#!/usr/bin/env python3
"""Package local, test-only evidence; never fetch or publish build artifacts."""

import argparse
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import stat
import sys
import zipfile


TEXT_SUFFIXES = {".txt", ".json", ".xml", ".csv", ".log", ".md", ".tsv", ".yaml", ".yml"}
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic", ".heif", ".tif", ".tiff"}
VIDEO_SUFFIXES = {".mov", ".mp4", ".m4v", ".webm", ".avi", ".mpeg", ".mpg"}
TEXT_UTIS = {"public.plain-text", "public.utf8-plain-text", "public.utf16-plain-text", "public.json", "public.xml", "public.comma-separated-values-text"}


def reject_links(path):
    """Check every existing ancestor, including Windows directory junctions."""
    for part in (path, *path.parents):
        if part.is_symlink() or (hasattr(part, "is_junction") and part.is_junction()):
            raise ValueError(f"Symlink/junction is not permitted: {part}")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def image_type(header):
    if header.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if header.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if header.startswith((b"II*\x00", b"MM\x00*")):
        return "image/tiff"
    if len(header) >= 12 and header[4:8] == b"ftyp" and header[8:12] in {b"heic", b"heix", b"hevc", b"hevx", b"mif1", b"msf1"}:
        return "image/heic"
    return None


def attachment_hints(files, root):
    """Read export-manifest metadata without opening paths supplied by a manifest."""
    hints = {}
    for path in files:
        if path.suffix.lower() != ".json" or "manifest" not in path.name.lower():
            continue
        if not any(part.endswith("-screenshots") for part in path.relative_to(root).parts[:-1]):
            continue
        data = json.loads(path.read_text(encoding="utf-8-sig"))

        def visit(node):
            if isinstance(node, dict):
                name = node.get("exportedFileName") or node.get("fileName") or node.get("filename")
                if isinstance(name, str):
                    # Names are hints only. Never follow absolute/relative references from JSON.
                    key = (path.parent, Path(name).name)
                    value = node.get("uniformTypeIdentifier") or node.get("typeIdentifier") or node.get("mimeType") or node.get("contentType")
                    if isinstance(value, str):
                        hints[key] = value.lower()
                for value in node.values():
                    visit(value)
            elif isinstance(node, list):
                for value in node:
                    visit(value)

        visit(data)
    return hints


def classify(path, relative, hints):
    bundle = next((part for part in relative.parts[:-1] if part.endswith(".xcresult")), None)
    if bundle:
        return "forensic-only", "Complete original result bundle", None, bundle
    suffix = path.suffix.lower()
    guessed_mime = mimetypes.guess_type(path.name)[0] or ""
    hint = hints.get((path.parent, path.name), "")
    with path.open("rb") as source:
        header = source.read(64)
    image_mime = image_type(header)
    if image_mime:
        return "included", "Original image bytes", image_mime, None
    if suffix in VIDEO_SUFFIXES or guessed_mime.startswith("video/") or hint.startswith("video/") or hint in {"public.movie", "public.mpeg-4", "com.apple.quicktime-movie"}:
        return "omitted-video", "Video excluded from compact evidence; original remains in its result bundle", guessed_mime or hint, None
    if suffix in IMAGE_SUFFIXES:
        raise ValueError(f"Image extension has no recognized original image signature: {relative}")
    if suffix in TEXT_SUFFIXES or guessed_mime.startswith("text/") or guessed_mime in {"application/json", "application/xml"} or hint in TEXT_UTIS or hint.startswith("text/"):
        return "included", "Original text/structured evidence bytes", guessed_mime or hint or "text/plain", None
    return "omitted-unknown", "Unrecognized attachment/evidence inventoried; source not modified", guessed_mime or hint or None, None


def write_zip(destination, root, entries, index=None, directories=()):
    """Write once, without rewriting images, and fail rather than archive a changing file."""
    reject_links(destination)
    if destination.exists():
        raise ValueError(f"Refusing to overwrite existing evidence archive: {destination}")
    temporary = destination.with_suffix(destination.suffix + ".partial")
    reject_links(temporary)
    if temporary.exists():
        raise ValueError(f"Refusing to overwrite partial evidence archive: {temporary}")
    with zipfile.ZipFile(temporary, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=1, allowZip64=True) as archive:
        for directory in directories:
            archive.write(root / directory, directory.as_posix() + "/")
        for entry in entries:
            relative = Path(entry["path"])
            path = root / relative
            reject_links(path)
            before = path.stat()
            if before.st_size != entry["bytes"] or sha256(path) != entry["sha256"]:
                raise ValueError(f"Evidence changed before archiving: {relative}")
            archive.write(path, relative.as_posix())
            after = path.stat()
            if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                raise ValueError(f"Evidence changed while archiving: {relative}")
        if index is not None:
            archive.writestr("evidence-index.json", json.dumps(index, indent=2, ensure_ascii=False) + "\n")
    temporary.rename(destination)


def package(root, output):
    root = root.absolute()
    output = output.absolute()
    reject_links(root)
    reject_links(output)
    root = root.resolve(strict=True)
    output = output.resolve(strict=False)
    if not root.is_dir():
        raise ValueError("Evidence root must be a directory")
    if output == root or root in output.parents or output in root.parents:
        raise ValueError("Evidence and archive directories must be separate sibling trees")
    files, directories = [], []
    for current, names, filenames in os.walk(root, followlinks=False):
        parent = Path(current)
        for name in sorted(names + filenames):
            path = parent / name
            reject_links(path)
            if not path.resolve(strict=True).is_relative_to(root):
                raise ValueError(f"Evidence path escapes its root: {path}")
            mode = path.lstat().st_mode
            if stat.S_ISDIR(mode):
                directories.append(path.relative_to(root))
            elif stat.S_ISREG(mode):
                files.append(path)
            else:
                raise ValueError(f"Non-regular evidence entry: {path}")
    files.sort(key=lambda path: path.relative_to(root).as_posix())
    entries = []
    for path in files:
        relative = path.relative_to(root)
        if relative.as_posix() == "evidence-index.json":
            raise ValueError("Source evidence uses the reserved packaging index name")
        bundles = [part for part in relative.parts[:-1] if part.endswith(".xcresult")]
        if bundles and (len(bundles) != 1 or relative.parts[0] != bundles[0]):
            raise ValueError(f"Result bundles must be direct children of the evidence root: {relative}")
        entry = {"path": relative.as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)}
        if bundles:
            entry.update(disposition="forensic-only", reason="Complete original result bundle", forensicArchive="forensics/" + bundles[0] + ".zip")
        entries.append(entry)
    output.mkdir(parents=True, exist_ok=True)
    reject_links(output)
    forensic_root = output / "forensics"
    reject_links(forensic_root)
    forensic_root.mkdir(exist_ok=True)
    forensic_archives = []
    # Preserve full forensic results first, even if a malformed exported manifest later fails.
    bundles = {"forensics/" + path.parts[0] + ".zip" for path in directories if len(path.parts) == 1 and path.name.endswith(".xcresult")}
    for bundle in sorted(bundles):
        bundle_entries = [entry for entry in entries if entry.get("forensicArchive") == bundle]
        bundle_name = Path(bundle).name.removesuffix(".zip")
        bundle_directories = [path for path in directories if path.parts[0] == bundle_name]
        destination = output / bundle
        write_zip(destination, root, bundle_entries, directories=bundle_directories)
        forensic_archives.append({"path": bundle, "bytes": destination.stat().st_size, "sha256": sha256(destination)})
    hints = attachment_hints(files, root)
    for entry in entries:
        if "forensicArchive" in entry:
            continue
        relative = Path(entry["path"])
        disposition, reason, mime, _ = classify(root / relative, relative, hints)
        entry.update(disposition=disposition, reason=reason)
        if mime:
            entry["mediaType"] = mime
    index = {"formatVersion": 1, "scope": "Local native test evidence; no downloads or publishing", "imagesReencoded": False, "sourceFilesModified": False, "forensicArchives": forensic_archives, "files": entries}
    compact = output / "modern-parity-evidence.zip"
    write_zip(compact, root, [entry for entry in entries if entry["disposition"] == "included"], index=index)
    print(json.dumps({"compactArchive": compact.name, "compactBytes": compact.stat().st_size, "compactSHA256": sha256(compact), "sourceFiles": len(entries), "includedFiles": sum(entry["disposition"] == "included" for entry in entries), "forensicArchives": forensic_archives}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        package(args.evidence_root, args.output_root)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"EVIDENCE PACKAGING FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
