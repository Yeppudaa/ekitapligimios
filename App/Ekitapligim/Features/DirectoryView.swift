import SwiftUI
import EkitapligimCore

@MainActor
struct DirectoryView: View {
    @EnvironmentObject private var container: AppContainer
    let kind: DirectoryKind

    @State private var items: [DirectoryItemDTO] = []
    @State private var query = ""
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView(L10n.directoryLoading)
            } else if let errorMessage, items.isEmpty {
                ContentUnavailableView(
                    L10n.directoryUnavailableTitle,
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if items.isEmpty {
                ContentUnavailableView(
                    L10n.directoryEmptyTitle,
                    systemImage: "magnifyingglass",
                    description: Text(L10n.directoryEmptyDescription)
                )
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            DirectoryBooksView(kind: kind, item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text(L10n.directoryBookCount(item.bookCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    if currentPage < lastPage {
                        Button(L10n.commonLoadMore) {
                            Task { await load(reset: false) }
                        }
                        .disabled(isLoading)
                    }
                }
            }
        }
        .navigationTitle(kind == .author ? L10n.directoryAuthorsTitle : L10n.directoryPublishersTitle)
        .searchable(text: $query, prompt: L10n.directorySearchPrompt)
        .task { await load(reset: true) }
        .onSubmit(of: .search) { Task { await load(reset: true) } }
    }

    private func load(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let page = reset ? 1 : currentPage + 1
        do {
            let result = try await container.directories.items(
                kind: kind,
                page: page,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            items = reset ? result.items : items + result.items.filter { newItem in
                !items.contains(where: { $0.id == newItem.id })
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
        } catch {
            errorMessage = L10n.directoryLoadFailed
        }
    }
}

@MainActor
private struct DirectoryBooksView: View {
    @EnvironmentObject private var container: AppContainer
    let kind: DirectoryKind
    let item: DirectoryItemDTO

    @State private var books: [BookDTO] = []
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && books.isEmpty {
                ProgressView(L10n.catalogLoading)
            } else if let errorMessage, books.isEmpty {
                ContentUnavailableView(L10n.catalogUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if books.isEmpty {
                ContentUnavailableView(L10n.catalogEmptyTitle, systemImage: "books.vertical", description: Text(L10n.catalogEmptyDescription))
            } else {
                List {
                    ForEach(books) { book in
                        NavigationLink {
                            BookDetailView(bookID: Int(book.id) ?? 0)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title).font(.headline)
                                Text(kind == .author ? book.publisher : book.author)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    if currentPage < lastPage {
                        Button(L10n.commonLoadMore) {
                            Task { await load() }
                        }
                        .disabled(isLoading)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .task { await load() }
    }

    private func load() async {
        guard !isLoading, currentPage < lastPage || currentPage == 0 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await container.directories.books(kind: kind, slug: item.slug, page: currentPage + 1)
            books += result.books.filter { newBook in
                !books.contains(where: { $0.id == newBook.id })
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
        } catch {
            errorMessage = L10n.catalogLoadFailed
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
