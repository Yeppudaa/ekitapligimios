import SwiftUI
import EkitapligimCore

@MainActor
struct BookRequestsView: View {
    @StateObject private var model = BookRequestsModel()
    @State private var pendingAccess: BookRequestAccessPresentation?
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showCreateSheet = false
    @State private var showLoginAlert = false
    @State private var showingLogin = false
    @State private var query = ""
    @State private var selectedStatus = ""
    @State private var accessPresentation: BookRequestAccessPresentation?
    @State private var routeAfterAccess: AppRoute?

    private var visibleItems: [BookRequestDTO] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.items.filter { item in
            (item.userId.map { !container.blockedUserIDs.contains($0) } ?? true)
            && (selectedStatus.isEmpty || item.status.uppercased() == selectedStatus)
            && (search.isEmpty || item.title.localizedStandardContains(search) || item.author.localizedStandardContains(search))
        }
    }

    private var featuredRequest: BookRequestDTO? {
        model.items.filter { item in
            item.allowsVote && (item.userId.map { !container.blockedUserIDs.contains($0) } ?? true)
        }.max { $0.voteCount < $1.voteCount }
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if model.isLoading && model.items.isEmpty {
                    EKLoadingState(message: L10n.bookRequestsLoading)
                } else if let errorMessage = model.errorMessage, model.items.isEmpty {
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
        .task(id: container.sessionRevision) {
            configureModel()
            await load()
        }
        .onChange(of: container.sessionRevision) { _, _ in
            configureModel()
            accessPresentation = nil; pendingAccess = nil; routeAfterAccess = nil; showCreateSheet = false
        }
        .refreshable { await load() }
        .alert(L10n.commonSuccess, isPresented: Binding(
            get: { model.statusMessage != nil && !showCreateSheet },
            set: { if !$0 { model.statusMessage = nil } }
        )) {
            Button(L10n.commonClose) { model.statusMessage = nil }
        } message: {
            Text(model.statusMessage ?? "")
        }
        .alert(L10n.bookRequestsActionFailedTitle, isPresented: Binding(
            get: { model.operationError != nil },
            set: { if !$0 { model.operationError = nil } }
        )) {
            Button(L10n.commonClose) { model.operationError = nil }
        } message: {
            Text(model.operationError ?? L10n.bookRequestsActionFailedMessage)
        }
        .alert(L10n.bookRequestsLoginRequiredTitle, isPresented: $showLoginAlert) {
            Button(L10n.commonCancel, role: .cancel) {}
            Button(L10n.bookRequestsGoToLogin) { showingLogin = true }
        } message: {
            Text(L10n.bookRequestsLoginRequiredMessage)
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .sheet(item: $accessPresentation, onDismiss: {
            if let route = routeAfterAccess {
                routeAfterAccess = nil
                container.open(route: route)
            }
        }) { presentation in
            BookRequestAccessView(presentation: presentation,
                onClose: { accessPresentation = nil },
                onPremium: { closeAccess(opening: .premium) },
                onCatalog: { closeAccess(opening: .catalog) },
                onAudio: { closeAccess(opening: .audiobooks) })
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: {
            if let pendingAccess { accessPresentation = pendingAccess; self.pendingAccess = nil }
        }) {
            BookRequestCreateSheet(
                title: $model.draftTitle,
                author: $model.draftAuthor,
                isbn: $model.draftISBN,
                isSignedIn: container.isSignedIn,
                isSubmitting: model.isSubmitting,
                errorMessage: model.createError,
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
                            BookRequestRow(item: featuredRequest, isVoting: model.votingID != nil) {
                                Task { await vote(on: featuredRequest) }
                            } onBlocked: {
                                if let userID = featuredRequest.userId { model.removeUser(userID) }
                            }
                        }
                        .padding(14).background(Color(hex: 0xF4F3E3), in: RoundedRectangle(cornerRadius: 20))
                    }
                    collectionHeader.id("request-collection")
                    requestFilters
                    if let errorMessage = model.errorMessage { EKInlineError(message: errorMessage) }
                    if visibleItems.isEmpty {
                        EKStateCard(title: L10n.bookRequestsEmptyTitle, message: CommunityRefreshL10n.count("requests.count", 0))
                    } else {
                        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                        ForEach(visibleItems) { item in
                            BookRequestRow(item: item, isVoting: model.votingID != nil) {
                                Task { await vote(on: item) }
                            } onBlocked: {
                                if let userID = item.userId { model.removeUser(userID) }
                            }
                        }
                        }
                    }
                    if model.hasMore {
                        EKLoadMoreButton(isLoading: model.isLoadingMore) { Task { await model.loadMore() } }
                            .accessibilityIdentifier("requests.loadMore")
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
                .floatingLauncherClearance()
            }
            .accessibilityIdentifier("requests.scroll")
        }
    }

    private var requestStats: some View {
        // Site-wide totals from the server; the loaded page is only a fallback for older servers.
        let metrics: [(String, Int, String)] = model.stats.map { stats in [
            ("requests.pending", stats.pending, "hourglass"),
            ("requests.acquired", stats.acquired, "checkmark"),
            ("requests.rejected", stats.rejected, "shield"),
            ("requests.support", stats.support, "heart")
        ] } ?? [
            ("requests.pending", model.items.filter { $0.allowsVote }.count, "hourglass"),
            ("requests.acquired", model.items.filter { $0.isAcquired }.count, "checkmark"),
            ("requests.rejected", model.items.filter { $0.status.uppercased() == "REJECTED" }.count, "shield"),
            ("requests.support", model.items.reduce(0) { $0 + $1.voteCount }, "heart")
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
            }.buttonStyle(.plain).disabled(model.isSubmitting)
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
        configureModel()
        if let explanation = model.prepareCreation() {
            accessPresentation = explanation
            return
        }
        showCreateSheet = true
    }

    private func closeAccess(opening route: AppRoute) {
        routeAfterAccess = route
        accessPresentation = nil
    }

    private func configureModel() {
        model.configure(BookRequestsDependencies(repository: container.bookRequests),
                        session: container.sessionRevision, signedIn: container.isSignedIn)
    }

    private func load() async { configureModel(); await model.load() }

    private func submitRequest() async {
        configureModel()
        if await model.submit() {
            showCreateSheet = false
        } else if let explanation = model.accessExplanation {
            pendingAccess = explanation
            showCreateSheet = false
        }
    }

    private func vote(on item: BookRequestDTO) async {
        guard container.isSignedIn else { showLoginAlert = true; return }
        configureModel()
        await model.vote(item)
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
            cover
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

    /// Shelved requests show the real catalog cover; open requests keep the generated jacket.
    @ViewBuilder
    private var cover: some View {
        if let coverURL = item.fulfilledCoverURL {
            EKitapligimRemoteCover(urlString: coverURL, title: item.title, author: item.author)
                .frame(width: 82, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                .accessibilityHidden(true)
        } else {
            EKBookRequestCover(title: item.title, author: item.author, seed: item.id + item.title)
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
