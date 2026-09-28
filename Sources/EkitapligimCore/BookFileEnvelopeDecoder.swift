import Foundation

/// Streams the legacy base64 JSON response to disk without materializing the encoded string or ebook in memory.
/// Binary files bypass this decoder. Both root payloads and XenForo's innerContent envelope are supported.
public enum BookFileEnvelopeDecoder {
    public enum Failure: Error { case invalidJSON, noBookPayload, invalidBase64 }
    public static func decode(source: URL, destination: URL) throws {
        try Task.checkCancellation()
        let input = try BufferedBookInput(url: source)
        // The caller supplies a new temporary URL. Preserve existing files on mistakes,
        // including accidentally passing the source as the destination.
        try Data().write(to: destination, options: .withoutOverwriting)
        var success = false
        defer { if !success { try? FileManager.default.removeItem(at: destination) } }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        let parser = BookEnvelopeParser(input: input, output: output)
        try parser.parse()
        try Task.checkCancellation()
        try output.synchronize()
        success = true
    }
}

private final class BufferedBookInput {
    private let handle: FileHandle
    private var buffer = Data()
    private var cursor = 0
    init(url: URL) throws { handle = try FileHandle(forReadingFrom: url) }
    deinit { try? handle.close() }
    func peek() throws -> UInt8? {
        if cursor >= buffer.count {
            try Task.checkCancellation()
            buffer = try handle.read(upToCount: 65_536) ?? Data()
            cursor = 0
        }
        return cursor < buffer.count ? buffer[cursor] : nil
    }
    func take() throws -> UInt8? { let value = try peek(); if value != nil { cursor += 1 }; return value }
    func whitespace() throws {
        while let c = try peek(), [9, 10, 13, 32].contains(c) { _ = try take() }
    }
    func expect(_ byte: UInt8) throws {
        guard try take() == byte else { throw BookFileEnvelopeDecoder.Failure.invalidJSON }
    }
}

private final class BookEnvelopeParser {
    typealias Failure = BookFileEnvelopeDecoder.Failure
    let input: BufferedBookInput
    let output: FileHandle
    var found = false
    let payloadKeys: Set<String> = ["data", "contents", "file", "file_data", "fileData"]
    init(input: BufferedBookInput, output: FileHandle) { self.input = input; self.output = output }
    func parse() throws {
        try input.whitespace()
        try object(depth: 0, acceptsPayload: true)
        try input.whitespace()
        guard try input.peek() == nil else { throw Failure.invalidJSON }
        guard found else { throw Failure.noBookPayload }
    }
    func object(depth: Int, acceptsPayload: Bool) throws {
        guard depth < 32 else { throw Failure.invalidJSON }
        try input.expect(123); try input.whitespace()
        if try input.peek() == 125 { _ = try input.take(); return }
        while true {
            var keyBytes = Data()
            try string { if keyBytes.count < 256 { keyBytes.append($0) } }
            let key = String(data: keyBytes, encoding: .utf8) ?? ""
            try input.whitespace(); try input.expect(58); try input.whitespace()
            if acceptsPayload, payloadKeys.contains(key), !found, try input.peek() == 34 {
                try payload()
            } else if depth == 0, key == "innerContent", try input.peek() == 123 {
                try object(depth: depth + 1, acceptsPayload: true)
            } else { try value(depth: depth + 1) }
            try input.whitespace()
            if try input.peek() == 125 { _ = try input.take(); return }
            try input.expect(44); try input.whitespace()
        }
    }
    func value(depth: Int) throws {
        guard depth < 32 else { throw Failure.invalidJSON }
        try input.whitespace()
        switch try input.peek() {
        case 123: try object(depth: depth, acceptsPayload: false)
        case 34: try string { _ in }
        case 91:
            _ = try input.take(); try input.whitespace()
            if try input.peek() == 93 { _ = try input.take(); return }
            while true {
                try value(depth: depth + 1); try input.whitespace()
                if try input.peek() == 93 { _ = try input.take(); return }
                try input.expect(44)
            }
        default:
            var scalar = Data()
            while let c = try input.peek(), ![9, 10, 13, 32, 44, 93, 125].contains(c) {
                guard scalar.count < 128 else { throw Failure.invalidJSON }
                scalar.append(c); _ = try input.take()
            }
            guard !scalar.isEmpty, (try? JSONSerialization.jsonObject(with: scalar, options: .fragmentsAllowed)) != nil else { throw Failure.invalidJSON }
        }
    }
    func string(_ consume: (UInt8) throws -> Void) throws {
        try input.expect(34)
        while let byte = try input.take() {
            if byte == 34 { return }
            guard byte >= 32 else { throw Failure.invalidJSON }
            if byte != 92 { try consume(byte); continue }
            guard let escaped = try input.take() else { throw Failure.invalidJSON }
            switch escaped {
            case 34, 47, 92: try consume(escaped)
            case 98: try consume(8)
            case 102: try consume(12)
            case 110: try consume(10)
            case 114: try consume(13)
            case 116: try consume(9)
            case 117:
                var code: UInt32 = 0
                for _ in 0..<4 {
                    guard let byte = try input.take(), let digit = Int(String(UnicodeScalar(byte)), radix: 16) else { throw Failure.invalidJSON }
                    code = code * 16 + UInt32(digit)
                }
                // Payload characters are ASCII. Non-ASCII metadata is consumed without retaining strings.
                if let scalar = UnicodeScalar(code) { for byte in String(scalar).utf8 { try consume(byte) } }
                else { try consume(63) }
            default: throw Failure.invalidJSON
            }
        }
        throw Failure.invalidJSON
    }
    func payload() throws {
        try output.truncate(atOffset: 0); try output.seek(toOffset: 0)
        var encoded = Data(), header = Data()
        var valid = true, paddingCount = 0
        func flush() throws {
            guard !encoded.isEmpty else { return }
            guard let decoded = Data(base64Encoded: encoded) else { valid = false; encoded.removeAll(keepingCapacity: true); return }
            if header.count < 1024 { header.append(decoded.prefix(1024 - header.count)) }
            try output.write(contentsOf: decoded)
            encoded.removeAll(keepingCapacity: true)
        }
        try string { byte in
            guard valid else { return }
            // JSON strings can contain escaped line breaks around a base64 response.
            // Ignoring ASCII whitespace also accepts MIME-wrapped payloads without copying them.
            if byte == 9 || byte == 10 || byte == 13 || byte == 32 { return }
            let isAlphabet = (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 43 || byte == 47
            guard isAlphabet || byte == 61, paddingCount == 0 || byte == 61 else { valid = false; return }
            if byte == 61 {
                paddingCount += 1
                guard paddingCount <= 2 else { valid = false; return }
            }
            encoded.append(byte)
            // Every flush ends at a quartet boundary; even malformed padding cannot
            // grow this working buffer beyond 64 KiB.
            if encoded.count == 65_536 { try flush() }
        }
        if valid { try flush() }
        found = valid && DownloadFilePolicy.sniffedFileExtension(fromHeader: header) != nil
        if !found { try output.truncate(atOffset: 0) }
    }
}
