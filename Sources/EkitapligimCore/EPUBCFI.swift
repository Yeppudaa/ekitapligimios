import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum EPUBPositionError: Error { case invalidCFI, invalidPackage, missingResource }

/// EPUB.js-compatible point CFIs. Range CFIs resume at the range's start.
public struct EPUBCFI: Equatable, Sendable {
    public let packageSteps: [Int]
    public let contentSteps: [Int]
    public let textOffset: Int
    public var spineIndex: Int { (packageSteps.last ?? 0) / 2 - 1 }

    public init(_ value: String) throws {
        guard value.hasPrefix("epubcfi("), value.hasSuffix(")") else { throw EPUBPositionError.invalidCFI }
        let source = String(value.dropFirst(8).dropLast())
        var plain = "", inAssertion = false, escaped = false
        for character in source {
            if escaped { escaped = false; continue }
            if character == "^" { escaped = true; continue }
            if character == "[" { guard !inAssertion else { throw EPUBPositionError.invalidCFI }; inAssertion = true; continue }
            if character == "]" { guard inAssertion else { throw EPUBPositionError.invalidCFI }; inAssertion = false; continue }
            if !inAssertion { plain.append(character) }
        }
        guard !inAssertion, !escaped else { throw EPUBPositionError.invalidCFI }
        let parts = plain.split(separator: "!", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw EPUBPositionError.invalidCFI }
        let ranges = parts[1].split(separator: ",", omittingEmptySubsequences: false)
        guard ranges.count == 1 || ranges.count == 3 else { throw EPUBPositionError.invalidCFI }
        let content = ranges.count == 3 ? String(ranges[0]) + String(ranges[1]) : String(ranges[0])
        func parse(_ path: String) throws -> ([Int], Int) {
            // Side bias does not change the character anchor.
            let anchor = path.components(separatedBy: ";s=")[0]
            let pieces = anchor.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count <= 2, pieces[0].hasPrefix("/") else { throw EPUBPositionError.invalidCFI }
            let rawSteps = pieces[0].dropFirst().split(separator: "/", omittingEmptySubsequences: false)
            let steps = try rawSteps.map { step -> Int in
                guard !step.isEmpty, step.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(step), number > 0 else { throw EPUBPositionError.invalidCFI }
                return number
            }
            let offset = pieces.count == 2 ? Int(pieces[1]) : 0
            guard let offset, offset >= 0, !steps.isEmpty else { throw EPUBPositionError.invalidCFI }
            return (steps, offset)
        }
        (packageSteps, _) = try parse(String(parts[0]))
        (contentSteps, textOffset) = try parse(content)
        guard packageSteps.count == 2, packageSteps.allSatisfy({ $0 % 2 == 0 }),
              contentSteps.dropLast().allSatisfy({ $0 % 2 == 0 }) else { throw EPUBPositionError.invalidCFI }
    }

    /// CSS element anchor for Readium's initialLocation; the exact text range is resolved from the DOM afterward.
    public var cssSelector: String {
        ":root" + contentSteps.filter { $0 % 2 == 0 }.map { " > :nth-child(\($0 / 2))" }.joined()
    }
}

/// Keeps the actual OPF spine order, including non-linear resources (which Readium's readingOrder may omit).
public struct EPUBPackageIndex: Sendable {
    public struct Item: Sendable { public let href: String; public let cfiBase: String }
    public let items: [Item]

    public init(opf: Data, packagePath: String) throws {
        let delegate = PackageParser()
        let parser = XMLParser(data: opf)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.spineStep > 0, !delegate.spine.isEmpty,
              let base = URL(string: "https://epub.invalid/" + packagePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
            throw EPUBPositionError.invalidPackage
        }
        items = try delegate.spine.enumerated().map { index, id in
            guard let href = delegate.manifest[id], let resolved = URL(string: href, relativeTo: base)?.absoluteURL else { throw EPUBPositionError.invalidPackage }
            return Item(href: Self.normalizedPath(resolved.path), cfiBase: "/\(delegate.spineStep)/\((index + 1) * 2)")
        }
    }

    public static func normalizedPath(_ path: String) -> String {
        let resource = URL(string: path).flatMap { $0.scheme == nil ? nil : $0.path } ?? path
        let clean = resource.components(separatedBy: "#")[0].components(separatedBy: "?")[0]
        return (clean.removingPercentEncoding ?? clean).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private final class PackageParser: NSObject, XMLParserDelegate {
        var manifest: [String: String] = [:]
        var spine: [String] = []
        var spineStep = 0
        var depth = 0
        var packageChild = 0
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            depth += 1
            let local = name.split(separator: ":").last.map(String.init) ?? name
            if depth == 2 { packageChild += 1 }
            if local == "spine" { spineStep = packageChild * 2 }
            if local == "item", let id = attributes["id"], let href = attributes["href"] { manifest[id] = href }
            if local == "itemref", let id = attributes["idref"] { spine.append(id) }
        }
        func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
    }
}
