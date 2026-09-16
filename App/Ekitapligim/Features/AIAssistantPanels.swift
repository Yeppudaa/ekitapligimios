import SwiftUI
import EkitapligimCore

@MainActor
struct AIHistoryView: View {
    @ObservedObject var model: AIAssistantModel
    @Environment(\.dismiss) private var dismiss
    @State private var deleting: AIConversationSummaryDTO?
    @State private var deletingAll = false
    var body: some View {
        List {
            if model.bootstrap?.conversations.isEmpty != false {
                ContentUnavailableView(AIL10n.text("emptyHistory"), systemImage: "bubble.left.and.bubble.right")
            }
            ForEach(model.bootstrap?.conversations ?? []) { conversation in
                Button {
                    model.loadConversation(conversation.id); dismiss()
                } label: {
                    Label(conversation.title, systemImage: "bubble.left").foregroundStyle(AIStyle.navy)
                        .padding(.vertical, 8)
                }.disabled(model.busy)
                .swipeActions {
                    Button(AIL10n.text("delete"), role: .destructive) { deleting = conversation }
                }
            }
            if model.bootstrap?.conversations.isEmpty == false {
                Button(AIL10n.text("deleteAll"), role: .destructive) { deletingAll = true }.disabled(model.busy)
            }
            Section { Text(AIL10n.text("retention")).font(.footnote).foregroundStyle(AIStyle.muted) }
            AIModelFeedback(model: model)
        }
        .navigationTitle(AIL10n.text("history"))
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(AIL10n.text("close")) { dismiss() } } }
        .alert(AIL10n.text("delete"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(AIL10n.text("delete"), role: .destructive) {
                if let id = deleting?.id { model.deleteConversation(id) }; deleting = nil
            }
            Button(AIL10n.text("cancel"), role: .cancel) { deleting = nil }
        } message: { Text(AIL10n.text("deleteMessage")) }
        .alert(AIL10n.text("deleteAll"), isPresented: $deletingAll) {
            Button(AIL10n.text("deleteAll"), role: .destructive) { model.deleteConversation(nil) }
            Button(AIL10n.text("cancel"), role: .cancel) {}
        } message: { Text(AIL10n.text("deleteAllMessage")) }
    }
}

@MainActor
struct AIPreferencesView: View {
    @ObservedObject var model: AIAssistantModel
    @Environment(\.dismiss) private var dismiss
    @State private var personalized = false
    @State private var digest = AIDigestPreferenceDTO()
    @State private var loaded = false
    var body: some View {
        Form {
            Section {
                Toggle(AIL10n.text("personalization"), isOn: $personalized)
            } footer: { Text(AIL10n.text("personalizationNote")) }
            if model.bootstrap?.features.weeklyDigest == true {
                Section(AIL10n.text("weeklyDigest")) {
                    Toggle(AIL10n.text("weeklyDigest"), isOn: $digest.enabled)
                    Toggle(AIL10n.text("siteAlert"), isOn: $digest.siteAlert).disabled(!digest.enabled)
                    Toggle(AIL10n.text("email"), isOn: $digest.email).disabled(!digest.enabled)
                    Toggle(AIL10n.text("push"), isOn: $digest.push).disabled(!digest.enabled)
                }
            }
            AIModelFeedback(model: model)
        }
        .disabled(model.busy)
        .navigationTitle(AIL10n.text("preferences"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(AIL10n.text("close")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(AIL10n.text("save")) {
                    model.savePreferences(personalized: personalized, digest: digest)
                }.disabled(model.busy || !loaded)
            }
        }
        .onAppear { sync() }
        .onChange(of: model.preferences) { _, _ in sync() }
    }
    private func sync() {
        guard let preference = model.preferences else { return }
        personalized = preference.personalizationEnabled
        digest = preference.digest ?? AIDigestPreferenceDTO(); loaded = true
    }
}

@MainActor
struct AICollectionsView: View {
    @ObservedObject var model: AIAssistantModel
    var slug: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.bootstrap?.enabled == true && model.bootstrap?.features.collections == true {
                    if let slug {
                        if let collection = model.selectedCollection, collection.slug == slug {
                            Text(collection.title).font(.largeTitle.bold()).foregroundStyle(AIStyle.navy)
                            Text(collection.description).foregroundStyle(AIStyle.muted)
                            AIBookStrip(title: "", books: collection.books)
                        }
                    } else {
                        if model.collections.isEmpty && !model.busy {
                            ContentUnavailableView(AIL10n.text("emptyCollections"), systemImage: "rectangle.stack")
                        }
                        ForEach(model.collections) { collection in
                            NavigationLink { AICollectionsView(model: model, slug: collection.slug) } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label(collection.title, systemImage: "books.vertical.fill").font(.title3.bold()).foregroundStyle(AIStyle.navy)
                                    Text(collection.description).font(.subheadline).foregroundStyle(AIStyle.muted)
                                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).aiCard()
                            }.buttonStyle(.plain)
                        }
                    }
                }
                AIModelFeedback(model: model)
            }.frame(maxWidth: 760).padding(20).frame(maxWidth: .infinity)
        }.background(AIStyle.background)
            .navigationTitle(AIL10n.text("collections"))
            .task(id: slug) {
                await model.waitUntilIdle()
                guard !Task.isCancelled else { return }
                model.loadCollections(slug: slug)
            }
            .environment(\.colorScheme, .light)
    }
}

@MainActor
struct AICollectionsDestination: View {
    @EnvironmentObject private var container: AppContainer
    var slug: String?
    var body: some View { AICollectionsView(model: container.assistantModel, slug: slug) }
}

@MainActor
struct AIModelFeedback: View {
    @ObservedObject var model: AIAssistantModel
    var body: some View {
        if model.busy { ProgressView().frame(maxWidth: .infinity).padding() }
        if let error = model.error { Text(error).foregroundStyle(AIStyle.navy) }
        if let notice = model.notice { Label(notice, systemImage: "checkmark.circle").foregroundStyle(AIStyle.success) }
    }
}

/// Views which cover the application (reader, login) can suppress the root launcher without changing navigation.
struct AILauncherHiddenKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

@MainActor
struct AIAssistantLauncher: View {
    @ObservedObject var model: AIAssistantModel
    @Binding var isCollapsed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void

    var body: some View {
        if model.showLauncher {
            Button {
                setCollapsed(false)
                action()
            } label: {
                HStack(spacing: 9) {
                    AIEmblem(size: 38)
                    if !isCollapsed {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(AIL10n.text("title")).font(.subheadline.weight(.bold))
                            Text(AIL10n.text("online")).font(.caption2).foregroundStyle(.white.opacity(0.9))
                        }
                        Image(systemName: "sparkles").accessibilityHidden(true)
                    }
                }
                .foregroundStyle(.white)
                .padding(7)
                .padding(.trailing, isCollapsed ? 0 : 9)
                .frame(minWidth: 52, minHeight: 52)
                .background(AIStyle.gradient, in: RoundedRectangle(cornerRadius: isCollapsed ? 26 : 22))
                .contentShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: AIStyle.navy.opacity(0.20), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ai-launcher")
            .accessibilityLabel(AIL10n.text("title"))
            .accessibilityValue(AIL10n.text(isCollapsed ? "launcherCollapsed" : "launcherExpanded"))
            .accessibilityAction(named: Text(AIL10n.text(isCollapsed ? "expandLauncher" : "collapseLauncher"))) {
                setCollapsed(!isCollapsed)
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        guard abs(horizontal) >= 40,
                              abs(horizontal) > abs(value.translation.height) else { return }
                        setCollapsed(horizontal > 0)
                    }
            )
        }
    }

    private func setCollapsed(_ collapsed: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            isCollapsed = collapsed
        }
    }
}

@MainActor
struct AIBookEntry: View {
    @ObservedObject var model: AIAssistantModel
    let book: BookDTO
    var body: some View {
        if model.bootstrap?.enabled == true && model.bootstrap?.features.contextBook == true {
            NavigationLink {
                AIAssistantView(model: model, initialBook: book)
            } label: {
                HStack(spacing: 12) {
                    AIEmblem(size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AIL10n.text("askBook")).font(.headline).foregroundStyle(AIStyle.navy)
                        Text(AIL10n.text("menuSubtitle")).font(.caption).foregroundStyle(AIStyle.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(AIStyle.blue)
                }.padding(16).aiCard()
            }.buttonStyle(.plain).accessibilityIdentifier("ai-book-entry")
        }
    }
}
