import SwiftUI
import EkitapligimCore

@MainActor
struct BookRequestsView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var items: [BookRequestDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var operationError: String?
    @State private var statusMessage: String?
    @State private var showCreateSheet = false
    @State private var showLoginAlert = false
    @State private var isSubmitting = false
    @State private var votingID: String?
    @State private var draftTitle = ""
    @State private var draftAuthor = ""
    @State private var draftISBN = ""

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
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .profile }
        } message: {
            Text(L10n.bookRequestsLoginRequiredMessage)
        }
                .sheet(isPresented: $showCreateSheet) {
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
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }

    private var requestList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard

                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x1B56E8), Color(hex: 0x63A5FF)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 5, height: 28)
                    Text(L10n.bookRequestsListSection)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(hex: 0x07152E))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button(action: presentCreate) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                            Text(L10n.bookRequestsRequestAction)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: isSubmitting
                                    ? [Color(hex: 0xE0B16D), Color(hex: 0xD59A54)]
                                    : [Color(hex: 0xFFA122), Color(hex: 0xE07700)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }

                if items.isEmpty {
                    Text(L10n.bookRequestsEmptyTitle)
                        .font(.body)
                        .foregroundStyle(Color(hex: 0x697386))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(28)
                        .ekitapligimCard()
                } else {
                    ForEach(items) { item in
                        BookRequestRow(item: item, isVoting: votingID == item.id) {
                            Task { await vote(on: item) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: 0xF7FAFC), Color.white, Color(hex: 0xF8FBFC)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.bookRequestsHeroTitle)
                    .font(.system(.largeTitle, design: .serif).weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(L10n.bookRequestsHeroSubtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.92))
            }
            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 58, weight: .semibold))
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 78, weight: .semibold))
            }
            .foregroundStyle(Color(hex: 0xF7E9D0))
        }
        .padding(.leading, 34)
        .padding(.trailing, 32)
        .frame(maxWidth: .infinity, minHeight: 178, maxHeight: 178, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0x111169),
                        Color(hex: 0x073580),
                        Color(hex: 0x0086A9),
                        Color(hex: 0x17D0C4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Canvas { context, size in
                    let glow = Color(hex: 0xFFD98B).opacity(0.40)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: size.width * 0.52,
                            y: -size.height * 0.33,
                            width: size.width * 0.90,
                            height: size.height * 0.90
                        )),
                        with: .color(.white.opacity(0.07))
                    )
                    var spline = Path()
                    spline.move(to: CGPoint(x: size.width * 0.64, y: size.height * 0.72))
                    spline.addLine(to: CGPoint(x: size.width * 0.98, y: size.height * 0.52))
                    context.stroke(spline, with: .color(.white.opacity(0.42)), lineWidth: 2)
                    var gold = Path()
                    gold.move(to: CGPoint(x: size.width * 0.68, y: size.height * 0.84))
                    gold.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
                    context.stroke(gold, with: .color(Color(hex: 0xFFE2A7).opacity(0.75)), lineWidth: 1.2)
                    var teal = Path()
                    teal.move(to: CGPoint(x: size.width * 0.56, y: size.height * 0.92))
                    teal.addLine(to: CGPoint(x: size.width, y: size.height * 0.74))
                    context.stroke(teal, with: .color(Color(hex: 0x3AF0E2).opacity(0.46)), lineWidth: 1.1)
                    for (index, point) in [
                        CGPoint(x: size.width * 0.64, y: size.height * 0.34),
                        CGPoint(x: size.width * 0.72, y: size.height * 0.24),
                        CGPoint(x: size.width * 0.88, y: size.height * 0.21),
                        CGPoint(x: size.width * 0.96, y: size.height * 0.18)
                    ].enumerated() {
                        let radius: CGFloat = index.isMultiple(of: 2) ? 2 : 3
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                            with: .color(glow)
                        )
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func presentCreate() {
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

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            BookRequestCover(title: item.title, author: item.author, seed: item.id + item.title)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color(hex: 0x07152E))
                    .lineLimit(2)
                Text(L10n.bookRequestsAuthorLine(item.author))
                    .font(.body)
                    .foregroundStyle(Color(hex: 0x697386))
                    .lineLimit(1)
                if !item.requestedBy.isEmpty {
                    Text(L10n.bookRequestsRequestedBy(item.requestedBy))
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x697386))
                        .lineLimit(1)
                }
                BookRequestStatusPill(status: item.status)
            }
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                Button(action: onVote) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1954C8).opacity(item.allowsVote && !isVoting ? 1 : 0.35))
                        .frame(width: 62, height: 62)
                        .background(Color(hex: 0xF1F5FF))
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(Color(hex: 0xE4EAF8), lineWidth: 1)
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
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .ekitapligimCard()
    }
}

private struct BookRequestStatusPill: View {
    let status: String

    private var tone: Color {
        switch status.uppercased() {
        case "ACQUIRED": Color(hex: 0x07968E)
        case "REJECTED": Color(hex: 0xD34B4B)
        default: Color(hex: 0x3C73E8)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
            Text(L10n.bookRequestsStatus(status))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(tone)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tone.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var iconName: String {
        switch status.uppercased() {
        case "ACQUIRED": "checkmark.circle.fill"
        case "REJECTED": "xmark.circle.fill"
        default: "circle.fill"
        }
    }
}

private struct BookRequestCover: View {
    let title: String
    let author: String
    let seed: String

    private static let palettes: [(Color, Color)] = [
        (Color(hex: 0xE9D2A0), Color(hex: 0x9D7444)),
        (Color(hex: 0x7A1E1E), Color(hex: 0x2B1012)),
        (Color(hex: 0x8FB2BE), Color(hex: 0x183140)),
        (Color(hex: 0x102D5A), Color(hex: 0x051326)),
        (Color(hex: 0xE5ECE9), Color(hex: 0x8A948D))
    ]

    var body: some View {
        let palette = Self.palettes[abs(seed.hashValue) % Self.palettes.count]
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [palette.0, palette.1], startPoint: .top, endPoint: .bottom))
            Canvas { context, size in
                let glowRect = CGRect(
                    x: size.width * 0.28,
                    y: -size.height * 0.32,
                    width: size.width,
                    height: size.width
                )
                context.fill(Path(ellipseIn: glowRect), with: .color(.white.opacity(0.13)))
                var highlight = Path()
                highlight.move(to: CGPoint(x: 0, y: size.height * 0.72))
                highlight.addLine(to: CGPoint(x: size.width, y: size.height * 0.52))
                context.stroke(highlight, with: .color(.white.opacity(0.18)), lineWidth: 1)
            }
            .allowsHitTesting(false)
            VStack(spacing: 8) {
                Text(String(title.uppercased().prefix(38)))
                    .font(.system(.subheadline, design: .serif).weight(.heavy))
                    .foregroundStyle(.white.opacity(0.94))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                Spacer(minLength: 0)
                Text(String(author.uppercased().prefix(20)))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: 82, height: 116)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
