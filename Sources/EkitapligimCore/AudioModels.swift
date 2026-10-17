import Foundation

public struct AudioCategoryDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let count: Int
    public init(id: Int, title: String, count: Int = 0) { self.id = id; self.title = title; self.count = count }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self)
        id = c.int("id"); title = c.text("title"); count = max(0, c.int("count"))
    }
}

public struct AudioChapterDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let duration: Double
    public let displayOrder: Int
    public let url: String
    public init(id: Int, title: String, duration: Double, displayOrder: Int = 0, url: String = "") {
        self.id = id; self.title = title; self.duration = AudioPolicy.finite(duration); self.displayOrder = displayOrder; self.url = url
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self)
        id = c.int("chapter_id"); title = c.text("title"); duration = max(0, c.number("duration"))
        displayOrder = c.int("display_order"); url = c.text("url")
    }
}

public struct AudioUserStateDTO: Decodable, Equatable, Sendable {
    public var chapterID: Int = 0
    public var position: Double = 0
    public var progress: Double = 0
    public var speed: Double = 1
    public var lastListen: Int = 0
    public var completedDate: Int = 0
    public var saved = false
    public var favorite = false
    public var later = false
    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self)
        chapterID = c.int("chapter_id"); position = max(0, c.number("position")); progress = min(100, max(0, c.number("progress")))
        speed = min(2, max(0.5, c.number("speed", fallback: 1))); lastListen = c.int("last_listen"); completedDate = c.int("completed_date")
        saved = c.flag("saved"); favorite = c.flag("favorite"); later = c.flag("later")
    }
}

public struct AudioBookDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let author: String
    public let narrator: String
    public let description: String
    public let coverURL: String
    public let url: String
    public let duration: Double
    public let durationLabel: String
    public let language: String
    public let publisher: String
    public let publicationDate: String
    public let rating: Double?
    public let ratingCount: Int
    public let categories: [AudioCategoryDTO]
    public let chapters: [AudioChapterDTO]
    public let chapterCount: Int
    public let canListen: Bool
    public let featured: Bool
    public let editorPick: Bool
    public let weeklyPick: Bool
    public let isDemo: Bool
    public var state: AudioUserStateDTO
    public init(id: Int, title: String, author: String = "", coverURL: String = "", duration: Double = 0,
                description: String = "", chapters: [AudioChapterDTO] = [], canListen: Bool = false,
                state: AudioUserStateDTO = .init()) {
        self.id = id; self.title = title; self.author = author; self.coverURL = coverURL; self.duration = AudioPolicy.finite(duration)
        self.description = description; self.chapters = chapters; self.canListen = canListen; self.state = state
        narrator = ""; url = ""; durationLabel = ""; language = ""; publisher = ""; publicationDate = ""; rating = nil
        ratingCount = 0; categories = []; chapterCount = chapters.count; featured = false; editorPick = false; weeklyPick = false; isDemo = false
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self)
        id = c.int("thread_id"); guard id > 0 else { throw AudioError.invalidResponse }
        title = c.text("title"); author = c.text("author"); narrator = c.text("narrator"); description = c.text("description")
        coverURL = c.text("cover_url", fallback: c.text("cover")); url = c.text("url")
        duration = max(0, c.number("duration")); durationLabel = c.text("duration_label"); language = c.text("language")
        publisher = c.text("publisher"); publicationDate = c.text("publication_date")
        rating = Double(c.text("rating")).flatMap { $0.isFinite ? $0 : nil }
        ratingCount = max(0, c.int("rating_count")); categories = c.value("categories", fallback: [])
        chapters = c.value("chapters", fallback: []); chapterCount = max(0, c.int("chapter_count", fallback: chapters.count))
        canListen = c.flag("can_listen"); featured = c.flag("featured"); editorPick = c.flag("editor_pick"); weeklyPick = c.flag("weekly_pick")
        state = c.value("user_state", fallback: .init()); isDemo = c.flag("is_demo")
    }
}

public struct AudioShelfDTO: Decodable, Equatable, Sendable {
    public let title: String
    public let hint: String
    public let books: [AudioBookDTO]
    public init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: AudioKey.self); title = c.text("title"); hint = c.text("hint"); books = c.value("books", fallback: []) }
}

public struct AudioPaginationDTO: Decodable, Equatable, Sendable {
    public let page: Int
    public let pages: Int
    public let total: Int
    public init(page: Int = 1, pages: Int = 1, total: Int = 0) { self.page = page; self.pages = pages; self.total = total }
    public init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: AudioKey.self); page = max(1, c.int("page", fallback: 1)); pages = max(1, c.int("pages", fallback: 1)); total = max(0, c.int("total")) }
}
public struct AudioCatalogDTO: Decodable, Equatable, Sendable {
    public let books: [AudioBookDTO]
    public let categories: [AudioCategoryDTO]
    public let sections: [AudioShelfDTO]
    public let hero: AudioBookDTO?
    public let pagination: AudioPaginationDTO
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self)
        try c.validateVersion()
        if c.contains(AudioKey("available")), !c.flag("available") { throw AudioError.unavailable }
        books = try c.decode([AudioBookDTO].self, forKey: AudioKey("books")); categories = c.value("categories", fallback: []); sections = c.value("sections", fallback: [])
        hero = try c.decodeIfPresent(AudioBookDTO.self, forKey: AudioKey("hero")); pagination = c.value("pagination", fallback: .init())
    }
}
public struct AudioDetailDTO: Decodable, Equatable, Sendable {
    public let book: AudioBookDTO
    public let related: [AudioBookDTO]
    public let sameAuthor: [AudioBookDTO]
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self); try c.validateVersion(); book = try c.decode(AudioBookDTO.self, forKey: AudioKey("book"))
        related = c.value("related", fallback: []); sameAuthor = c.value("same_author", fallback: [])
        // User comments and narrator recommendations are deliberately not presented on mobile.
    }
}
public enum AudioLibraryTab: String, CaseIterable, Sendable { case saved, listening, completed, later, favorite, history }
public enum AudioShelfField: String, Sendable { case saved, favorite, later }
public struct AudioLibraryDTO: Decodable, Equatable, Sendable {
    public let books: [AudioBookDTO]
    public let tab: String
    public let counts: [String: Int]
    public let resumeBook: AudioBookDTO?
    public let stats: [String: String]
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self); try c.validateVersion(); books = try c.decode([AudioBookDTO].self, forKey: AudioKey("books")); tab = c.text("tab", fallback: "saved")
        let countContainer = try? c.nestedContainer(keyedBy: AudioKey.self, forKey: AudioKey("counts"))
        counts = Dictionary(uniqueKeysWithValues: AudioLibraryTab.allCases.map { ($0.rawValue, max(0, countContainer?.int($0.rawValue) ?? 0)) })
        resumeBook = try c.decodeIfPresent(AudioBookDTO.self, forKey: AudioKey("resume_book"))
        let statsContainer = try? c.nestedContainer(keyedBy: AudioKey.self, forKey: AudioKey("stats"))
        stats = Dictionary(uniqueKeysWithValues: ["total", "month", "completed", "active", "top_category"].map { ($0, statsContainer?.text($0) ?? "0") })
    }
}
public enum AudioAnnotationKind: Sendable { case bookmark, note, quote }
public struct AudioBookmarkDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let chapterID: Int
    public let position: Double
    public let label: String
    public var kind: AudioAnnotationKind {
        if label.lowercased().hasPrefix("alıntı: ") { return .quote }
        if label.lowercased().hasPrefix("not: ") { return .note }
        return .bookmark
    }
    public var displayText: String {
        switch kind { case .quote: return String(label.dropFirst(8)); case .note: return String(label.dropFirst(5)); case .bookmark: return label }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self); id = c.int("bookmark_id"); chapterID = c.int("chapter_id")
        position = max(0, c.number("position")); label = c.text("label")
    }
}
public struct AudioManifestDTO: Decodable, Equatable, Sendable {
    public let session: String
    public let sequence: Int
    public let state: AudioUserStateDTO
    public let book: AudioBookDTO
    public let chapters: [AudioChapterDTO]
    public let bookmarks: [AudioBookmarkDTO]
    public let recommendations: [AudioBookDTO]
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self); try c.validateVersion(); session = c.text("session"); sequence = max(0, c.int("sequence"))
        state = c.value("state", fallback: .init()); book = try c.decode(AudioBookDTO.self, forKey: AudioKey("book"))
        chapters = try c.decode([AudioChapterDTO].self, forKey: AudioKey("chapters")); bookmarks = c.value("bookmarks", fallback: [])
        recommendations = c.value("recommendations", fallback: [])
        guard !session.isEmpty, !chapters.isEmpty, chapters.allSatisfy({ $0.id > 0 && !$0.url.isEmpty }), Set(chapters.map(\.id)).count == chapters.count else { throw AudioError.invalidResponse }
    }
}
public struct AudioProgressResponseDTO: Decodable, Equatable, Sendable {
    public let saved: Bool
    public let completed: Bool
    public let credited: Double
    public let state: AudioUserStateDTO?
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AudioKey.self); saved = c.flag("saved"); completed = c.flag("completed"); credited = max(0, c.number("credited"))
        state = try c.decodeIfPresent(AudioUserStateDTO.self, forKey: AudioKey("state"))
    }
}
public struct AudioFilters: Equatable, Sendable {
    public var query = ""
    public var category = 0
    public var sort = "new"
    public var language = ""
    public var maxDuration = 0
    public var page = 1
    public var author = ""
    public var narrator = ""
    public init() {}
    public var active: Bool { !query.isEmpty || category > 0 || sort != "new" || !language.isEmpty || maxDuration > 0 || !author.isEmpty || !narrator.isEmpty }
    public var queryItems: [URLQueryItem] {
        var pairs = ["q": query, "sort": sort, "language": language, "page": String(max(1, page)), "per_page": "24", "author": author, "narrator": narrator]
        if category > 0 { pairs["category"] = String(category) }; if maxDuration > 0 { pairs["max_duration"] = String(maxDuration) }
        return pairs.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}

struct AudioKey: CodingKey {
    let stringValue: String
    var intValue: Int? { Int(stringValue) }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { self.init(String(intValue)) }
}
extension KeyedDecodingContainer where Key == AudioKey {
    func validateVersion() throws { guard int("api_version") == 1 else { throw AudioError.invalidResponse } }
    func text(_ key: String, fallback: String = "") -> String {
        if let text = try? decode(String.self, forKey: AudioKey(key)), text != "null" { return text }
        if let n = try? decode(Int.self, forKey: AudioKey(key)) { return String(n) }
        if let n = try? decode(Double.self, forKey: AudioKey(key)), n.isFinite { return String(n) }
        return fallback
    }
    func int(_ key: String, fallback: Int = 0) -> Int { Int(text(key)) ?? fallback }
    func number(_ key: String, fallback: Double = 0) -> Double { guard let n = Double(text(key)), n.isFinite else { return fallback }; return n }
    func flag(_ key: String) -> Bool { (try? decode(Bool.self, forKey: AudioKey(key))) ?? ["1", "true"].contains(text(key).lowercased()) }
    func value<T: Decodable>(_ key: String, fallback: T) -> T { (try? decode(T.self, forKey: AudioKey(key))) ?? fallback }
}
