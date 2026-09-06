import SwiftUI
import EkitapligimCore

enum AIStyle {
    // The assistant uses the same visual language as the Android client.
    static let navy = Color(hex: 0x0F3D64)
    static let blue = Color(hex: 0x126DA6)
    static let cyan = Color(hex: 0x16A7D8)
    static let muted = Color(hex: 0x687784)
    static let background = Color.white
    static let surface = Color(hex: 0xF5FAFD)
    static let border = Color(hex: 0x526B78)
    static let success = Color(hex: 0x117A56)
    static let gradient = LinearGradient(colors: [navy, blue, cyan], startPoint: .leading, endPoint: .trailing)
}

struct AIEmblem: View {
    var size: CGFloat = 48
    var body: some View {
        Image("AIAssistantAvatar")
            .resizable()
            .scaledToFit()
            .background(Color.white, in: Circle())
            .clipShape(Circle())
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
                LazyVStack(alignment: .leading, spacing: 16) {
                    quota
                    if model.contextBookID != nil { contextCard }
                    if model.messages.isEmpty { welcome }
                    ForEach(model.messages) { message in
                        AIMessageView(message: message, features: model.bootstrap?.features ?? AIFeaturesDTO(),
                            canSend: model.canSend, confirmed: model.confirmedActions,
                            onPrompt: { send($0) }, onAction: { pendingAction = $0 })
                    }
                    if model.sending {
                        HStack(spacing: 10) {
                            ProgressView().tint(AIStyle.cyan)
                            Text(AIL10n.text("thinking")).font(.subheadline)
                        }
                        .foregroundStyle(AIStyle.muted)
                        .padding(.horizontal, 18)
                        .accessibilityIdentifier("ai-thinking")
                    }
                    feedback
                    Color.clear.frame(height: 1).id("ai-bottom")
                        .onAppear { atBottom = true }.onDisappear { atBottom = false }
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) { _, _ in
                guard atBottom else { return }
                // Long, dynamically laid-out answers can continuously retarget an animated
                // ScrollViewReader transition. An immediate move keeps the composer visible
                // and avoids trapping accessibility/UI automation in a non-idle animation.
                proxy.scrollTo("ai-bottom", anchor: .bottom)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 9) {
                    AIEmblem(size: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(AIL10n.text("title")).font(.subheadline.bold()).foregroundStyle(AIStyle.navy)
                        Text(AIL10n.text("online")).font(.caption2.weight(.medium)).foregroundStyle(AIStyle.success)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.newConversation() } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel(AIL10n.newConversation)
                Button { panel = .history } label: { Image(systemName: "clock.arrow.circlepath") }
                    .accessibilityLabel(AIL10n.text("history"))
                Button {
                    if model.signedIn { model.loadPreferences(); panel = .preferences } else { panel = .login }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel(AIL10n.text("preferences"))
            }
        }
        .sheet(item: $panel) { selection in
            NavigationStack {
                switch selection {
                case .history: AIHistoryView(model: model)
                case .preferences: AIPreferencesView(model: model)
                case .login: LoginView(initialMode: .login)
                }
            }.tint(AIStyle.blue)
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
        .onChange(of: model.confirmedActions) { old, new in
            if new.count > old.count { Task { await container.refreshSessionData() } }
        }
        .tint(AIStyle.blue)
        .foregroundStyle(AIStyle.navy)
        .environment(\.colorScheme, .light)
        .preference(key: AILauncherHiddenKey.self, value: true)
    }

    private var quota: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.bootstrap == nil ? AIL10n.text("quotaLoading") : AIL10n.text("dailyUsage"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let b = model.bootstrap {
                    Text(AIL10n.remaining(b.usage.remaining, b.usage.limit)).font(.subheadline)
                } else if model.busy { ProgressView() }
            }
            if let b = model.bootstrap {
                ProgressView(value: Double(b.usage.used), total: Double(max(1, b.usage.limit)))
                    .tint(.white)
                    .background(.white.opacity(0.28), in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(AIStyle.gradient)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ai-quota")
    }
    private var contextCard: some View {
        HStack(spacing: 12) {
            EKitapligimRemoteCover(urlString: model.book?.coverUrl ?? "")
                .frame(width: 40, height: 58).clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(AIL10n.text("bookContext")).font(.caption.weight(.semibold)).foregroundStyle(AIStyle.blue)
                if let title = model.book?.title { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AIStyle.navy) }
            }
            Spacer()
        }
        .padding(14)
        .background(AIStyle.surface, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 12) {
                AIEmblem(size: 92)
                    .shadow(color: AIStyle.blue.opacity(0.14), radius: 18, y: 8)
                Text(AIL10n.text("welcome"))
                    .font(.title2.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AIStyle.navy)
                Text(AIL10n.text("welcomeMessage"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AIStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            ScrollView(.horizontal) {
                HStack(spacing: 9) { suggestionButtons }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollIndicators(.hidden)
            if let profile = model.bookProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AIL10n.text("bookProfile")).font(.headline)
                    Text(([profile.mood, profile.pace, profile.difficulty, profile.audience] + profile.themes + profile.contentWarnings)
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                }.padding(16).background(AIStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
            }
            if let b = model.bootstrap, b.enabled {
                AIBookStrip(title: AIL10n.text("latest"), books: b.latest)
                AIBookStrip(title: AIL10n.text("popular"), books: b.popular)
                if b.features.collections {
                    NavigationLink {
                        AICollectionsView(model: model)
                    } label: {
                        Label(AIL10n.text("allCollections"), systemImage: "rectangle.stack.fill")
                            .font(.headline).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(AIStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                }
            }
            Text(AIL10n.text("privacyNote")).font(.footnote).foregroundStyle(AIStyle.muted)
                .padding(.horizontal, 16).padding(.bottom, 8)
        }
    }
    @ViewBuilder private var suggestionButtons: some View {
        AISuggestion(title: AIL10n.text(model.contextBookID == nil ? "suggestDiscover" : "suggestBook"), icon: "sparkles") {
            send(AIL10n.text(model.contextBookID == nil ? "promptDiscover" : "promptBook"))
        }.disabled(!model.canSend)
        if model.bootstrap?.features.suitability == true {
            AISuggestion(title: AIL10n.text("suggestMood"), icon: "sun.max") { send(AIL10n.text("promptMood")) }.disabled(!model.canSend)
        }
        if model.bootstrap?.features.comparison == true {
            AISuggestion(title: AIL10n.text("suggestCompare"), icon: "books.vertical") { send(AIL10n.text("promptCompare")) }.disabled(!model.canSend)
        }
    }
    @ViewBuilder private var feedback: some View {
        if let b = model.bootstrap {
            if !b.enabled { Text(AIL10n.unavailable).foregroundStyle(AIStyle.muted) }
            else if b.usage.remaining == 0 { Text(AIL10n.limitReached).foregroundStyle(AIStyle.muted) }
            else if model.contextBookID != nil && !b.features.contextBook { Text(AIL10n.text("contextUnavailable")) }
        }
        if let notice = model.notice { Label(notice, systemImage: "checkmark.circle").foregroundStyle(AIStyle.success).padding(.horizontal, 16) }
        if let error = model.error {
            VStack(alignment: .leading, spacing: 12) {
                Label(error, systemImage: "exclamationmark.circle").foregroundStyle(AIStyle.navy)
                HStack {
                    Button(AIL10n.text("refresh")) { model.refresh() }.disabled(model.busy)
                    if error == AIL10n.sessionRequired { Button(AIL10n.text("login")) { panel = .login } }
                }
            }.padding(16).background(AIStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16).accessibilityIdentifier("ai-error")
        }
    }
    private var composer: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("", text: $model.input,
                    prompt: Text(AIL10n.text("compose")).foregroundStyle(AIStyle.muted), axis: .vertical)
                    .lineLimit(1...5).focused($composerFocused).padding(.horizontal, 16).padding(.vertical, 13)
                    .foregroundStyle(AIStyle.navy)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(AIStyle.border, lineWidth: 1))
                    .accessibilityIdentifier("ai-input")
                Button { send(); composerFocused = false } label: {
                    Image(systemName: "arrow.up").font(.title3.weight(.bold))
                        .frame(width: 52, height: 52).foregroundStyle(.white)
                        .background(model.canSend ? AIStyle.blue : AIStyle.muted, in: Circle())
                        .accessibilityLabel(AIL10n.text("send"))
                        .accessibilityIdentifier("ai-send")
                }
                .disabled(!model.canSend || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || model.input.unicodeScalars.count > (model.bootstrap?.constraints.maxMessageLength ?? 0))
            }
            if !model.input.isEmpty, let max = model.bootstrap?.constraints.maxMessageLength {
                Text(String(format: AIL10n.text("charactersFormat"), model.input.unicodeScalars.count, max))
                    .font(.caption2).foregroundStyle(AIStyle.muted).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }.frame(maxWidth: 760).padding(.horizontal, 10).padding(.vertical, 10)
            .frame(maxWidth: .infinity).background(.white.shadow(.drop(color: .black.opacity(0.07), radius: 10, y: -2)))
    }

    private func send(_ prompt: String? = nil) {
        // A deliberate send follows the newly appended exchange. Passive incoming
        // changes still respect `atBottom`, so reading older messages is undisturbed.
        atBottom = true
        model.send(prompt)
    }
}

private enum AIPanel: String, Identifiable { case history, preferences, login; var id: String { rawValue } }

struct AISuggestion: View {
    let title: String, icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AIStyle.blue)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(AIStyle.surface, in: Capsule())
                .overlay(Capsule().stroke(AIStyle.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AIBookStrip: View {
    var title: String
    let books: [AIBookCardDTO]
    var body: some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !title.isEmpty {
                    Text(title).font(.headline.weight(.bold)).foregroundStyle(AIStyle.navy)
                        .padding(.horizontal, 16)
                }
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        ForEach(books.filter { $0.threadId > 0 }) { book in
                            NavigationLink { BookDetailView(bookID: book.threadId) } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    EKitapligimRemoteCover(urlString: book.coverUrl).frame(width: 154, height: 154)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(book.title).font(.subheadline.weight(.semibold)).foregroundStyle(AIStyle.navy)
                                        .lineLimit(2)
                                    Text(book.author).font(.caption).foregroundStyle(AIStyle.muted)
                                        .lineLimit(1)
                                    if !book.recommendationReason.isEmpty {
                                        Text(book.recommendationReason).font(.caption).foregroundStyle(AIStyle.blue)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(width: 154, alignment: .leading)
                                .padding(10)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                                .shadow(color: AIStyle.navy.opacity(0.10), radius: 8, y: 3)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 5)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)
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
    @ViewBuilder
    var body: some View {
        if isUser {
            HStack(alignment: .bottom, spacing: 7) {
                Spacer(minLength: 44)
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .background(AIStyle.blue, in: UnevenRoundedRectangle(
                        topLeadingRadius: 20, bottomLeadingRadius: 20,
                        bottomTrailingRadius: 4, topTrailingRadius: 20
                    ))
                    .accessibilityIdentifier("ai-user-message")
                Image(systemName: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AIStyle.navy, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    AIEmblem(size: 32)
                    Text(AIL10n.text("title")).font(.subheadline.weight(.bold)).foregroundStyle(AIStyle.navy)
                }
                Text(message.content).font(.body).textSelection(.enabled)
                    .foregroundStyle(AIStyle.navy).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ai-assistant-message")
                if let p = message.presentation {
                    if !p.title.isEmpty { Text(p.title).font(.headline).foregroundStyle(AIStyle.navy) }
                    if !p.summary.isEmpty && p.summary != message.content { Text(p.summary).foregroundStyle(AIStyle.muted) }
                    ForEach(Array(p.facts.enumerated()), id: \.offset) { _, fact in
                        HStack(alignment: .top, spacing: 10) {
                            Text(fact.label).font(.subheadline.weight(.bold)).foregroundStyle(AIStyle.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(fact.value).font(.subheadline).foregroundStyle(AIStyle.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(11)
                        .background(AIStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if features.comparison && !p.comparison.isEmpty {
                        Text(AIL10n.text("comparison")).font(.headline)
                        ForEach(Array(p.comparison.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(row.keys.sorted(), id: \.self) { key in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(key).font(.caption.weight(.semibold)).foregroundStyle(AIStyle.navy)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(row[key] ?? "").font(.subheadline).foregroundStyle(AIStyle.navy)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }.padding(12).background(AIStyle.surface, in: RoundedRectangle(cornerRadius: 14))
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
                    if confirmed.contains(action.id) {
                        Label(AIL10n.text("actionDone"), systemImage: "checkmark.circle").foregroundStyle(AIStyle.success)
                    }
                    else {
                        Button(AIL10n.text("confirmAction")) { onAction(action) }
                            .buttonStyle(.borderedProminent).tint(AIStyle.navy)
                            .disabled(!action.canConfirm(at: Date()))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

extension View {
    func aiCard() -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: AIStyle.navy.opacity(0.10), radius: 9, y: 3)
    }
}
