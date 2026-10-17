import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AudioPolicyTests: XCTestCase {
    func testBridgeBasePreservesSubdirectoryAndRequiresSecureOrigin() throws {
        XCTAssertEqual(try AudioPolicy.baseURL(webBaseURL: XCTUnwrap(URL(string: "https://ekitapligim.com/ekitapligim/"))).absoluteString, "https://ekitapligim.com/ekitapligim/mobile-api/v1/")
        for raw in ["http://ekitapligim.com/", "https://user:pass@ekitapligim.com/", "https://ekitapligim.com/?token=x", "https://ekitapligim.com/#x"] {
            XCTAssertThrowsError(try AudioPolicy.baseURL(webBaseURL: XCTUnwrap(URL(string: raw))))
        }
    }
    func testStreamAllowsOnlyExactAuthenticatedBridgeRouteAndChapter() throws {
        let base = try XCTUnwrap(URL(string: "https://ekitapligim.com/mobile-api/v1/"))
        let good = "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream?chapter_id=42"
        XCTAssertEqual(try AudioPolicy.streamURL(good, bookID: 27, chapterID: 42, baseURL: base).absoluteString, good)
        for bad in [good.replacingOccurrences(of: "https:", with: "http:"), good.replacingOccurrences(of: "ekitapligim.com", with: "evil.example"),
                    good.replacingOccurrences(of: "/27/", with: "/28/"), good.replacingOccurrences(of: "42", with: "43"),
                    good + "&token=secret", good + "&chapter_id=42", good + "#redirect", good.replacingOccurrences(of: "https://", with: "https://user@"),
                    "https://ekitapligim.com:8443/mobile-api/v1/audio-books/27/stream?chapter_id=42",
                    "https://ekitapligim.com/media/book.mp3?chapter_id=42", "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream/other?chapter_id=42"] {
            XCTAssertThrowsError(try AudioPolicy.streamURL(bad, bookID: 27, chapterID: 42, baseURL: base), bad)
        }
    }
    func testTokensCannotInjectHeadersAndLegacyTokensAreRejected() {
        XCTAssertTrue(AudioPolicy.validToken("ms_at_valid"))
        for bad in ["", "ms_at_", "legacy", "ms_at_x\r\nCookie: x", "ms_at_x y", "ms_at_x\t"] { XCTAssertFalse(AudioPolicy.validToken(bad)) }
    }
    func testProgressReservationsNeverDuplicateInFlightListeningCredit() throws {
        var ledger = AudioProgressLedger(); ledger.activate(session: "lease", sequence: 9)
        for _ in 0..<15 { ledger.accrue(elapsed: 1, playing: true) }
        let first = try ledger.reserve(bookID: 1, chapterID: 2, position: 15, speed: 1)
        let second = try ledger.reserve(bookID: 1, chapterID: 2, position: 15, speed: 1)
        XCTAssertEqual(first.sequence, 10); XCTAssertEqual(first.listened, 15)
        XCTAssertEqual(second.sequence, 11); XCTAssertEqual(second.listened, 0)
        ledger.accrue(elapsed: 1, playing: true); ledger.acknowledged(first)
        XCTAssertEqual(ledger.pendingSeconds, 1)
    }
    func testProgressRetryCreditIsBoundedAndCannotRestoreAnotherLease() throws {
        var ledger = AudioProgressLedger(); ledger.activate(session: "old", sequence: 0)
        ledger.accrue(elapsed: 100_000, playing: true)
        let write = try ledger.reserve(bookID: 1, chapterID: 2, position: .nan, speed: 9)
        XCTAssertEqual(write.listened, 1.5); XCTAssertEqual(write.position, 0); XCTAssertEqual(write.speed, 2)
        ledger.failed(write); ledger.failed(write)
        XCTAssertEqual(ledger.pendingSeconds, 1.5)
        ledger.activate(session: "new", sequence: 2); ledger.failed(write)
        XCTAssertEqual(ledger.pendingSeconds, 0)
        XCTAssertEqual(try ledger.reserve(bookID: 1, chapterID: 2, position: 0, speed: 1).sequence, 3)
    }
    func testPausedAndInvalidTimeCannotManufactureListening() throws {
        var ledger = AudioProgressLedger(); ledger.activate(session: "lease", sequence: 0)
        ledger.accrue(elapsed: 30, playing: false); ledger.accrue(elapsed: .infinity, playing: true); ledger.accrue(elapsed: -1, playing: true)
        XCTAssertEqual(ledger.pendingSeconds, 0)
        XCTAssertThrowsError(try ledger.reserve(bookID: 0, chapterID: 2, position: 0, speed: 1))
    }
    func testStrictRangeValidationRejectsIgnoredPartialAndMalformedResponses() throws {
        let url = try XCTUnwrap(URL(string: "https://ekitapligim.com/stream"))
        func response(_ code: Int, _ range: String?) throws -> HTTPURLResponse {
            try XCTUnwrap(HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: range.map { ["Content-Range": $0] }))
        }
        XCTAssertNoThrow(try AudioRangePolicy.validate(response: response(206, "bytes 100-199/1000"), dataCount: 100, start: 100, end: 199))
        XCTAssertNoThrow(try AudioRangePolicy.validate(response: response(206, "bytes 950-999/1000"), dataCount: 50, start: 950, end: 1099))
        for (code, range, count) in [(200, "bytes 100-199/1000", 100), (206, "bytes 0-99/1000", 100), (206, "bytes 100-199/1000", 99), (206, "bytes 100-200/1000", 101), (206, "bytes 100-199/*", 100), (416, "bytes */1000", 0)] {
            XCTAssertThrowsError(try AudioRangePolicy.validate(response: response(code, range), dataCount: count, start: 100, end: 199))
        }
    }
    func testMetadataRequiresActualLengthRangesAndAudioContent() throws {
        let url = try XCTUnwrap(URL(string: "https://ekitapligim.com/stream"))
        let headers = ["Content-Length": "1000", "Content-Type": "audio/mpeg", "Accept-Ranges": "bytes"]
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers))
        XCTAssertEqual(try AudioMediaMetadata(response: response).length, 1000)
        for values in [["Content-Length": "0", "Content-Type": "audio/mpeg", "Accept-Ranges": "bytes"],
                       ["Content-Length": "1000", "Content-Type": "text/html", "Accept-Ranges": "bytes"],
                       ["Content-Length": "1000", "Content-Type": "audio/mpeg"]] {
            let bad = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: values))
            XCTAssertThrowsError(try AudioMediaMetadata(response: bad))
        }
    }
    func testAnnotationPrefixesAreCompatibleWithAndroidAndBoundedWithoutLosingText() throws {
        XCTAssertEqual(try AudioPolicy.annotation(kind: .note, text: "  Yeni bir dünya  "), "Not: Yeni bir dünya")
        XCTAssertEqual(try AudioPolicy.annotation(kind: .quote, text: "Hayat"), "Alıntı: Hayat")
        XCTAssertEqual(try AudioPolicy.annotation(kind: .quote, text: String(repeating: "ğ", count: 500)).count, 255)
        XCTAssertThrowsError(try AudioPolicy.annotation(kind: .note, text: " \n "))
        let note = try JSONDecoder().decode(AudioBookmarkDTO.self, from: Data(#"{"bookmark_id":"1","chapter_id":"2","position":"8.5","label":"Alıntı: Yeni bir dünya"}"#.utf8))
        XCTAssertEqual(note.kind, .quote); XCTAssertEqual(note.displayText, "Yeni bir dünya"); XCTAssertEqual(note.position, 8.5)
    }
    func testTimeFormattingIsBoundedAndAlwaysFinite() {
        XCTAssertEqual(AudioPolicy.time(3605), "1:00:05"); XCTAssertEqual(AudioPolicy.time(125), "2:05")
        XCTAssertEqual(AudioPolicy.time(.nan), "0:00"); XCTAssertEqual(AudioPolicy.time(-30), "0:00")
    }
}
