import SwiftUI
import EkitapligimCore

@MainActor
struct ForumThreadsView: View {
    @EnvironmentObject private var container: AppContainer
    let forum: ForumDTO

    @State private var threads: [ForumThreadDTO] = []
    @State private var currentPage = 1
    @State private var lastPage = 1
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var operationError: String?
    @State private var statusMessage: String?
    @State private var showCreateSheet = false
    @State private var showLoginAlert = false
    @State private var showingTerms = false
    @State private var heroCollapseProgress: CGFloat = 0

    private let contentSafety = ContentSafety()

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && threads.isEmpty {
                    EKLoadingState(message: L10n.forumThreadsLoading)
                } else if let errorMessage, threads.isEmpty {
                    EKErrorState(title: L10n.forumThreadsUnavailableTitle, message: errorMessage, retryTitle: L10n.commonRetryAgain) {
                        Task { await load(reset: true) }
                    }
                } else if threads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 78, height: 78)
                            .background(
                                LinearGradient(
                                    colors: [EKitapligimPalette.forumTeal, EKitapligimPalette.forumTealDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                            .shadow(color: EKitapligimPalette.forumTeal.opacity(0.25), radius: 12, y: 6)
                        Text(L10n.forumThreadsEmptyTitle)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(EKitapligimPalette.forumInk)
                            .multilineTextAlignment(.center)
                        Text(L10n.forumThreadsEmptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(EKitapligimPalette.forumMuted)
                            .multilineTextAlignment(.center)
                        Button(L10n.forumThreadsCreateDialogTitle) {
                            showCreateSheet = true
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [EKitapligimPalette.forumTeal, EKitapligimPalette.forumTealDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            EKScrollOffsetTracker()
                            heroCard

                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(EKitapligimPalette.success)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }

                            ForEach(threads.filter { thread in
                                guard let userID = thread.userId else { return true }
                                return !container.blockedUserIDs.contains(userID)
                            }) { thread in
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink {
                                        ForumThreadDetailView(thread: thread)
                                    } label: {
                                        EKForumThreadRow(thread: thread)
                                    }
                                    .buttonStyle(.plain)
                                    if let firstPostID = thread.firstPostId {
                                        UGCSafetyMenu(
                                            type: .forumPost,
                                            contentID: firstPostID,
                                            userID: thread.userId
                                        ) {
                                            threads.removeAll { $0.userId == thread.userId }
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                            if currentPage < lastPage {
                                EKLoadMoreButton(
                                    isLoading: isLoadingMore,
                                    title: L10n.forumThreadsLoadMore,
                                    loadingTitle: L10n.forumThreadsLoadMoreLoading
                                ) {
                                    Task { await load(reset: false) }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await load(reset: true) }
                    .ekCollapsibleScrollTracking { heroCollapseProgress = $0 }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .forumPageBackground()
        }
        .navigationTitle(forum.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.forumThreadsCreateAccessibility)
            }
        }
        .task { await load(reset: true) }
        .sheet(isPresented: $showCreateSheet) {
            ForumThreadCreateView(isSubmitting: isSubmitting) { title, message in
                await create(title: title, message: message)
            }
        }
        .sheet(isPresented: $showingTerms) {
            TermsAcceptanceView()
        }
        .alert(L10n.bookRequestsLoginRequiredTitle, isPresented: $showLoginAlert) {
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .profile }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.forumThreadsLoginRequiredMessage)
        }
        .alert(
            L10n.forumThreadsCreateFailedTitle,
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button(L10n.commonClose) { operationError = nil }
        } message: {
            Text(operationError ?? L10n.forumThreadsCreateFailedMessage)
        }
    }

    private var heroCard: some View {
        EKCollapsibleHero(progress: heroCollapseProgress) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "text.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [EKitapligimPalette.forumTeal, EKitapligimPalette.forumTealDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .shadow(color: EKitapligimPalette.forumTeal.opacity(0.22), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(forum.title)
                        .font(.system(.title3, design: .serif).weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.ink)
                        .lineLimit(2)
                    Text(L10n.forumThreadsCommunitySubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                    HStack(spacing: 6) {
                        Text("\(threads.count)")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(EKitapligimPalette.teal)
                        Text(L10n.forumThreadsHeroMetricLabel)
                            .font(.subheadline)
                            .foregroundStyle(EKitapligimPalette.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                        Text(L10n.forumThreadsCreate)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [EKitapligimPalette.forumTeal, EKitapligimPalette.forumTealDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.forumThreadsCreate)
            }
            .padding(14)
            .forumHeroSurface(radius: 16)
        } collapsed: {
            HStack(spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: 0xF2F8F6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: 0xE2C48E), lineWidth: 1)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(forum.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.ink)
                        .lineLimit(1)
                    Text(L10n.forumThreadsCollapsedCount(threads.count))
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.muted)
                }
                Spacer(minLength: 0)
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.teal)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.96), in: Circle())
                        .overlay(Circle().stroke(Color(hex: 0xE2B866), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.forumThreadsCreateAccessibility)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .forumHeroSurface(radius: 14)
        }
    }

    private func load(reset: Bool = true) async {
        guard let forumID = Int(forum.id) else {
            errorMessage = L10n.forumThreadsInvalidForum
            return
        }
        if reset {
            isLoading = true
        } else {
            guard !isLoadingMore, currentPage < lastPage else { return }
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }
        let targetPage = reset ? 1 : currentPage + 1
        do {
            let page = try await container.community.threads(forumID: forumID, page: targetPage)
            let incoming = page.threads
            threads = reset ? incoming : threads + incoming.filter { item in
                !threads.contains(where: { $0.id == item.id })
            }
            currentPage = page.currentPage ?? targetPage
            lastPage = max(page.lastPage ?? targetPage, currentPage)
            errorMessage = nil
        } catch {
            if reset {
                errorMessage = L10n.forumThreadsLoadFailed
            }
        }
    }

    private func create(title: String, message: String) async -> Bool {
        guard !isSubmitting, let forumID = Int(forum.id) else { return false }
        guard isSignedIn else {
            showLoginAlert = true
            return false
        }

        switch contentSafety.validateUserGeneratedText(title) {
        case .accepted:
            break
        case .rejected(let reason):
            operationError = reason.userMessage
            return false
        }
        switch contentSafety.validateUserGeneratedText(message) {
        case .accepted:
            break
        case .rejected(let reason):
            operationError = reason.userMessage
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let terms = try? await container.account.termsStatus()
            if terms?.requiresAcceptance == true {
                showingTerms = true
                return false
            }
            let thread = try await container.community.createThread(forumID: forumID, title: title, message: message)
            threads.insert(thread, at: 0)
            statusMessage = L10n.forumThreadsCreateSuccess
            showCreateSheet = false
            return true
        } catch {
            operationError = L10n.forumThreadsCreateFailedMessage
            return false
        }
    }
}

@MainActor
private struct ForumThreadCreateView: View {
    @Environment(\.dismiss) private var dismiss
    let isSubmitting: Bool
    let submit: (String, String) async -> Bool

    @State private var title = ""
    @State private var message = ""

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.forumTeal)
                    .frame(width: 42, height: 42)
                    .background(EKitapligimPalette.forumTealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(L10n.forumThreadsCreateDialogTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.forumInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.forumThreadsCreateTitlePlaceholder)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.forumMuted)
                TextField(L10n.forumThreadsCreateTitlePlaceholder, text: $title)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(EKitapligimPalette.forumBorder, lineWidth: 1)
                    }
                    .textInputAutocapitalization(.sentences)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.forumThreadsCreateMessageSection)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.forumMuted)
                TextEditor(text: $message)
                    .accessibilityLabel(L10n.forumThreadsCreateMessageSection)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(EKitapligimPalette.forumBorder, lineWidth: 1)
                    }
                    .overlay(alignment: .topLeading) {
                        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(L10n.forumThreadsCreateMessageSection)
                                .foregroundStyle(EKitapligimPalette.forumMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
            }

            HStack {
                Text("\(message.count) \(L10n.forumThreadReplyCountLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.forumMuted)
                Spacer(minLength: 0)
                Button(L10n.commonCancel) { dismiss() }
                    .foregroundStyle(EKitapligimPalette.forumMuted)
                Button {
                    Task {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        if await submit(trimmedTitle, trimmedMessage) {
                            title = ""
                            message = ""
                            dismiss()
                        }
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(L10n.forumThreadsCreateSubmit)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                canSubmit
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [EKitapligimPalette.forumTeal, EKitapligimPalette.forumTealDeep],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    : AnyShapeStyle(EKitapligimPalette.forumTeal.opacity(0.45)),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .background(EKitapligimPalette.forumSurface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
