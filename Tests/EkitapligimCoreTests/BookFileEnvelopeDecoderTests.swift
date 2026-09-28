import Foundation
import XCTest
@testable import EkitapligimCore

final class BookFileEnvelopeDecoderTests: XCTestCase {
    private func withFiles(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("response.json"), directory.appendingPathComponent("book.pdf"))
    }

    func testDecodesAllSupportedPayloadKeysAndInnerEnvelope() throws {
        let pdf = Data("%PDF-1.7\nBook content\n%%EOF".utf8)
        for key in ["data", "contents", "file", "file_data", "fileData"] {
            for wrapped in [false, true] {
                try withFiles { source, destination in
                    let payload: [String: Any] = [key: pdf.base64EncodedString()]
                    let object: [String: Any] = wrapped ? ["innerContent": payload] : payload
                    try JSONSerialization.data(withJSONObject: object).write(to: source)

                    try BookFileEnvelopeDecoder.decode(source: source, destination: destination)

                    XCTAssertEqual(try Data(contentsOf: destination), pdf)
                }
            }
        }
    }

    func testStreamsMultiMegabyteBookAcrossBufferBoundaries() throws {
        try withFiles { source, destination in
            // Each 48 KiB binary chunk produces one 64 KiB encoded buffer. The JSON
            // prefix offsets input boundaries, and the final chunk requires padding.
            let chunk = Data(repeating: 65, count: 49_152)
            let first = Data("%PDF-1.7\n".utf8) + Data(repeating: 66, count: 49_143)
            let last = Data("\n%%EOF".utf8) + Data([10])
            try Data("{\"innerContent\":{\"data\":\"".utf8).write(to: source)
            let writer = try FileHandle(forWritingTo: source)
            defer { try? writer.close() }
            try writer.seekToEnd()
            try writer.write(contentsOf: Data(first.base64EncodedString().utf8))
            for _ in 0..<64 { try writer.write(contentsOf: Data(chunk.base64EncodedString().utf8)) }
            try writer.write(contentsOf: Data(last.base64EncodedString().utf8))
            try writer.write(contentsOf: Data("\"},\"metadata\":[true,null,42,{\"title\":\"Kitap\"}]}".utf8))
            try writer.synchronize()

            try BookFileEnvelopeDecoder.decode(source: source, destination: destination)

            let reader = try FileHandle(forReadingFrom: destination)
            defer { try? reader.close() }
            XCTAssertEqual(try reader.read(upToCount: first.count), first)
            for _ in 0..<64 { XCTAssertEqual(try reader.read(upToCount: chunk.count), chunk) }
            XCTAssertEqual(try reader.read(upToCount: last.count), last)
            XCTAssertTrue(try reader.read(upToCount: 1)?.isEmpty ?? true)
        }
    }

    func testAcceptsEscapedWhitespaceAndSlashInBase64() throws {
        try withFiles { source, destination in
            let pdf = Data("%PDF-1.7\n".utf8) + Data([255, 255, 255])
            let encoded = pdf.base64EncodedString()
            let wrapped = " \t" + String(encoded.prefix(4)) + "\r\n" + String(encoded.dropFirst(4)) + "\n "
            let json = try JSONSerialization.data(withJSONObject: ["data": wrapped])
            try json.write(to: source)

            try BookFileEnvelopeDecoder.decode(source: source, destination: destination)

            XCTAssertEqual(try Data(contentsOf: destination), pdf)
        }
    }

    func testSkipsInvalidCandidateAndReadsFollowingBookPayload() throws {
        try withFiles { source, destination in
            let pdf = Data("%PDF-1.7\nvalid".utf8)
            let json = "{\"data\":\"not a book\",\"contents\":\"\(pdf.base64EncodedString())\"}"
            try Data(json.utf8).write(to: source)

            try BookFileEnvelopeDecoder.decode(source: source, destination: destination)

            XCTAssertEqual(try Data(contentsOf: destination), pdf)
        }
    }

    func testAcceptsEPUBArchiveHeader() throws {
        try withFiles { source, destination in
            let epub = Data([0x50, 0x4B, 0x03, 0x04, 0x0A, 0x00])
            try JSONSerialization.data(withJSONObject: ["data": epub.base64EncodedString()]).write(to: source)

            try BookFileEnvelopeDecoder.decode(source: source, destination: destination)

            XCTAssertEqual(try Data(contentsOf: destination), epub)
        }
    }

    func testRejectsMalformedJSONAndRemovesPartialOutput() throws {
        let encoded = Data("%PDF-1.7\nvalid".utf8).base64EncodedString()
        for malformed in ["{\"data\":\"\(encoded)\"", "{\"data\":\"\(encoded)\"} trailing", "{\"data\":\"\(encoded)\",}"] {
            try withFiles { source, destination in
                try Data(malformed.utf8).write(to: source)

                XCTAssertThrowsError(try BookFileEnvelopeDecoder.decode(source: source, destination: destination))

                XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
                XCTAssertEqual(try Data(contentsOf: source), Data(malformed.utf8))
            }
        }
    }

    func testRejectsInvalidBase64AndExcessivePadding() throws {
        let encoded = Data("%PDF-1.7\nvalid".utf8).base64EncodedString()
        for value in [encoded + "A", encoded + String(repeating: "=", count: 131_072), "%PDF-not-base64", ""] {
            try withFiles { source, destination in
                try JSONSerialization.data(withJSONObject: ["data": value]).write(to: source)

                XCTAssertThrowsError(try BookFileEnvelopeDecoder.decode(source: source, destination: destination))

                XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            }
        }
    }

    func testDoesNotTreatNestedMetadataAsBookPayload() throws {
        try withFiles { source, destination in
            let metadata = ["metadata": ["data": Data("%PDF-1.7 metadata".utf8).base64EncodedString()]]
            try JSONSerialization.data(withJSONObject: metadata).write(to: source)

            XCTAssertThrowsError(try BookFileEnvelopeDecoder.decode(source: source, destination: destination))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
    }

    func testPreservesExistingDestinationAndSource() throws {
        try withFiles { source, destination in
            let original = Data("%PDF-1.7 existing".utf8)
            let response = try JSONSerialization.data(withJSONObject: ["data": original.base64EncodedString()])
            try response.write(to: source)
            try original.write(to: destination)

            XCTAssertThrowsError(try BookFileEnvelopeDecoder.decode(source: source, destination: destination))
            XCTAssertEqual(try Data(contentsOf: destination), original)
            XCTAssertThrowsError(try BookFileEnvelopeDecoder.decode(source: source, destination: source))
            XCTAssertEqual(try Data(contentsOf: source), response)
        }
    }

    func testCancelledDecodeDoesNotCreateOutput() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("response.json")
        let destination = directory.appendingPathComponent("book.pdf")
        try Data("{}".utf8).write(to: source)
        let task = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            try BookFileEnvelopeDecoder.decode(source: source, destination: destination)
        }

        do {
            try await task.value
            XCTFail("Cancelled decoding must throw")
        } catch is CancellationError {
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
    }
}
