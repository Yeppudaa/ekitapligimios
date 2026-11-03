import XCTest
@testable import EkitapligimCore

final class LossyBookDecodingTests: XCTestCase {
    private func book(_ id: String) -> String {
        """
        {"id": "\(id)", "thread_id": \(id), "title": "Kitap \(id)", "author": "Yazar", "publisher": "Yayınevi",
         "isbn": "", "category": "Roman", "language": "Türkçe", "publish_year": "2026", "description": "",
         "cover_url": "", "pdf_url": "", "page_count": 10, "isPremiumOnly": false, "view_count": 1,
         "reaction_score": 0, "rating": 0, "file_type": "pdf"}
        """
    }

    func testOneMalformedBookDoesNotEmptyTheCatalogPage() throws {
        let data = Data("""
        {"books": [\(book("1")), "broken", {"id": null}, 42, \(book("2"))],
         "pagination": {"page": 1, "per_page": 20, "total": 5, "pages": 1}}
        """.utf8)
        let page = try JSONDecoder.ekitapligim.decode(BooksPageDTO.self, from: data)
        XCTAssertEqual(page.books.map(\.id), ["1", "2"])
        XCTAssertEqual(page.totalBooks, 5)
    }

    func testItemsKeyIsAlsoLossy() throws {
        let data = Data("""
        {"items": [{"title": "eksik"}, \(book("7"))]}
        """.utf8)
        let page = try JSONDecoder.ekitapligim.decode(BooksPageDTO.self, from: data)
        XCTAssertEqual(page.books.map(\.id), ["7"])
    }
}
