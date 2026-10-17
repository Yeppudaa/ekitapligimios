import Foundation
import SwiftUI
import EkitapligimCore

@MainActor
final class AudioCatalogModel: ObservableObject {
    @Published private(set) var catalog: AudioCatalogDTO?
    @Published private(set) var categories: [AudioCategoryDTO] = []
    @Published private(set) var hero: AudioBookDTO?
    @Published private(set) var books: [AudioBookDTO] = []
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published var filters = AudioFilters()
    private let repository: any AudioServing
    private var generation = UUID()
    private var successfulCriteria: AudioCatalogCriteria?
    private var successfulPage = 0
    private var successfulPageCount = 1
    private var failedRequest: AudioCatalogPageRequest?
    var hasMore: Bool {
        successfulCriteria == AudioCatalogCriteria(filters) && successfulPage > 0 && successfulPage < successfulPageCount
    }
    init(repository: any AudioServing, filters: AudioFilters = .init()) { self.repository = repository; self.filters = filters }
    func load(append: Bool = false) async {
        if append { await more(); return }
        var requestFilters = filters
        requestFilters.page = 1
        await loadPage(requestFilters, append: false)
    }
    private func loadPage(_ requestFilters: AudioFilters, append: Bool) async {
        let criteria = AudioCatalogCriteria(requestFilters)
        guard criteria == AudioCatalogCriteria(filters) else { return }
        if append {
            guard successfulCriteria == criteria, successfulPage > 0,
                  requestFilters.page == successfulPage + 1, requestFilters.page <= successfulPageCount else { return }
        } else if successfulCriteria != criteria {
            // Browse artwork/categories remain useful, but results and pagination belong to one criteria set.
            books = []; catalog = nil; successfulCriteria = nil; successfulPage = 0; successfulPageCount = 1
        }
        generation = UUID(); let expected = generation; loading = true; error = nil; failedRequest = nil
        defer { if generation == expected { loading = false } }
        do {
            let result = try await repository.catalog(filters: requestFilters)
            try Task.checkCancellation()
            guard generation == expected, AudioCatalogCriteria(filters) == criteria else { return }
            catalog = result; filters = requestFilters
            if !result.categories.isEmpty { categories = result.categories }
            if let resultHero = result.hero { hero = resultHero }
            successfulCriteria = criteria; successfulPage = requestFilters.page; successfulPageCount = result.pagination.pages
            if append { let ids = Set(books.map(\.id)); books.append(contentsOf: result.books.filter { !ids.contains($0.id) }) }
            else { books = result.books }
        } catch is CancellationError { } catch {
            guard generation == expected, AudioCatalogCriteria(filters) == criteria else { return }
            self.error = AudioL10n.error(error); failedRequest = AudioCatalogPageRequest(filters: requestFilters, append: append)
        }
    }
    func apply(_ update: (inout AudioFilters) -> Void) async { update(&filters); filters.page = 1; await load() }
    func more() async {
        guard !loading, hasMore else { return }
        var next = filters; next.page = successfulPage + 1; await loadPage(next, append: true)
    }
    func retry() async {
        guard !loading else { return }
        if let failedRequest, AudioCatalogCriteria(failedRequest.filters) == AudioCatalogCriteria(filters) {
            await loadPage(failedRequest.filters, append: failedRequest.append)
        }
        else { await load() }
    }
}

private struct AudioCatalogCriteria: Equatable {
    let filters: AudioFilters
    init(_ filters: AudioFilters) {
        var criteria = filters; criteria.page = 1
        self.filters = criteria
    }
}

private struct AudioCatalogPageRequest {
    let filters: AudioFilters
    let append: Bool
}

@MainActor
final class AudioDetailModel: ObservableObject {
    @Published private(set) var detail: AudioDetailDTO?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var shelfBusy = false
    @Published private(set) var saved = false
    @Published private(set) var favorite = false
    @Published private(set) var later = false
    private let repository: any AudioServing
    let bookID: Int
    private var generation = UUID()
    private var activeAccount: String?
    private var didActivate = false
    private var shelfOperation: UUID?
    private var shelfRevision = 0
    init(bookID: Int, repository: any AudioServing) { self.bookID = bookID; self.repository = repository }
    func activate(account: String?) {
        guard !didActivate || activeAccount != account else { return }
        didActivate = true; activeAccount = account; generation = UUID(); detail = nil; error = nil; saved = false; favorite = false; later = false; shelfBusy = false; shelfOperation = nil; shelfRevision += 1
    }
    func load() async {
        generation = UUID(); let expected = generation; loading = true; error = nil
        let expectedShelfRevision = shelfRevision
        defer { if generation == expected { loading = false } }
        do {
            let result = try await repository.detail(bookID: bookID); try Task.checkCancellation()
            guard generation == expected else { return }; detail = result
            if expectedShelfRevision == shelfRevision, shelfOperation == nil { saved = result.book.state.saved; favorite = result.book.state.favorite; later = result.book.state.later }
        } catch is CancellationError { } catch { if generation == expected { self.error = AudioL10n.error(error) } }
    }
    func toggle(_ field: AudioShelfField, account: String?) async -> Bool {
        guard let account, activeAccount == account, !shelfBusy else { return false }
        let operation = UUID(); shelfOperation = operation; shelfBusy = true
        defer { if shelfOperation == operation { shelfBusy = false; shelfOperation = nil } }
        let value: Bool
        switch field { case .saved: value = !saved; case .favorite: value = !favorite; case .later: value = !later }
        do {
            try await repository.shelf(bookID: bookID, field: field, value: value, account: account)
            guard shelfOperation == operation, activeAccount == account else { return false }; shelfRevision += 1
            switch field { case .saved: saved = value; case .favorite: favorite = value; case .later: later = value }
            return true
        } catch is CancellationError { return false } catch { if shelfOperation == operation, activeAccount == account { self.error = AudioL10n.error(error) }; return false }
    }
}

@MainActor
final class AudioLibraryModel: ObservableObject {
    @Published private(set) var library: AudioLibraryDTO?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published var tab: AudioLibraryTab
    private let repository: any AudioServing
    private var generation = UUID()
    private var activeAccount: String?
    init(repository: any AudioServing, tab: AudioLibraryTab = .saved) { self.repository = repository; self.tab = tab }
    func load(account: String?) async {
        generation = UUID(); let expected = generation
        if activeAccount != account { activeAccount = account; library = nil; error = nil }
        guard let account else { library = nil; loading = false; error = nil; return }
        loading = true; error = nil
        defer { if expected == generation { loading = false } }
        do {
            let result = try await repository.library(tab: tab, account: account); try Task.checkCancellation()
            guard expected == generation else { return }; library = result
        } catch is CancellationError { } catch { if expected == generation { library = nil; self.error = AudioL10n.error(error) } }
    }
}

extension AudioLibraryTab {
    var localizedTitle: String { AudioL10n.text(rawValue + "Tab") }
}
