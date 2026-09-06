import SwiftUI
import EkitapligimCore

enum AIStyle {
    static let navy = Color(hex: 0x103848)
    static let teal = Color(hex: 0x087F86)
    static let muted = Color(hex: 0x536B75)
    static let background = Color(hex: 0xF4F9F9)
    static let border = Color(hex: 0xDCE9EB)
    static let gradient = LinearGradient(colors: [navy, teal], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct AIEmblem: View {
    var size: CGFloat = 48
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32).fill(AIStyle.gradient)
            Image(systemName: "book.closed.fill").font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white)
            Image(systemName: "sparkle").font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(Color(hex: 0xBCECE7)).offset(x: size * 0.23, y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
struct AIAssistantDestination: View {
    @EnvironmentObject private var container: AppContainer
    var bookID: Int?
    var body: some View {
        AIAssistantView(model: container.assistantModel, initialBookID: bookID)
    }
}

@MainActor
struct AIAssistantView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: AIAssistantModel
    var initialBook: BookDTO?
    var initialBookID: Int?
    @State private var panel: AIPanel?
    @State private var pendingAction: AIPendingActionDTO?
    @State private var atBottom = true
    @State private var didOpen = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    quota
                    if model.contextBookID != nil { contextCard }
                    if model.messages.isEmpty { welcome }
                    ForEach(model.messages) { message in
                        AIMessageView(message: message, features: model.bootstrap?.features ?? AIFeaturesDTO(),
                            canSend: model.canSend, confirmed: model.confirmedActions,
                            onPrompt: { model.send($0) }, onAction: { pendingAction = $0 })
                    }
                    if model.sending {
                        HStack(spacing: 10) { ProgressView(); Text(AIL10n.text("thinking")).font(.subheadline) }
                            .foregroundStyle(AIStyle.teal).accessibilityIdentifier("ai-thinking")
                    }
                    feedback
                    Color.clear.frame(height: 1).id("ai-bottom")
                        .onAppear { atBottom = true }.onDisappear { atBottom = false }
                }
                .frame(maxWidth: 760)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) { _, _ in
                guard atBottom else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("ai-bottom", anchor: .bottom) }
            }
            .overlay(alignment: .bottomTrailing) {
                if !atBottom && !model.messages.isEmpty {
                    Button { proxy.scrollTo("ai-bottom", anchor: .bottom) } label: {
                        Label(AIL10n.text("jumpLatest"), systemImage: "arrow.down")
                            .font(.caption.weight(.semibold)).padding(12).background(.regularMaterial, in: Capsule())
                    }.padding(16)
                }
            }
        }
        .background(AIStyle.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .navigationTitle(AIL10n.text("title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button(AIL10n.newConversation, systemImage: "square.and.pencil") { model.newConversation() }
                    Button(AIL10n.text("history"), systemImage: "clock.arrow.circlepath") { panel = .history }
                    Button(AIL10n.text("preferences"), systemImage: "slider.horizontal.3") {
                        if model.signedIn { model.loadPreferences(); panel = .preferences } else { panel = .login }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel(AIL10n.text("more")).disabled(model.busy)
            }
        }
        .sheet(item: $panel) { selection in
            NavigationStack {
                switch selection {
                case .history: AIHistoryView(model: model)
                case .preferences: AIPreferencesView(model: model)
                case .login: LoginView(initialMode: .login)
                }
            }.tint(AIStyle.teal)
        }
        .confirmationDialog(AIL10n.text("confirmAction"), isPresented: Binding(
            get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }
        ), titleVisibility: .visible) {
            if let action = pendingAction {
                Button(AIL10n.text(model.signedIn ? "confirm" : "login")) {
                    if model.signedIn { model.confirm(action) } else { panel = .login }
                    pendingAction = nil
                }
            }
            Button(AIL10n.text("cancel"), role: .cancel) { pendingAction = nil }
        } message: { Text(pendingAction?.preview ?? "") }
        .task {
            guard !didOpen else { return }
            didOpen = true
            model.open(book: initialBook, bookID: initialBookID)
            if initialBook == nil, let id = initialBookID {
                await model.resolveBook(id, repository: container.books)
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.refresh() } }
        .onChange(of: container.authState) { _, _ in panel = nil; pendingAction = nil }
        .tint(AIStyle.teal)
        .foregroundStyle(AIStyle.navy)
        .environment(\.colorScheme, .light)
        .accessibilityIdentifier("ai-assistant-screen")
        .preference(key: AILauncherHiddenKey.self, value: true)
    }

    private var quota: some View {
        HStack(spacing: 14) {
            AIEmblem()
            VStack(alignment: .leading, spacing: 5) {
                Text(AIL10n.text("subtitle")).font(.subheadline.weight(.semibold)).foregroundStyle(AIStyle.navy)
                if let b = model.bootstrap {
                    Text(AIL10n.quota(b.usage.remaining, b.usage.limit)).font(.caption).foregroundStyle(AIStyle.muted)
                    ProgressView(value: Double(b.usage.remaining), total: Double(max(1, b.usage.limit))).tint(AIStyle.teal)
                        .accessibilityHidden(true)
                } else if model.busy { ProgressView() }
            }
            Spacer(minLength: 0)
        }.padding(16).aiCard()
        .accessibilityElement(children: .combine).accessibilityIdentifier("ai-quota")
    }
    private var contextCard: some View {
        HStack(spacing: 12) {
            EKitapligimRemoteCover(urlString: model.book?.coverUrl ?? "")
                .frame(width: 40, height: 58).clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(AIL10n.text("bookContext")).font(.caption).foregroundStyle(AIStyle.teal)
                if let title = model.book?.title { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AIStyle.navy) }
            }
            Spacer()
        }.padding(14).aiCard()
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                AIEmblem(size: 70).shadow(color: AIStyle.teal.opacity(0.16), radius: 18, y: 8)
                Text(AIL10n.text("welcome")).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AIStyle.navy).fixedSize(horizontal: false, vertical: true)
                Text(AIL10n.text("welcomeMessage")).font(.body).foregroundStyle(AIStyle.muted)
            }.padding(.vertical, 12)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { suggestionButtons }
                VStack(alignment: .leading, spacing: 10) { suggestionButtons }
            }
            if let profile = model.bookProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AIL10n.text("bookProfile")).font(.headline)
                    Text(([profile.mood, profile.pace, profile.difficulty, profile.audience] + profile.themes + profile.contentWarnings)
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                }.padding(16).aiCard()
            }
            if let b = model.bootstrap, b.enabled {
                AIBookStrip(title: AIL10n.text("latest"), books: b.latest)
                AIBookStrip(title: AIL10n.text("popular"), books: b.popular)
                if b.features.collections {
                    NavigationLink {
                        AICollectionsView(model: model)
                    } label: {
                        Label(AIL10n.text("allCollections"), systemImage: "rectangle.stack.fill")
                            .font(.headline).padding(18).frame(maxWidth: .infinity, alignment: .leading).aiCard()
                    }
                }
            }
            Text(AIL10n.text("privacyNote")).font(.footnote).foregroundStyle(AIStyle.muted)
        }
    }
    @ViewBuilder private var suggestionButtons: some View {
        AISuggestion(title: AIL10n.text(model.contextBookID == nil ? "suggestDiscover" : "suggestBook"), icon: "sparkles") {
            model.send(AIL10n.text(model.contextBookID == nil ? "promptDiscover" : "promptBook"))
        }.disabled(!model.canSend)
        if model.bootstrap?.features.suitability == true {
            AISuggestion(title: AIL10n.text("suggestMood"), icon: "sun.max") { model.send(AIL10n.text("promptMood")) }.disabled(!model.canSend)
        }
        if model.bootstrap?.features.comparison == true {
            AISuggestion(title: AIL10n.text("suggestCompare"), icon: "books.vertical") { model.send(AIL10n.text("promptCompare")) }.disabled(!model.canSend)
        }
    }
    @ViewBuilder private var feedback: some View {
        if let b = model.bootstrap {
            if !b.enabled { Text(AIL10n.unavailable).foregroundStyle(AIStyle.muted) }
            else if b.usage.remaining == 0 { Text(AIL10n.limitReached).foregroundStyle(AIStyle.muted) }
            else if model.contextBookID != nil && !b.features.contextBook { Text(AIL10n.text("contextUnavailable")) }
        }
        if let notice = model.notice { Label(notice, systemImage: "checkmark.circle").foregroundStyle(AIStyle.teal) }
        if let error = model.error {
            VStack(alignment: .leading, spacing: 12) {
                Label(error, systemImage: "exclamationmark.circle").foregroundStyle(AIStyle.navy)
                HStack {
                    Button(AIL10n.text("refresh")) { model.refresh() }.disabled(model.busy)
                    if error == AIL10n.sessionRequired { Button(AIL10n.text("login")) { panel = .login } }
                }
            }.padding(16).aiCard().accessibilityIdentifier("ai-error")
        }
    }
    private var composer: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField(AIL10n.text("compose"), text: $model.input, axis: .vertical)
                    .lineLimit(1...5).focused($composerFocused).padding(.vertical, 12).padding(.leading, 16)
                    .accessibilityIdentifier("ai-input")
                Button { model.send(); composerFocused = false } label: {
                    Image(systemName: "arrow.up").font(.title3.weight(.bold))
                        .frame(width: 46, height: 46).foregroundStyle(.white)
                        .background(model.canSend ? AIStyle.teal : AIStyle.muted, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!model.canSend || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || model.input.unicodeScalars.count > (model.bootstrap?.constraints.maxMessageLength ?? 0))
                .accessibilityLabel(AIL10n.text("send")).accessibilityIdentifier("ai-send").padding(5)
            }.background(.white, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(AIStyle.border))
            if !model.input.isEmpty, let max = model.bootstrap?.constraints.maxMessageLength {
                Text(String(format: AIL10n.text("charactersFormat"), model.input.unicodeScalars.count, max))
                    .font(.caption2).foregroundStyle(AIStyle.muted).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }.frame(maxWidth: 760).padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity).background(.regularMaterial)
    }
}

private enum AIPanel: String, Identifiable { case history, preferences, login; var id: String { rawValue } }

struct AISuggestion: View {
    let title: String, icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.subheadline.weight(.medium)).padding(14)
                .frame(minHeight: 48, alignment: .leading).foregroundStyle(AIStyle.teal).aiCard()
        }.buttonStyle(.plain)
    }
}

struct AIBookStrip: View {
    var title: String
    let books: [AIBookCardDTO]
    var body: some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                if !title.isEmpty { Text(title).font(.title3.weight(.bold)).foregroundStyle(AIStyle.navy) }
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(books.filter { $0.threadId > 0 }) { book in
                            NavigationLink { BookDetailView(bookID: book.threadId) } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    EKitapligimRemoteCover(urlString: book.coverUrl).frame(width: 130, height: 185)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text(book.title).font(.subheadline.weight(.semibold)).foregroundStyle(AIStyle.navy)
                                    Text(book.author).font(.caption).foregroundStyle(AIStyle.muted)
                                    if !book.recommendationReason.isEmpty {
                                        Text(book.recommendationReason).font(.caption).foregroundStyle(AIStyle.teal)
                                    }
                                }.frame(width: 150, alignment: .leading).padding(12).aiCard()
                            }.buttonStyle(.plain)
                        }
                    }.padding(.bottom, 4)
                }.scrollIndicators(.hidden)
            }
        }
    }
}

struct AIMessageView: View {
    let message: AIMessageDTO, features: AIFeaturesDTO
    let canSend: Bool, confirmed: Set<Int>
    let onPrompt: (String) -> Void
    let onAction: (AIPendingActionDTO) -> Void
    private var isUser: Bool { message.role == "user" }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                if !isUser { AIEmblem(size: 28) }
                Text(AIL10n.text(isUser ? "you" : "title")).font(.caption.weight(.bold))
            }.foregroundStyle(isUser ? .white.opacity(0.8) : AIStyle.teal)
            Text(message.content).font(.body).textSelection(.enabled)
                .foregroundStyle(isUser ? .white : AIStyle.navy).fixedSize(horizontal: false, vertical: true)
            if !isUser {
                if let p = message.presentation {
                    if !p.title.isEmpty { Text(p.title).font(.headline).foregroundStyle(AIStyle.navy) }
                    if !p.summary.isEmpty && p.summary != message.content { Text(p.summary).foregroundStyle(AIStyle.muted) }
                    ForEach(Array(p.facts.enumerated()), id: \.offset) { _, fact in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AIStyle.teal)
                            Text(fact.value).font(.subheadline).foregroundStyle(AIStyle.navy)
                        }
                    }
                    if features.comparison && !p.comparison.isEmpty {
                        Text(AIL10n.text("comparison")).font(.headline)
                        ForEach(Array(p.comparison.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(row.keys.sorted(), id: \.self) { key in
                                    Text(row[key] ?? "").font(.subheadline).foregroundStyle(AIStyle.navy)
                                }
                            }.padding(12).background(AIStyle.background, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                AIBookStrip(title: "", books: message.bookCards)
                if features.evidence && !message.evidence.isEmpty {
                    Text(AIL10n.text("sources")).font(.caption.weight(.bold)).foregroundStyle(AIStyle.muted)
                    ForEach(Array(message.evidence.enumerated()), id: \.offset) { _, source in
                        if let url = AIPolicy.secureSource(source.url) {
                            Link(destination: url) {
                                Label(source.label.isEmpty ? source.source : source.label,
                                      systemImage: source.verified ? "checkmark.seal" : "link")
                                    .font(.subheadline).frame(minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                }
                if !message.scopeNotice.isEmpty { Text(message.scopeNotice).font(.footnote).foregroundStyle(AIStyle.muted) }
                if let action = message.pendingAction {
                    Text(action.preview).font(.subheadline)
                    if confirmed.contains(action.id) { Label(AIL10n.text("actionDone"), systemImage: "checkmark.circle") }
                    else {
                        Button(AIL10n.text("confirmAction")) { onAction(action) }
                            .buttonStyle(.bordered).disabled(!action.canConfirm(at: Date()))
                    }
                }
                if let p = message.presentation, !p.followUps.isEmpty {
                    ForEach(Array(p.followUps.enumerated()), id: \.offset) { _, follow in
                        Button { onPrompt(follow.prompt) } label: {
                            Label(follow.label, systemImage: "arrow.turn.down.right").font(.subheadline)
                                .frame(minHeight: 44, alignment: .leading)
                        }.disabled(!canSend)
                    }
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(isUser ? AIStyle.navy : .white, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isUser ? .clear : AIStyle.border))
        .padding(.leading, isUser ? 30 : 0).padding(.trailing, isUser ? 0 : 10)
    }
}

extension View {
    func aiCard() -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AIStyle.border))
    }
}
