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
    @State private var createError: String?
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            // Keep creation separate from the menu's native trailing toolbar item.
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    presentCreate()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.bookRequestsCreate)
                .accessibilityIdentifier("requests.create.open")
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
            BookRequestCreateSheet(
                title: $draftTitle,
                author: $draftAuthor,
                isbn: $draftISBN,
                isSignedIn: container.isSignedIn,
                isSubmitting: isSubmitting,
                errorMessage: createError,
                onCancel: { showCreateSheet = false },
                onSubmit: { Task { await submitRequest() } }
            )
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
            .accessibilityIdentifier("requests.scroll")
        }
    }

    private var requestStats: some View {
        let metrics: [(String, Int, String)] = [
            ("requests.pending", items.filter { $0.allowsVote }.count, "hourglass"),
            ("requests.acquired", items.filter { $0.isAcquired }.count, "checkmark"),
            ("requests.rejected", items.filter { $0.status.uppercased() == "REJECTED" }.count, "shield"),
            ("requests.support", items.reduce(0) { $0 + $1.voteCount }, "heart")
        ]
        return LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
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
        createError = nil
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
        createError = nil
        defer { isSubmitting = false }
        do {
            _ = try await container.bookRequests.create(title: title, author: author, isbn: draftISBN.trimmed)
            showCreateSheet = false
            statusMessage = L10n.bookRequestsCreated
            await load()
        } catch {
            createError = L10n.bookRequestsCreateFailed
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

@MainActor
private struct BookRequestCreateSheet: View {
    @Binding var title: String
    @Binding var author: String
    @Binding var isbn: String
    let isSignedIn: Bool
    let isSubmitting: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, author, isbn }

    private var page: Color { Color(hex: colorScheme == .dark ? 0x102329 : 0xFAF8F2) }
    private var surface: Color { Color(hex: colorScheme == .dark ? 0x193239 : 0xFFFFFF) }
    private var ink: Color { Color(hex: colorScheme == .dark ? 0xF2F4EC : 0x183F45) }
    private var muted: Color { Color(hex: colorScheme == .dark ? 0xACC1C3 : 0x647B7D) }
    private var accent: Color { Color(hex: colorScheme == .dark ? 0x9DDCCF : 0x246D69) }
    private var border: Color { Color(hex: colorScheme == .dark ? 0x355157 : 0xDCE5DE) }
    private var canSubmit: Bool {
        isSignedIn && !isSubmitting && !title.trimmed.isEmpty && !author.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    VStack(alignment: .leading, spacing: 18) {
                        inputField(L10n.bookRequestsBookTitle, placeholderKey: "requests.form.titlePlaceholder",
                                   symbol: "book.closed", text: $title, field: .title)
                        inputField(L10n.bookRequestsAuthor, placeholderKey: "requests.form.authorPlaceholder",
                                   symbol: "person", text: $author, field: .author)
                        inputField(CommunityRefreshL10n.text("requests.form.isbn"), placeholderKey: "requests.form.isbnPlaceholder",
                                   symbol: "barcode", text: $isbn, field: .isbn)
                    }
                    .disabled(isSubmitting)

                    if !isSignedIn {
                        formMessage(L10n.bookRequestsGuestCreateHint, isError: true)
                    }
                    if let errorMessage {
                        formMessage(errorMessage, isError: true)
                            .accessibilityIdentifier("requests.create.error")
                    } else {
                        formMessage(CommunityRefreshL10n.text("requests.form.required"), isError: false)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("requests.create.scroll")
            .safeAreaInset(edge: .bottom, spacing: 0) { submitBar }
            .background(page.ignoresSafeArea(.container))
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.commonClose) { focusedField = nil }
                        .tint(accent)
                }
            }
        }
        .tint(accent)
        .presentationBackground(page)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(650), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled(isSubmitting)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "book.closed.fill")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color(hex: 0xE9CD8B))
                    .frame(width: 52, height: 56)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: 0x2E716D), Color(hex: 0x173F45)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(hex: 0xE9CD8B).opacity(0.24))
                    }
                    .accessibilityHidden(true)
                Spacer(minLength: 12)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(muted)
                        .frame(width: 44, height: 44)
                        .background(surface, in: Circle())
                        .overlay { Circle().strokeBorder(border) }
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel(L10n.commonCancel)
                .accessibilityIdentifier("requests.create.cancel")
            }
            Text(L10n.bookRequestsCreate)
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
            Text(CommunityRefreshL10n.text("requests.form.title"))
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(CommunityRefreshL10n.text("requests.form.subtitle"))
                .font(.subheadline)
                .foregroundStyle(muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
    }

    private func inputField(_ label: String, placeholderKey: String, symbol: String,
                            text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(focusedField == field ? accent : muted)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                TextField(label, text: text,
                          prompt: Text(CommunityRefreshL10n.text(placeholderKey)).foregroundColor(muted.opacity(0.8)),
                          axis: .vertical)
                    .font(.body)
                    .foregroundStyle(ink)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(field == .isbn ? .characters : .words)
                    .autocorrectionDisabled()
                    .keyboardType(field == .isbn ? .asciiCapable : .default)
                    .submitLabel(field == .isbn ? .done : .next)
                    .focused($focusedField, equals: field)
                    .onSubmit {
                        switch field {
                        case .title: focusedField = .author
                        case .author: focusedField = .isbn
                        case .isbn: focusedField = nil
                        }
                    }
                    .accessibilityIdentifier("requests.create.\(field)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(minHeight: 54)
            .background(surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(focusedField == field ? accent : border,
                                  lineWidth: focusedField == field ? 1.5 : 1)
            }
        }
    }

    private func formMessage(_ message: String, isError: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle" : "info.circle")
                .accessibilityHidden(true)
            Text(message).fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(isError ? Color.red : muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var submitBar: some View {
        Button {
            guard canSubmit else { return }
            focusedField = nil
            onSubmit()
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill").accessibilityHidden(true)
                }
                Text(isSubmitting ? L10n.bookRequestsSubmitting : CommunityRefreshL10n.text("requests.form.submit"))
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x2C7C70), Color(hex: 0x205A60)],
                                         startPoint: .leading, endPoint: .trailing))
            }
            .opacity(canSubmit || isSubmitting ? 1 : 0.55)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityIdentifier("requests.create.submit")
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background {
            page
                .overlay(alignment: .top) { border.frame(height: 1) }
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

private struct BookRequestRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))) {
            EKBookRequestCover(title: item.title, author: item.author, seed: item.id + item.title)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.bookRequestsAuthorLine(item.author))
                    .font(.body)
                    .foregroundStyle(Color(hex: 0x697386))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if !item.requestedBy.isEmpty {
                    MemberProfileLink(memberID: item.userId) {
                        Text(L10n.bookRequestsRequestedBy(item.requestedBy))
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0x697386))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
