import SwiftUI
import EkitapligimCore

@MainActor
struct BookRequestsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var requests: [BookRequestDTO] = []
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var operationError: String?
    @State private var showCreateSheet = false
    @State private var showLoginAlert = false

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }

    var body: some View {
        Group {
            if isLoading && requests.isEmpty {
                ProgressView(L10n.bookRequestsLoading)
            } else if let errorMessage, requests.isEmpty {
                ContentUnavailableView(L10n.bookRequestsUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if requests.isEmpty {
                ContentUnavailableView(L10n.bookRequestsEmptyTitle, systemImage: "text.badge.plus", description: Text(L10n.bookRequestsEmptyDescription))
            } else {
                List(requests) { request in
                    BookRequestRow(
                        request: request,
                        isSubmitting: isSubmitting,
                        canVote: request.status == "PENDING",
                        onVote: { Task { await vote(request) } }
                    )
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(L10n.bookRequestsTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isSignedIn { showCreateSheet = true } else { showLoginAlert = true }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.bookRequestsCreate)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCreateSheet) {
            BookRequestCreateView(isSubmitting: isSubmitting) { title, author, isbn in
                await create(title: title, author: author, isbn: isbn)
            }
        }
        .alert(L10n.bookRequestsLoginRequiredTitle, isPresented: $showLoginAlert) {
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .settings }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.bookRequestsLoginRequiredMessage)
        }
        .alert(
            L10n.bookRequestsActionFailedTitle,
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button(L10n.commonClose) { operationError = nil }
        } message: {
            Text(operationError ?? L10n.bookRequestsActionFailedMessage)
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            requests = try await container.bookRequests.requests().items
        } catch {
            errorMessage = L10n.bookRequestsLoadFailed
        }
    }

    private func vote(_ request: BookRequestDTO) async {
        guard isSignedIn, !isSubmitting else {
            showLoginAlert = !isSignedIn
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await container.bookRequests.toggleVote(id: request.id)
            await load()
        } catch {
            operationError = L10n.bookRequestsVoteFailed
        }
    }

    private func create(title: String, author: String, isbn: String) async -> Bool {
        guard isSignedIn, !isSubmitting else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await container.bookRequests.create(title: title, author: author, isbn: isbn)
            showCreateSheet = false
            await load()
            return true
        } catch {
            return false
        }
    }
}

private struct BookRequestRow: View {
    let request: BookRequestDTO
    let isSubmitting: Bool
    let canVote: Bool
    let onVote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(request.title).font(.headline)
                Text(request.author.isEmpty ? L10n.bookRequestsAuthorMissing : request.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !request.requestedBy.isEmpty {
                    Text(L10n.bookRequestsRequestedBy(request.requestedBy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(L10n.bookRequestsStatus(request.status))
                    .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 8)
            Button(action: onVote) {
                VStack(spacing: 3) {
                    Image(systemName: "hand.thumbsup")
                    Text("\(request.voteCount)")
                        .font(.caption.monospacedDigit())
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .disabled(!canVote || isSubmitting)
            .accessibilityLabel(L10n.bookRequestsVoteCount(request.voteCount))
        }
        .padding(.vertical, 5)
    }
}

private struct BookRequestCreateView: View {
    @Environment(\.dismiss) private var dismiss
    let isSubmitting: Bool
    let submit: (String, String, String) async -> Bool

    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var submissionFailed = false

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.bookRequestsBookTitle, text: $title)
                    .onChange(of: title) { _, value in title = String(value.prefix(255)) }
                TextField(L10n.bookRequestsAuthor, text: $author)
                    .onChange(of: author) { _, value in author = String(value.prefix(255)) }
                TextField(L10n.bookRequestsISBN, text: $isbn)
                    .textInputAutocapitalization(.never)
                    .onChange(of: isbn) { _, value in isbn = String(value.prefix(32)) }
                if submissionFailed {
                    Text(L10n.bookRequestsCreateFailed)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(L10n.bookRequestsCreate)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? L10n.bookRequestsSubmitting : L10n.commonSubmit) {
                        Task {
                            submissionFailed = false
                            if await submit(title.trimmed, author.trimmed, isbn.trimmed) {
                                dismiss()
                            } else {
                                submissionFailed = true
                            }
                        }
                    }
                    .disabled(title.trimmed.isEmpty || isSubmitting)
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
