import XCTest
@testable import EkitapligimCore

final class AudioModelsTests: XCTestCase {
    func testCatalogDecodesProductionBridgeContractAndNumbersAsStrings() throws {
        let catalog = try JSONDecoder().decode(AudioCatalogDTO.self, from: Data(AudioFixtures.catalog.utf8))
        XCTAssertEqual(catalog.books.count, 1); XCTAssertEqual(catalog.hero?.id, 27)
        XCTAssertEqual(catalog.books[0].duration, 317.5); XCTAssertTrue(catalog.books[0].canListen)
        XCTAssertEqual(catalog.books[0].state.progress, 74); XCTAssertEqual(catalog.books[0].coverURL, "https://ekitapligim.com/cover.jpg")
        XCTAssertEqual(catalog.pagination.page, 1); XCTAssertEqual(catalog.pagination.total, 1)
    }
    func testManifestRequiresLeaseUniqueChaptersAndExplicitSecureURLs() throws {
        let manifest = try JSONDecoder().decode(AudioManifestDTO.self, from: Data(AudioFixtures.manifest.utf8))
        XCTAssertEqual(manifest.session, "fixture-lease"); XCTAssertEqual(manifest.sequence, 3); XCTAssertEqual(manifest.chapters[0].id, 42)
        for body in [AudioFixtures.manifest.replacingOccurrences(of: "fixture-lease", with: ""),
                     AudioFixtures.manifest.replacingOccurrences(of: AudioFixtures.chapter, with: ""),
                     AudioFixtures.manifest.replacingOccurrences(of: "[\(AudioFixtures.chapter)]", with: "[\(AudioFixtures.chapter),\(AudioFixtures.chapter)]")] {
            XCTAssertThrowsError(try JSONDecoder().decode(AudioManifestDTO.self, from: Data(body.utf8)))
        }
    }
    func testUnknownVersionAndUnavailableAreNotEmptyCatalogSuccess() throws {
        for body in [#"{"api_version":2,"books":[]}"#, #"{"api_version":1,"available":false,"books":[]}"#, #"{"error":{"code":"audio_unavailable"}}"#, #"{"api_version":1,"books":[{"thread_id":0}]}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(AudioCatalogDTO.self, from: Data(body.utf8)))
        }
    }
    func testLibraryShelfCountsAndMixedStatsMatchBridgeAndWebState() throws {
        let body = #"{"api_version":1,"tab":"listening","books":[],"counts":{"saved":"2","listening":1,"completed":0,"favorite":"1"},"stats":{"total":3600,"month":"20","active":1,"top_category":"Roman"},"resume_book":null}"#
        let library = try JSONDecoder().decode(AudioLibraryDTO.self, from: Data(body.utf8))
        XCTAssertEqual(library.counts["saved"], 2); XCTAssertEqual(library.counts["history"], 0)
        XCTAssertEqual(library.stats["total"], "3600"); XCTAssertEqual(library.stats["top_category"], "Roman")
    }
    func testDetailIgnoresRemovedCommentAndNarratorSectionsWithoutLosingBook() throws {
        let body = "{\"api_version\":1,\"book\":\(AudioFixtures.book),\"comments\":[{\"private\":true}],\"same_narrator\":[{}],\"related\":[],\"same_author\":[]}"
        let detail = try JSONDecoder().decode(AudioDetailDTO.self, from: Data(body.utf8))
        XCTAssertEqual(detail.book.title, "Beyaz Zambaklar Ülkesinde"); XCTAssertTrue(detail.related.isEmpty)
    }
    func testProgressCreditAndStateAreDecodedWithoutManufacturingCompletion() throws {
        let response = try JSONDecoder().decode(AudioProgressResponseDTO.self, from: Data(#"{"saved":true,"credited":"5.5","completed":false,"state":{"progress":101,"position":-2,"speed":8}}"#.utf8))
        XCTAssertTrue(response.saved); XCTAssertEqual(response.credited, 5.5); XCTAssertFalse(response.completed)
        XCTAssertEqual(response.state?.progress, 100); XCTAssertEqual(response.state?.position, 0); XCTAssertEqual(response.state?.speed, 2)
    }
    func testFiltersKeepSameServerNamesAndNeverDefaultToExpanded() {
        var filters = AudioFilters(); XCTAssertFalse(filters.active)
        filters.query = "Petrov"; filters.maxDuration = 1800; filters.language = "Türkçe"; filters.category = 2
        let fields = Dictionary(uniqueKeysWithValues: filters.queryItems.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(fields["q"], "Petrov"); XCTAssertEqual(fields["max_duration"], "1800"); XCTAssertEqual(fields["language"], "Türkçe")
        XCTAssertEqual(fields["per_page"], "24"); XCTAssertEqual(fields["category"], "2"); XCTAssertTrue(filters.active)
    }
    func testEveryAudioStringResolvesFromResourceTable() {
        for key in ["title", "premiumMessage", "stopClose", "rewind", "forward", "rangeError", "libraryHero", "profileTitle", "quoteText", "noteText"] {
            XCTAssertNotEqual(AudioL10n.text(key), key)
        }
        XCTAssertTrue(AudioL10n.duration(3660).contains("1")); XCTAssertTrue(AudioL10n.duration(3660).contains("sa"))
    }
}

enum AudioFixtures {
    static let chapter = #"{"chapter_id":"42","title":"Bölüm 1","duration":"317.5","display_order":0,"url":"https://ekitapligim.com/mobile-api/v1/audio-books/27/stream?chapter_id=42"}"#
    static let book = #"{"thread_id":"27","title":"Beyaz Zambaklar Ülkesinde","author":"Grigori Petrov","cover_url":"https://ekitapligim.com/cover.jpg","duration":"317.5","language":"Türkçe","can_listen":1,"chapter_count":1,"user_state":{"progress":"74","favorite":true,"position":12}}"#
    static let catalog = "{\"api_version\":1,\"available\":true,\"books\":[\(book)],\"hero\":\(book),\"categories\":[],\"sections\":[],\"pagination\":{\"page\":1,\"pages\":1,\"total\":1}}"
    static let manifest = "{\"api_version\":1,\"session\":\"fixture-lease\",\"sequence\":3,\"book\":\(book),\"chapters\":[\(chapter)],\"state\":{},\"bookmarks\":[],\"recommendations\":[]}"
}
