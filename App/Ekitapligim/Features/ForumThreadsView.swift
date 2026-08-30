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
                    VStack(spacing: 0) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.primary)
                        Spacer().frame(height: 12)
                        Text(L10n.forumThreadsEmptyTitle)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 8)
                        Text(L10n.forumThreadsEmptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 16)
                        Button(L10n.forumThreadsCreateDialogTitle) {
                            showCreateSheet = true
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(24)
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
                                        ForumThreadCard(thread: thread)
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
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFFFCF4), Color(hex: 0xFAF6EC), Color(hex: 0xF5FBFA), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
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
                    .foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 52, height: 52)
                    .background(Color(hex: 0xF1F8F7), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color(hex: 0xD9C79F), lineWidth: 1)
                    }

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
                    .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
private struct ForumThreadCard: View {
    let thread: ForumThreadDTO

    private var displayUsername: String {
        ForumMessageFormatting.displayUsername(thread.username)
    }

    private var initial: String {
        String(displayUsername.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Text(initial)
                .font(.system(.title3, design: .serif).weight(.heavy))
                .foregroundStyle(Color(hex: 0x087A80))
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xEDF7F5), Color(hex: 0xFFF8EA)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 5) {
                    if thread.isSticky {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: 0xCF8A18))
                            .accessibilityLabel(L10n.forumThreadsSticky)
                    }
                    Text(thread.title)
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(Color(hex: 0x0E1B2B))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    Text(displayUsername)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(hex: 0x687385))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    metricPill(systemImage: "bubble.left", value: thread.replyCount)
                    metricPill(systemImage: "eye", value: thread.viewCount)
                }
            }

            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(hex: 0x87939D))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.99), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xE1ECEA), lineWidth: 1)
        }
    }

    private func metricPill(systemImage: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text("\(value)")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Color(hex: 0x087A80))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(hex: 0xF7F4EA), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: 0xE8E2D2), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.forumThreadsCreateDialogTitle)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(L10n.forumThreadsCreateTitlePlaceholder, text: $title)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.sentences)
            TextField(L10n.forumThreadsCreateMessageSection, text: $message, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...8)
            HStack {
                Spacer(minLength: 0)
                Button(L10n.commonCancel) { dismiss() }
                Button(L10n.forumThreadsCreateSubmit) {
                    Task {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        if await submit(trimmedTitle, trimmedMessage) {
                            title = ""
                            message = ""
                            dismiss()
                        }
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
