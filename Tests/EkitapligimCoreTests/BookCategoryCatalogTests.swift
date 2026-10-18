import Foundation
import XCTest
@testable import EkitapligimCore

final class BookCategoryCatalogTests: XCTestCase {
    private let expectedEnglishTitles = [
        "Fiction", "Literature", "Education", "Science", "History", "Religion", "Psychology", "Personal Growth",
        "Economics", "Children's Books", "Biography", "Philosophy", "Short Stories", "Politics", "Romance",
        "Fantasy", "Science Fiction", "Adventure", "Crime Fiction", "Horror / Thriller", "Young Adult", "Health",
        "Turkish Classics", "World Classics", "Technology / Computing", "Foreign Languages", "Culture / Art",
        "Film / Theatre", "Academic", "Family and Lifestyle", "Food / Cooking", "Fairy Tales"
    ]

    func testEmptyCommunityResponseStillProvidesAndroidCatalogCategories() {
        let categories = BookCategoryCatalog.merging(live: [])

        XCTAssertEqual(categories, BookCategoryCatalog.defaults)
        XCTAssertEqual(categories.map(\.id), expectedCategories.map(\.id))
        let expectedTitles = Bundle.module.preferredLocalizations.first == "en"
            ? expectedEnglishTitles : expectedCategories.map(\.title)
        XCTAssertEqual(categories.map(\.title), expectedTitles)
        XCTAssertEqual(categories.count, 32)
        XCTAssertEqual(Array(categories.prefix(8)).map(\.id), ["6", "7", "8", "9", "10", "11", "12", "13"])
        XCTAssertFalse(categories.contains { $0.id == "31" })
    }

    func testFallbackCategoriesDoNotInventBookCounts() {
        XCTAssertTrue(BookCategoryCatalog.defaults.allSatisfy { $0.threadCount == nil })
        XCTAssertTrue(BookCategoryCatalog.defaults.allSatisfy { $0.isBookForum == true })
        XCTAssertEqual(Set(BookCategoryCatalog.defaults.map(\.id)).count, 32)
    }

    func testLiveCatalogMetadataEnrichesKnownCategoryWithoutChangingOrder() throws {
        let live = ForumDTO(
            id: "6", title: "  📚 Roman  ", description: "Roman türündeki kitaplar",
            url: "https://example.com/forumlar/roman.6/", stats: "120 kitap",
            threadCount: 120, isBookForum: true
        )
        let categories = BookCategoryCatalog.merging(live: [live])
        let roman = try XCTUnwrap(categories.first { $0.id == "6" })

        XCTAssertEqual(roman.title, "Roman")
        XCTAssertEqual(roman.description, live.description)
        XCTAssertEqual(roman.url, live.url)
        XCTAssertEqual(roman.stats, live.stats)
        XCTAssertEqual(roman.threadCount, 120)
        XCTAssertEqual(roman.isBookForum, true)
        XCTAssertEqual(categories.map(\.id), expectedCategories.map(\.id))
        XCTAssertEqual(categories.count, 32)
    }

    func testLiveTitlesTrimBothBookEmojiPrefixes() throws {
        let categories = BookCategoryCatalog.merging(live: [
            ForumDTO(id: "6", title: " \n📚 Roman \t"),
            ForumDTO(id: "7", title: "  📖 Edebiyat  ")
        ])

        XCTAssertEqual(try XCTUnwrap(categories.first { $0.id == "6" }).title, "Roman")
        XCTAssertEqual(try XCTUnwrap(categories.first { $0.id == "7" }).title, "Edebiyat")
    }

    func testCommunityOnlyForumsCannotReplaceOrAddCatalogCategories() {
        let categories = BookCategoryCatalog.merging(live: [
            ForumDTO(id: "1", title: "Duyurular", threadCount: 800, isBookForum: false),
            ForumDTO(id: "31", title: "Sohbet", isBookForum: true),
            ForumDTO(id: "999", title: "Kitap kulübü", isBookForum: true)
        ])

        XCTAssertEqual(categories, BookCategoryCatalog.defaults)
        XCTAssertEqual(Set(categories.map(\.id)).count, categories.count)
    }

    func testBlankAndGenericLiveTitlesRetainUsefulFallbackCategory() throws {
        let categories = BookCategoryCatalog.merging(live: [
            ForumDTO(id: "6", title: " \n\t ", threadCount: 900),
            ForumDTO(id: "7", title: "Genel", threadCount: 700),
            ForumDTO(id: "8", title: " 📖  ", threadCount: 500)
        ])

        for id in ["6", "7", "8"] {
            let fallback = try XCTUnwrap(BookCategoryCatalog.defaults.first { $0.id == id })
            XCTAssertEqual(categories.first { $0.id == id }, fallback)
        }
    }

    func testDuplicateLiveRecordsUseFirstValidCategoryAndKeepOneEntryPerID() throws {
        let categories = BookCategoryCatalog.merging(live: [
            ForumDTO(id: "6", title: " ", threadCount: 900),
            ForumDTO(id: "6", title: "📚 Roman", threadCount: 120),
            ForumDTO(id: "6", title: "Sonraki başlık", threadCount: 240),
            ForumDTO(id: "7", title: "Genel", threadCount: 800),
            ForumDTO(id: "7", title: "📖 Edebiyat", threadCount: 42)
        ])
        let roman = try XCTUnwrap(categories.first { $0.id == "6" })
        let literature = try XCTUnwrap(categories.first { $0.id == "7" })

        XCTAssertEqual(roman.title, "Roman")
        XCTAssertEqual(roman.threadCount, 120)
        XCTAssertEqual(literature.title, "Edebiyat")
        XCTAssertEqual(literature.threadCount, 42)
        XCTAssertEqual(categories.count, 32)
        XCTAssertEqual(Set(categories.map(\.id)).count, categories.count)
    }

    func testNegativeCountsStayUnknownWhileExplicitZeroIsPreserved() throws {
        let categories = BookCategoryCatalog.merging(live: [
            ForumDTO(id: "6", title: "Roman", threadCount: -1),
            ForumDTO(id: "7", title: "Edebiyat", threadCount: 0),
            ForumDTO(id: "8", title: "Eğitim")
        ])

        XCTAssertNil(try XCTUnwrap(categories.first { $0.id == "6" }).threadCount)
        XCTAssertEqual(try XCTUnwrap(categories.first { $0.id == "7" }).threadCount, 0)
        XCTAssertNil(try XCTUnwrap(categories.first { $0.id == "8" }).threadCount)
    }

    func testTurkishSortUsesLocalizedAlphabetAndPreservesRecords() {
        let categories = [
            ForumDTO(id: "6", title: "Roman"),
            ForumDTO(id: "7", title: "Edebiyat"),
            ForumDTO(id: "15", title: "Çocuk"),
            ForumDTO(id: "9", title: "Bilim"),
            ForumDTO(id: "36", title: "Aile ve Yaşam"),
            ForumDTO(id: "40", title: "İnceleme"),
            ForumDTO(id: "41", title: "Işık")
        ]
        let sorted = BookCategoryCatalog.sorted(categories, locale: Locale(identifier: "tr_TR"))

        XCTAssertEqual(sorted.map(\.title), ["Aile ve Yaşam", "Bilim", "Çocuk", "Edebiyat", "Işık", "İnceleme", "Roman"])
        XCTAssertEqual(Set(sorted.map(\.id)), Set(categories.map(\.id)))
        XCTAssertEqual(BookCategoryCatalog.sorted(categories), sorted)
    }

    func testEqualTitlesHaveDeterministicIDOrderRegardlessOfInputOrder() {
        let categories = [
            ForumDTO(id: "7", title: "Roman"),
            ForumDTO(id: "6", title: "Roman"),
            ForumDTO(id: "8", title: "Roman")
        ]
        let sorted = BookCategoryCatalog.sorted(categories)

        XCTAssertEqual(sorted.map(\.id), ["6", "7", "8"])
        XCTAssertEqual(BookCategoryCatalog.sorted(Array(categories.reversed())), sorted)
    }

    private var expectedCategories: [(id: String, title: String)] {
        [
            ("6", "Roman"), ("7", "Edebiyat"), ("8", "Eğitim"), ("9", "Bilim"),
            ("10", "Tarih"), ("11", "Din"), ("12", "Psikoloji"), ("13", "Kişisel Gelişim"),
            ("14", "Ekonomi"), ("15", "Çocuk"), ("16", "Biyografi"), ("17", "Felsefe"),
            ("18", "Öykü / Hikaye"), ("19", "Siyaset"), ("20", "Romantik"), ("21", "Fantastik"),
            ("22", "Bilimkurgu"), ("23", "Macera"), ("24", "Polisiye"), ("25", "Korku / Gerilim"),
            ("26", "Gençlik"), ("27", "Sağlık"), ("28", "Türk Klasikleri"), ("29", "Dünya Klasikleri"),
            ("30", "Teknoloji / Bilişim"), ("32", "Yabancı Dil"), ("33", "Kültür / Sanat"),
            ("34", "Sinema / Tiyatro"), ("35", "Akademik"), ("36", "Aile ve Yaşam"),
            ("37", "Yemek / Mutfak"), ("38", "Masal")
        ]
    }
}
