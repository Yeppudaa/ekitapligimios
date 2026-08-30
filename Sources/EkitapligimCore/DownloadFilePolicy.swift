import Foundation

public enum DownloadFilePolicyError: Error, Equatable, Sendable {
    case invalidBookIdentifier
    case unsupportedFileType
    case invalidFileContents
}

public enum DownloadFilePolicy {
    public static func fileExtension(for rawFileType: String) throws -> String {
        switch rawFileType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pdf", ".pdf", "application/pdf":
            return "pdf"
        case "epub", ".epub", "application/epub+zip":
            return "epub"
        default:
            throw DownloadFilePolicyError.unsupportedFileType
        }
    }

    /// Session payloads sometimes send `unknown` for Drive books. Treat that as PDF until the file header is sniffed.
    public static func resolvedFileExtension(for rawFileType: String) -> String {
        (try? fileExtension(for: rawFileType)) ?? "pdf"
    }

    public static func fileName(bookID: String, fileExtension: String) throws -> String {
        guard !bookID.isEmpty,
              bookID.utf8.count <= 64,
              bookID.unicodeScalars.allSatisfy({ scalar in
                  scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_")
              }) else {
            throw DownloadFilePolicyError.invalidBookIdentifier
        }
        let validatedExtension = try self.fileExtension(for: fileExtension)
        return "book-\(bookID).\(validatedExtension)"
    }

    public static func validateHeader(_ data: Data, fileExtension: String) throws {
        let validatedExtension = try self.fileExtension(for: fileExtension)
        switch validatedExtension {
        case "pdf":
            guard let marker = "%PDF-".data(using: .ascii),
                  data.range(of: marker, options: [], in: data.startIndex..<min(data.endIndex, 1_024)) != nil else {
                throw DownloadFilePolicyError.invalidFileContents
            }
        case "epub":
            let allowedZipHeaders: [[UInt8]] = [
                [0x50, 0x4B, 0x03, 0x04],
                [0x50, 0x4B, 0x05, 0x06],
                [0x50, 0x4B, 0x07, 0x08]
            ]
            guard allowedZipHeaders.contains(where: { data.starts(with: $0) }) else {
                throw DownloadFilePolicyError.invalidFileContents
            }
        default:
            throw DownloadFilePolicyError.unsupportedFileType
        }
    }

    public static func sniffedFileExtension(fromHeader data: Data) -> String? {
        if (try? validateHeader(data, fileExtension: "pdf")) != nil {
            return "pdf"
        }
        if (try? validateHeader(data, fileExtension: "epub")) != nil {
            return "epub"
        }
        return nil
    }

    public static func sniffedFileExtension(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 1_024)) ?? Data()
        return sniffedFileExtension(fromHeader: header)
    }
}
