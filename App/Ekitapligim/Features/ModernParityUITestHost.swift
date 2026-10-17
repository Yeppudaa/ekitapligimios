#if DEBUG
import SwiftUI
import Foundation
import EkitapligimCore

/// Offline harness for the shipping SwiftUI screens. All transports are intercepted, including
/// unexpected requests; mutations receive 405 except the explicit, local audio playback fixture.
/// No bootstrap runs and no request or mutation can leave the simulator.
@MainActor
struct ModernParityUITestHost: View {
    @StateObject private var fixtureContainer: AppContainer
    @State private var audioController: AudioPlaybackController?
    private let audioRepository: AudioRepository?
    private let fixtureSession: ModernParityTokenStore
    private let screen: String
    private let guest: Bool
    private let largeText: Bool
    private let dark: Bool
    @State private var prepared = false
    @State private var audioID: Int?
    @State private var audioLibrary = false
    @State private var audioPlayer = false

    init() {
        let environment = ProcessInfo.processInfo.environment
        screen = environment["MODERN_PARITY_SCREEN"] ?? "home"
        guest = environment["MODERN_PARITY_GUEST"] == "1"
        largeText = environment["MODERN_PARITY_LARGE_TEXT"] == "1"
        dark = environment["MODERN_PARITY_DARK"] == "1"
        URLProtocol.registerClass(ModernParityProtocol.self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModernParityProtocol.self]
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpAdditionalHeaders = [ModernParityAudioFixture.markerHeader: ModernParityAudioFixture.markerValue]
        let session = URLSession(configuration: configuration)
        let tokens = ModernParityTokenStore(guest: guest)
        fixtureSession = tokens
        let container = AppContainer(apiSession: session, tokenStore: tokens)
        _fixtureContainer = StateObject(wrappedValue: container)
        // Keep production origin validation intact: the injected protocol captures all traffic locally.
        // Root navigation and standalone audio screenshots observe the very same playback instance.
        audioRepository = container.audioRepository
        _audioController = State(initialValue: container.audioPlayback)
    }

    var body: some View {
        Group {
            if prepared {
                content
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("modern-parity-ready")
            } else {
                ProgressView().accessibilityIdentifier("modern-parity-preparing")
            }
        }
        .environmentObject(fixtureContainer)
        .dynamicTypeSize(largeText ? .accessibility3 : .large)
        .preferredColorScheme(dark ? .dark : .light)
        .task {
            guard !prepared else { return }
            if let session = try? await fixtureSession.loadSession() {
                fixtureContainer.authState = .signedIn(session)
                // Cancel observer tasks synchronously, before yielding the main actor. The harness
                // does not enumerate entitlements, prepare products, restore, purchase or register push.
                fixtureContainer.storeKit.stopObservingTransactions()
                await fixtureContainer.refreshSessionData()
            }
            if screen == "catalog" { fixtureContainer.selectedTab = .catalog }
            if screen == "profile" { fixtureContainer.selectedTab = .profile }
            if ModernParityAudioFixture.enabled, let audioController {
                audioController.activate(account: ModernParityTokenStore.username)
                audioController.setVolume(0)
                audioController.start(bookID: 101)
            }
            prepared = true
        }
        .onDisappear { audioController?.close(); fixtureContainer.storeKit.stopObservingTransactions() }
    }

    @ViewBuilder private var content: some View {
        switch screen {
        case "home", "menu", "catalog", "profile": RootView().environment(\.scenePhase, .inactive)
        case "library": NavigationStack { LibraryView() }
        case "requests": NavigationStack { BookRequestsView() }
        case "forum": CommunityView()
        case "threads": NavigationStack { ForumThreadsView(forum: ForumDTO(id: "1", title: "Kitap Kulübü", description: "Okuduğumuz kitapları birlikte keşfedelim.")) }
        case "authors": NavigationStack { DirectoryView(kind: .author) }
        case "publishers": NavigationStack { DirectoryView(kind: .publisher) }
        case "agenda": NavigationStack { BookAgendaView() }
        case "live": NavigationStack { LiveActivityView() }
        case "notifications": NavigationStack { NotificationsView() }
        case "chat": NavigationStack { ChatView(initialRoomID: "4") }
        case "audio", "audio-detail", "audio-library", "audio-player": audioContent
        default: Text("Unknown fixture screen").accessibilityIdentifier("modern-parity-error")
        }
    }

    @ViewBuilder private var audioContent: some View {
        if let audioRepository, let audioController {
            NavigationStack {
                Group {
                    if screen == "audio-player" {
                        AudioPlayerView(controller: audioController, onBook: { audioID = $0 }, onPremium: {}, onLogin: {})
                    }
                    else if screen == "audio-detail" { audioDetail(101, repository: audioRepository, controller: audioController) }
                    else if screen == "audio-library" { audioLibraryView(repository: audioRepository, controller: audioController) }
                    else {
                        AudioBooksView(repository: audioRepository, controller: audioController,
                            account: guest ? nil : ModernParityTokenStore.username,
                            onBook: { audioID = $0 }, onLibrary: { audioLibrary = true },
                            onLogin: {}, onPremium: {})
                    }
                }
                .navigationDestination(item: $audioID) { id in audioDetail(id, repository: audioRepository, controller: audioController) }
                .navigationDestination(isPresented: $audioLibrary) { audioLibraryView(repository: audioRepository, controller: audioController) }
                .navigationDestination(isPresented: $audioPlayer) { AudioPlayerView(controller: audioController, onBook: { audioID = $0 }, onPremium: {}, onLogin: {}) }
            }
        } else { Text("Fixture configuration error").accessibilityIdentifier("modern-parity-error") }
    }

    private func audioDetail(_ id: Int, repository: AudioRepository, controller: AudioPlaybackController) -> some View {
        AudioBookDetailView(bookID: id, repository: repository, controller: controller,
            account: guest ? nil : ModernParityTokenStore.username, onBook: { audioID = $0 },
            onLogin: {}, onPremium: {}, onPlayer: { audioPlayer = true })
    }
    private func audioLibraryView(repository: AudioRepository, controller: AudioPlaybackController) -> some View {
        AudioLibraryView(repository: repository, controller: controller,
            account: guest ? nil : ModernParityTokenStore.username,
            onBook: { audioID = $0 }, onBrowse: { audioLibrary = false }, onLogin: {})
    }
}

private actor ModernParityTokenStore: TokenStore {
    static let username = "parity-fixture"
    private let guest: Bool
    init(guest: Bool) { self.guest = guest }
    func accessToken() async throws -> String? { guest ? nil : "ms_at_offline_fixture_never_send_to_network" }
    func loadSession() async throws -> Session? {
        guest ? nil : Session(accessToken: "ms_at_offline_fixture_never_send_to_network", refreshToken: nil, username: Self.username, userID: "900001")
    }
    func save(session: Session) async throws {}
    func clear() async throws {}
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool { false }
}

private final class ModernParityProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return }
        if let result = ModernParityAudioFixture.response(for: request) {
            deliver(url: url, status: result.status, headers: result.headers, data: result.data)
            return
        }
        let readOnly = request.httpMethod == nil || request.httpMethod == "GET" || request.httpMethod == "HEAD"
        if readOnly, ["/books", "/books/"].contains(url.path),
           URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(.init(name: "featured", value: "1")) == true {
            let cards = (1...4).map { value in
                "<article class='xcuBktCatalog-card'><div class='xcuBktCatalog-bookTitle'><a href='/konular/offline-book.\(900040 + value)/'>Okurların seçtiği hikâye \(value)</a></div><div class='xcuBktCatalog-author'>Örnek Yazar</div><span class='xcuBktCatalog-tag'>Roman</span></article>"
            }.joined()
            deliver(url: url, status: 200, headers: ["Content-Type": "text/html; charset=utf-8"], data: Data(cards.utf8))
            return
        }
        let payload: [String: Any] = readOnly ? ModernParityPayload.response(for: url) : ["success": false, "errors": ["Offline UI fixtures reject all mutations."]]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotDecodeContentData)); return
        }
        deliver(url: url, status: readOnly ? 200 : 405, headers: ["Content-Type": "application/json", "Cache-Control": "no-store"], data: data)
    }
    private func deliver(url: URL, status: Int, headers: [String: String], data: Data) {
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotDecodeContentData)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        var offset = 0
        while offset < data.count {
            let end = min(data.count, offset + 65_536)
            client?.urlProtocol(self, didLoad: data.subdata(in: offset..<end)); offset = end
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// Synthetic books and accounts are purposefully distinct from production IDs and credentials.
private enum ModernParityPayload {
    static let timestamp = 1_792_230_000
    static let actor: [String: Any] = ["id": "900002", "username": "Ada", "avatar_url": "", "is_premium": false]
    static let profile: [String: Any] = ["id": "900001", "username": "parity-fixture", "email": "fixture@example.invalid", "about": "Kitaplarla yeni dünyalar keşfediyorum.", "message_count": 26, "reaction_score": 48, "trophy_points": 10, "is_online": true, "can_edit": true, "role": ["is_premium": true, "role_type": "premium", "role_label": "Premium Üye"], "avatar_url": "", "banner_url": ""]
    static let room: [String: Any] = ["id": 4, "name": "Okur Sohbeti", "description": "Kitaplar, yazarlar ve yeni keşifler üzerine sohbet edin.", "can_send": true, "user_count": 28, "is_read_only": false]
    static let forums: [[String: Any]] = [
        ["id": "1", "title": "Kitap Kulübü", "description": "Aynı hikâyede buluşalım. Okuduklarını paylaş, yeni kitaplar keşfet.", "thread_count": 18, "stats": "18 konu · 124 mesaj", "is_book_forum": true],
        ["id": "2", "title": "Okuma Köşesi", "description": "Yeni öneriler ve okuma yolculukları.", "thread_count": 12],
        ["id": "3", "title": "Edebiyat Üzerine", "description": "Yazarların ve kelimelerin dünyasına birlikte bakalım.", "thread_count": 34],
        ["id": "6", "title": "Roman", "description": "Yeni hikâyeler keşfet.", "thread_count": 120, "is_book_forum": true],
        ["id": "7", "title": "Edebiyat", "description": "Kelimelerin dünyası.", "thread_count": 84, "is_book_forum": true],
        ["id": "9", "title": "Bilim", "description": "Merakının peşinden git.", "thread_count": 32, "is_book_forum": true]
    ]
    static let library: [[String: Any]] = [
        ["book_id": "900042", "title": "Kutup Yıldızı - Yaz Rüzgârı", "author": "Örnek Yazar", "shelf_state": "reading", "progress_percent": 42, "last_read_page": 84, "page_count": 200, "cover_url": "", "is_favorite": true],
        ["book_id": "900043", "title": "Yeni Bir Hikâye", "author": "Örnek Yazar", "shelf_state": "want_to_read", "progress_percent": 0, "last_read_page": 0, "page_count": 240, "cover_url": ""]
    ]
    static let requests: [[String: Any]] = (1...6).map(requestItem)

    private static func requestItem(_ value: Int) -> [String: Any] {
        let title = value == 1 ? "Bir Sonraki Hikâyemiz" : "Okurların Seçtiği Kitap \(value)"
        let status = value == 3 ? "ACQUIRED" : value == 4 ? "REJECTED" : "PENDING"
        var item: [String: Any] = [:]
        item["id"] = String(910000 + value)
        item["title"] = title
        item["author"] = "Örnek Yazar"
        item["requested_by"] = "Ada"
        item["user_id"] = 900002
        item["vote_count"] = 8 + value
        item["status"] = status
        item["book_id"] = value == 3 ? "900042" : ""
        return item
    }
    static func book(_ value: Int) -> [String: Any] {
        ["id": String(900040 + value), "title": ["Varoluş Yolunda Sayılı Yıllar", "Sonsuzluğun Büyüsü", "Beyaz Zambaklar Ülkesinde", "Küçük Prens"][value % 4], "author": value == 3 ? "Grigori Petrov" : "Örnek Yazar", "publisher": "Örnek Yayınevi", "isbn": "", "category": "Roman", "language": "Türkçe", "publish_year": "2024", "description": "Her sayfada yeni bir dünya. Okuma yolculuğunda sana eşlik edecek bir hikâye.", "cover_url": "", "pdf_url": "", "page_count": 200, "is_premium_only": false, "view_count": 320, "download_count": 18, "rating": 4.5, "file_type": "PDF"]
    }
    static func audioBook(_ value: Int) -> [String: Any] {
        if ModernParityAudioFixture.enabled { return ModernParityAudioFixture.book(value) }
        return ["thread_id": value, "title": value == 101 ? "Beyaz Zambaklar Ülkesinde" : "Küçük Prens", "author": value == 101 ? "Grigori Petrov" : "Antoine de Saint-Exupéry", "narrator": "Örnek Seslendiren", "description": "Bir hikâyeye kulak ver. Okuma dünyasına yeni bir ses katan bu eserde her bölüm yeni bir yolculuk.", "cover_url": "", "duration": 5715, "duration_label": "1 sa 35 dk", "language": "Türkçe", "publisher": "Örnek Yayınevi", "can_listen": false, "chapter_count": 1, "categories": [["id": 1, "title": "Roman"]], "chapters": [["chapter_id": value * 10, "title": "Birinci Bölüm", "duration": 5715]], "user_state": ["saved": true, "progress": 42, "position": 2400, "chapter_id": value * 10]]
    }
    static func response(for url: URL) -> [String: Any] {
        let path = url.path
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let search = query.first { $0.name == "q" }?.value ?? ""
        if path.hasSuffix("/audio-library") {
            return ["api_version": 1, "books": [audioBook(101), audioBook(102)], "counts": ["saved": 2, "listening": 1, "completed": 0, "favorite": 1, "later": 1, "history": 2], "resume_book": audioBook(101), "stats": ["total": "1 sa 12 dk", "month": "42 dk", "completed": "0", "active": "1"]]
        }
        if path.hasSuffix("/audio-books") {
            let books = search.isEmpty ? [audioBook(101), audioBook(102)] : [audioBook(101)]
            return ["api_version": 1, "available": true, "books": books, "hero": audioBook(101), "categories": [["id": 1, "title": "Roman", "count": 2]], "pagination": ["page": 1, "pages": 1, "total": books.count], "sections": [["title": "Yeni eklenenler", "hint": "Dinleyeceğin yeni hikâyeler", "books": books]]]
        }
        if path.contains("/audio-books/") { return ["api_version": 1, "book": audioBook(Int(url.lastPathComponent) ?? 101), "related": [audioBook(102)], "same_author": []] }
        if path.hasSuffix("/book-stats") { return ["total_books": 35818, "total_authors": 13656, "total_publishers": 2000, "total_categories": 32] }
        if path.hasSuffix("/me/subscription") {
            let premium = ProcessInfo.processInfo.environment["MODERN_PARITY_STANDARD_MEMBER"] != "1"
            return ["is_premium": premium, "plan_name": premium ? "Premium" : "", "user_tier": premium ? "premium" : "member", "remaining_days": premium ? 24 : 0, "expiration_time": premium ? timestamp + 86400 * 24 : 0]
        }
        if path.hasSuffix("/me/library") { return ["items": library] }
        if path.hasSuffix("/me/reading-stats") { return ["daily_goal_minutes": 45, "total_pages": 324, "total_seconds": 7200, "today_pages": 22, "today_seconds": 960, "goal_progress_percent": 35, "streak_count": 6] }
        if path.hasSuffix("/me/notifications/counts") { return ["unread": 0, "conversations_unread": 0] }
        if path.hasSuffix("/me/notifications") {
            return ["items": [
                ["id": "970001", "type": "user", "action": "profile_visit", "title": "Profil ziyareti", "message": "Ada profilini ziyaret etti.", "actor_username": "Ada", "actor_user_id": 900002, "content_id": 900002, "app_route": "member/900002", "event_date": timestamp, "is_read": false],
                ["id": "970002", "type": "book", "title": "Kitap güncellemesi", "message": "Yeni Bir Hikâye hakkında toplulukta yeni bir paylaşım var.", "app_route": "book/900042", "event_date": timestamp - 300, "is_read": true]
            ], "counts": ["unread": 1, "unviewed": 1]]
        }
        if path.hasSuffix("/me/blocked-members") { return ["members": []] }
        if path.hasSuffix("/me") {
            var value = profile
            if ProcessInfo.processInfo.environment["MODERN_PARITY_STANDARD_MEMBER"] == "1" {
                value["role"] = ["is_premium": false, "role_type": "member", "role_label": "Üye"]
            }
            return value
        }
        if path.hasSuffix("/book-requests") { return ["items": requests] }
        if path.hasSuffix("/chat/rooms") { return ["items": [room], "capabilities": ["authenticated": true, "can_use": true]] }
        if path.contains("/chat/rooms/") {
            let after = query.first { $0.name == "after_id" }?.value
            let messages: [[String: Any]] = after == nil ? (1...24).map(chatMessageItem) : []
            let pagination: [String: Any] = ["oldest_id": 920001, "newest_id": 920024, "has_more": false]
            let reactions: [[String: Any]] = [["reaction_id": 1, "title": "Beğen", "emoji": "👍"]]
            var result: [String: Any] = [:]
            result["room"] = room
            result["items"] = messages
            result["pagination"] = pagination
            result["reaction_options"] = reactions
            return result
        }
        if path.hasSuffix("/live-activity") {
            let items: [[String: Any]] = (1...8).map(liveActivityItem)
            let pagination: [String: Any] = ["has_more": false]
            return ["items": items, "pagination": pagination]
        }
        if path.hasSuffix("/book-agenda") {
            let items: [[String: Any]] = (1...4).map(agendaItem)
            let capabilities: [String: Any] = ["authenticated": true, "can_create": true]
            let pagination: [String: Any] = ["page": 1, "has_more": false]
            return ["items": items, "capabilities": capabilities, "pagination": pagination]
        }
        if path.hasSuffix("/authors") || path.hasSuffix("/publishers") {
            let author = path.hasSuffix("/authors")
            let names = author ? ["Ahmet Hamdi Tanpınar", "Grigori Petrov", "Sabahattin Ali", "Stefan Zweig", "Zygmunt Bauman"] : ["Can Yayınları", "İletişim Yayınları", "Türkiye İş Bankası Kültür Yayınları", "Yapı Kredi Yayınları"]
            var items: [[String: Any]] = []
            for (index, name) in names.enumerated() where search.isEmpty || name.localizedStandardContains(search) {
                var item: [String: Any] = [:]
                item["id"] = String(950000 + index)
                item["name"] = name
                item["slug"] = "fixture-\(index)"
                item["book_count"] = 12 + index
                items.append(item)
            }
            let pagination: [String: Any] = ["page": 1, "pages": 1, "total": names.count]
            return ["items": items, "pagination": pagination]
        }
        if path.hasSuffix("/forums") || path.hasSuffix("/book-categories") { return ["forums": forums, "items": forums] }
        if path.contains("/forums/") && path.hasSuffix("/threads") {
            let threads: [[String: Any]] = (1...6).map(forumThreadItem)
            let pagination: [String: Any] = ["page": 1, "pages": 1]
            return ["threads": threads, "pagination": pagination]
        }
        if path.hasSuffix("/books") {
            let books: [[String: Any]] = (1...8).map(book)
            let pagination: [String: Any] = ["page": 1, "pages": 1, "total": 8]
            return ["books": books, "pagination": pagination]
        }
        if path.contains("/books/") { return ["book": book(2)] }
        if path.contains("/members/") { return ["member": ["id": "900002", "username": "Ada", "can_view_profile": true], "items": []] }
        if path.contains("bootstrap") { return ["enabled": false] }
        return ["items": [], "members": [], "posts": [], "success": true]
    }

    private static func chatMessageItem(_ value: Int) -> [String: Any] {
        var item: [String: Any] = [:]
        item["id"] = 920000 + value
        item["room_id"] = 4
        item["user_id"] = 900002
        item["username"] = "Ada"
        item["message"] = "\(value). mesaj · Kitaplar üzerine yeni bir sohbet. Uzun cümleler dar ekranda da rahat okunmalı."
        item["can_quote"] = true
        item["can_react"] = true
        item["message_date"] = timestamp + value
        return item
    }

    private static func liveActivityItem(_ value: Int) -> [String: Any] {
        let isAudio = value.isMultiple(of: 2)
        let referencedBook: [String: Any] = ["id": "900042", "title": "Beyaz Zambaklar Ülkesinde", "author": "Grigori Petrov", "cover_url": ""]
        var item: [String: Any] = [:]
        item["id"] = String(930000 + value)
        item["type"] = isAudio ? "audio_started" : "reading"
        item["message"] = isAudio ? "Ada sesli kitabı dinlemeye başladı." : "Ada okumaya başladı."
        item["event_date"] = timestamp + value
        item["actor"] = actor
        item["audio_book_id"] = isAudio ? "101" : ""
        item["app_route"] = isAudio ? "audiobook/101" : "book/900042"
        item["book"] = referencedBook
        return item
    }

    private static func agendaItem(_ value: Int) -> [String: Any] {
        let referencedBook: [String: Any] = ["id": "900042", "title": "Yeni Bir Hikâye", "author": "Örnek Yazar", "cover_url": ""]
        let viewer: [String: Any] = ["can_react": true, "can_bookmark": true]
        var item: [String: Any] = [:]
        item["id"] = String(940000 + value)
        item["type"] = value == 1 ? "quotation" : "standard"
        item["message"] = value == 1 ? "Bir kitap, hayatına yeni bir pencere açabilir." : "Bugün okuduklarımızdan güzel bir öneri paylaşalım."
        item["created_at"] = timestamp + value
        item["actor"] = actor
        item["book"] = referencedBook
        item["viewer"] = viewer
        item["reaction_score"] = 12
        return item
    }

    private static func forumThreadItem(_ value: Int) -> [String: Any] {
        var thread: [String: Any] = [:]
        thread["id"] = String(960000 + value)
        thread["title"] = "Okuma yolculuğumuz \(value)"
        thread["username"] = "Ada"
        thread["reply_count"] = value * 4
        thread["view_count"] = value * 25
        thread["post_date"] = timestamp
        thread["can_reply"] = true
        thread["is_sticky"] = value == 1
        return thread
    }
}
#endif
