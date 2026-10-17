import SwiftUI
import EkitapligimCore

@MainActor
struct BookRequestsView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var items: [BookRequestDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var operationError: String?
    @State private var statusMessage: String?
    @State private var showCreateSheet = false
    @State private var showLoginAlert = false
    @State private var showingLogin = false
    @State private var isSubmitting = false
    @State private var votingID: String?
    @State private var draftTitle = ""
    @State private var draftAuthor = ""
    @State private var draftISBN = ""
    @State private var query = ""
    @State private var selectedStatus = ""

    private var visibleItems: [BookRequestDTO] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            (item.userId.map { !container.blockedUserIDs.contains($0) } ?? true)
            && (selectedStatus.isEmpty || item.status.uppercased() == selectedStatus)
            && (search.isEmpty || item.title.localizedStandardContains(search) || item.author.localizedStandardContains(search))
        }
    }

    private var featuredRequest: BookRequestDTO? {
        items.filter { item in
            item.allowsVote && (item.userId.map { !container.blockedUserIDs.contains($0) } ?? true)
        }.max { $0.voteCount < $1.voteCount }
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && items.isEmpty {
                    EKLoadingState(message: L10n.bookRequestsLoading)
                } else if let errorMessage, items.isEmpty {
                    EKErrorState(
                        title: L10n.bookRequestsUnavailableTitle,
                        message: errorMessage,
                        retry: { Task { await load() } }
                    )
                } else {
                    requestList
                }
            }
        }
        .navigationTitle(L10n.bookRequestsTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentCreate()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.bookRequestsCreate)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert(L10n.commonSuccess, isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button(L10n.commonClose) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .alert(L10n.bookRequestsActionFailedTitle, isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button(L10n.commonClose) { operationError = nil }
        } message: {
            Text(operationError ?? L10n.bookRequestsActionFailedMessage)
        }
        .alert(L10n.bookRequestsLoginRequiredTitle, isPresented: $showLoginAlert) {
            Button(L10n.commonCancel, role: .cancel) {}
            Button(L10n.bookRequestsGoToLogin) { showingLogin = true }
        } message: {
            Text(L10n.bookRequestsLoginRequiredMessage)
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .sheet(isPresented: $showCreateSheet) {
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.bookRequestsCreateDialogTitle)
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !container.isSignedIn {
                    Text(L10n.bookRequestsGuestCreateHint)
                        .font(.footnote)
                        .foregroundStyle(EKitapligimPalette.danger)
                }
                TextField(L10n.bookRequestsBookTitle, text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.bookRequestsAuthor, text: $draftAuthor)
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.bookRequestsISBN, text: $draftISBN)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                HStack {
                    Spacer(minLength: 0)
                    Button(L10n.commonCancel) { showCreateSheet = false }
                    Button(isSubmitting ? L10n.bookRequestsSubmitting : L10n.commonSubmit) {
                        Task { await submitRequest() }
                    }
                    .disabled(isSubmitting || !container.isSignedIn)
                }
            }
            .padding(20)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var requestList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    CommunityLiteraryHero(
                        artwork: "requests_wishlist_mobile",
                        wideArtwork: "requests_wishlist_wide",
                        eyebrow: CommunityRefreshL10n.text("requests.eyebrow"),
                        title: CommunityRefreshL10n.text("requests.title"),
                        emphasis: CommunityRefreshL10n.text("requests.emphasis"),
                        subtitle: CommunityRefreshL10n.text("requests.subtitle"),
                        actionTitle: L10n.bookRequestsCreate,
                        action: presentCreate
                    )
                    Button {
                        withAnimation { proxy.scrollTo("request-collection", anchor: .top) }
                    } label: {
                        Label(CommunityRefreshL10n.text("requests.discover"), systemImage: "arrow.down")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(.plain).foregroundStyle(EKitapligimPalette.teal)
                    requestStats
                    requestSteps
                    if let featuredRequest {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(CommunityRefreshL10n.text("requests.featured"), systemImage: "star")
                                .font(.caption2.weight(.semibold)).foregroundStyle(Color(hex: 0x867142))
                            BookRequestRow(item: featuredRequest, isVoting: votingID == featuredRequest.id) {
                                Task { await vote(on: featuredRequest) }
                            } onBlocked: {
                                if let userID = featuredRequest.userId { items.removeAll { $0.userId == userID } }
                            }
                        }
                        .padding(14).background(Color(hex: 0xF4F3E3), in: RoundedRectangle(cornerRadius: 20))
                    }
                    collectionHeader.id("request-collection")
                    requestFilters
                    if let errorMessage { EKInlineError(message: errorMessage) }
                    if visibleItems.isEmpty {
                        EKStateCard(title: L10n.bookRequestsEmptyTitle, message: CommunityRefreshL10n.count("requests.count", 0))
                    } else {
                        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                        ForEach(visibleItems) { item in
                            BookRequestRow(item: item, isVoting: votingID == item.id) {
                                Task { await vote(on: item) }
                            } onBlocked: {
                                if let userID = item.userId { items.removeAll { $0.userId == userID } }
                            }
                        }
                        }
                    }
                    CommunityInvitationCard(
                        eyebrow: CommunityRefreshL10n.text("requests.outroEyebrow"),
                        title: CommunityRefreshL10n.text("requests.outroTitle"),
                        subtitle: "",
                        actionTitle: L10n.bookRequestsCreate,
                        action: presentCreate
                    )
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    private var requestStats: some View {
        let metrics: [(String, Int, String)] = [
            ("requests.pending", items.filter { $0.allowsVote }.count, "hourglass"),
            ("requests.acquired", items.filter { $0.isAcquired }.count, "checkmark"),
            ("requests.rejected", items.filter { $0.status.uppercased() == "REJECTED" }.count, "shield"),
            ("requests.support", items.reduce(0) { $0 + $1.voteCount }, "heart")
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(metrics.indices, id: \.self) { index in
                let metric = metrics[index]
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(EKitapligimFormat.count(metric.1)).font(.system(.title, design: .serif))
                        Spacer(minLength: 6)
                        Image(systemName: metric.2).font(.title3)
                    }
                    Text(CommunityRefreshL10n.text(metric.0)).font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(index == 0 ? Color(hex: 0xFFF7E4) : EKitapligimPalette.ink)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(index == 0 ? Color(hex: 0x1C5653) : Color(hex: 0xFFFDF8), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(EKitapligimPalette.border))
            }
        }
    }

    private var requestSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(1...3, id: \.self) { number in
                HStack(alignment: .top, spacing: 14) {
                    Text(String(format: "%02d", number)).font(.system(.title2, design: .serif))
                        .foregroundStyle(Color(hex: 0xB19B68))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(CommunityRefreshL10n.text("requests.step\(number)")).font(.subheadline.weight(.semibold))
                            .foregroundStyle(EKitapligimPalette.ink)
                        Text(CommunityRefreshL10n.text("requests.step\(number)Body")).font(.caption)
                            .foregroundStyle(EKitapligimPalette.muted)
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 13)
                if number < 3 { Divider() }
            }
        }.padding(.horizontal, 4)
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CommunityRefreshL10n.text("requests.collectionEyebrow"))
                .font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(EKitapligimPalette.teal)
            Text(CommunityRefreshL10n.text("requests.collection"))
                .font(.system(.title, design: .serif)).foregroundStyle(EKitapligimPalette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(CommunityRefreshL10n.count("requests.count", visibleItems.count))
                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
            Button(action: presentCreate) {
                Label(L10n.bookRequestsRequestAction, systemImage: "plus")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white).background(Color(hex: 0x2B7569), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).disabled(isSubmitting)
        }
    }

    private var requestFilters: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField(CommunityRefreshL10n.text("requests.search"), text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                    }.accessibilityLabel(L10n.commonClose)
                }
            }
            .foregroundStyle(EKitapligimPalette.ink).padding(.horizontal, 14).frame(minHeight: 52)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(EKitapligimPalette.border))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    EKChip(title: L10n.commonAll, isSelected: selectedStatus.isEmpty) { selectedStatus = "" }
                    ForEach(["PENDING", "ACQUIRED", "REJECTED"], id: \.self) { status in
                        EKChip(title: CommunityRefreshL10n.text(status == "PENDING" ? "requests.pending" : status == "ACQUIRED" ? "requests.acquired" : "requests.rejected"), isSelected: selectedStatus == status) { selectedStatus = status }
                    }
                }
            }
        }
    }

    private func presentCreate() {
        guard container.isSignedIn else {
            showLoginAlert = true
            return
        }
        draftTitle = ""
        draftAuthor = ""
        draftISBN = ""
        showCreateSheet = true
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await container.bookRequests.requests().items
        } catch {
            errorMessage = L10n.bookRequestsLoadFailed
        }
    }

    private func submitRequest() async {
        let title = draftTitle.trimmed
        let author = draftAuthor.trimmed
        guard !title.isEmpty, !author.trimmed.isEmpty else { return }
        guard container.isSignedIn else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await container.bookRequests.create(title: title, author: author, isbn: draftISBN.trimmed)
            showCreateSheet = false
            statusMessage = L10n.bookRequestsCreated
            await load()
        } catch {
            operationError = L10n.bookRequestsCreateFailed
        }
    }

    private func vote(on item: BookRequestDTO) async {
        guard item.allowsVote else { return }
        guard container.isSignedIn else {
            showLoginAlert = true
            return
        }
        votingID = item.id
        defer { votingID = nil }
        do {
            _ = try await container.bookRequests.toggleVote(id: item.id)
            statusMessage = L10n.bookRequestsVoteSaved
            await load()
        } catch {
            operationError = L10n.bookRequestsVoteFailed
        }
    }
}

private struct BookRequestRow: View {
    let item: BookRequestDTO
    var isVoting: Bool = false
    let onVote: () -> Void
    var onBlocked: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            bookContent
            Divider()
            HStack(spacing: 12) {
                voteColumn
                Spacer(minLength: 0)
                if let contentID = Int(item.id) {
                    UGCSafetyMenu(type: .bookRequest, contentID: contentID, userID: item.userId, onBlocked: onBlocked)
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0xFFFDF8), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xD8E3DE)))
    }

    @ViewBuilder
    private var bookContent: some View {
        if let bookID = item.fulfilledBookID {
            NavigationLink { BookDetailDestination(bookIDString: bookID) } label: {
                bookInfo
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.agendaOpenBook)
        } else {
            bookInfo
        }
    }

    private var bookInfo: some View {
        HStack(alignment: .top, spacing: 14) {
            EKBookRequestCover(title: item.title, author: item.author, seed: item.id + item.title)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.bookRequestsAuthorLine(item.author))
                    .font(.body)
                    .foregroundStyle(Color(hex: 0x697386))
                    .lineLimit(1)
                if !item.requestedBy.isEmpty {
                    MemberProfileLink(memberID: item.userId) {
                        Text(L10n.bookRequestsRequestedBy(item.requestedBy))
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0x697386))
                            .lineLimit(1)
                    }
                }
                EKBookRequestStatusPill(status: item.status, showsBookHint: item.fulfilledBookID != nil)
            }
        }
    }

    private var voteColumn: some View {
        HStack(spacing: 10) {
            Button(action: onVote) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2B7569).opacity(item.allowsVote && !isVoting ? 1 : 0.35))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: 0xEDF4EA))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(Color(hex: 0xD8E3DE), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!item.allowsVote || isVoting)
            .accessibilityLabel(L10n.bookRequestsVoteAccessibility)
            Text(L10n.bookRequestsVoteCount(item.voteCount))
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(hex: 0x697386))
                .lineLimit(1)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
