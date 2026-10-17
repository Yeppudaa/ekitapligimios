import SwiftUI
import EkitapligimCore

@MainActor
struct AudioLibraryView: View {
    @StateObject private var model: AudioLibraryModel
    @ObservedObject var controller: AudioPlaybackController
    let account: String?
    var onBook: (Int) -> Void
    var onBrowse: () -> Void
    var onLogin: () -> Void
    init(repository: AudioRepository, controller: AudioPlaybackController, account: String?, initialTab: AudioLibraryTab = .saved,
         onBook: @escaping (Int) -> Void, onBrowse: @escaping () -> Void, onLogin: @escaping () -> Void) {
        _model = StateObject(wrappedValue: AudioLibraryModel(repository: repository, tab: initialTab))
        self.controller = controller; self.account = account; self.onBook = onBook; self.onBrowse = onBrowse; self.onLogin = onLogin
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                AudioLibraryHeroView()
                if account == nil {
                    AudioEmptyView(); AudioActionButton(title: AudioL10n.text("signIn"), icon: "person.crop.circle", prominent: true, action: onLogin)
                } else {
                    tabs
                    if let library = model.library, !model.loading, model.error == nil { AudioJourneyView(library: library) }
                    if (model.tab == .saved || model.tab == .listening), let book = model.library?.resumeBook { AudioResumeCard(book: book) { onBook(book.id) } }
                    if let error = model.error { AudioErrorView(message: error) { Task { await model.load(account: account) } } }
                    if model.loading { ProgressView().frame(maxWidth: .infinity).padding(20) }
                    if !model.loading, model.library?.books.isEmpty == true {
                        AudioEmptyView(); AudioActionButton(title: AudioL10n.text("profileDiscover"), icon: "headphones", prominent: true, action: onBrowse)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 14) {
                        ForEach(model.library?.books ?? []) { book in AudioCardView(book: book) { onBook(book.id) } }
                    }
                }
            }.padding(16).padding(.bottom, 28).frame(maxWidth: 1050).frame(maxWidth: .infinity)
        }.background(AudioStyle.paper).navigationTitle(AudioL10n.text("libraryTitle")).navigationBarTitleDisplayMode(.inline)
            .task(id: account) { await model.load(account: account) }.refreshable { await model.load(account: account) }
            .onChange(of: controller.revision) { _, _ in Task { await model.load(account: account) } }
            .accessibilityIdentifier("audio.library")
    }
    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AudioLibraryTab.allCases, id: \.rawValue) { tab in
                    Button { model.tab = tab; Task { await model.load(account: account) } } label: {
                        Text("\(tab.localizedTitle) (\(model.library.map { String($0.counts[tab.rawValue] ?? 0) } ?? "—"))").font(.caption.weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44).foregroundStyle(model.tab == tab ? Color.white : AudioStyle.ink)
                            .background(model.tab == tab ? AudioStyle.teal : Color.white).clipShape(Capsule())
                            .overlay(Capsule().stroke(AudioStyle.line, lineWidth: model.tab == tab ? 0 : 1))
                    }.buttonStyle(.plain).accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                }
            }
        }
    }
}

@MainActor
struct AudioLibraryHeroView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AudioL10n.text("libraryEyebrow")).font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(AudioStyle.teal)
            Text(AudioL10n.text("libraryHero")).font(.system(.largeTitle, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Text(AudioL10n.text("libraryMessage")).font(.subheadline).foregroundStyle(AudioStyle.muted).fixedSize(horizontal: false, vertical: true)
        }.padding(25).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 190)
            .background {
                GeometryReader { geometry in
                    AudioArtwork(name: "audio_moon_landscape").frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    LinearGradient(colors: [AudioStyle.cream.opacity(0.98), AudioStyle.cream.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                }
            }.foregroundStyle(AudioStyle.ink).clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
@MainActor
struct AudioJourneyView: View {
    let library: AudioLibraryDTO?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AudioL10n.text("journey")).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                stat("totalTime", value: AudioPresentationPolicy.serverDuration(library?.stats["total"]))
                stat("monthTime", value: AudioPresentationPolicy.serverDuration(library?.stats["month"]))
                stat("completed", value: String(library?.counts["completed"] ?? 0))
                stat("active", value: String(library?.counts["listening"] ?? 0))
            }
        }
    }
    private func stat(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(value).font(.title3.weight(.bold)).foregroundStyle(AudioStyle.teal); Text(AudioL10n.text(key)).font(.caption).foregroundStyle(AudioStyle.muted) }
            .padding(16).frame(maxWidth: .infinity, minHeight: 84, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AudioStyle.line, lineWidth: 1))
    }
}

@MainActor
struct AudioHomePreviewView: View {
    @StateObject private var model: AudioLibraryModel
    @ObservedObject var controller: AudioPlaybackController
    let account: String?
    var onBook: (Int) -> Void
    var onBrowse: () -> Void
    var onLibrary: () -> Void
    init(repository: AudioRepository, controller: AudioPlaybackController, account: String?, onBook: @escaping (Int) -> Void,
         onBrowse: @escaping () -> Void, onLibrary: @escaping () -> Void) {
        _model = StateObject(wrappedValue: AudioLibraryModel(repository: repository)); self.controller = controller; self.account = account
        self.onBook = onBook; self.onBrowse = onBrowse; self.onLibrary = onLibrary
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let book = model.library?.resumeBook { AudioResumeCard(book: book) { onBook(book.id) } }
            else { AudioDiscoverPreview(action: onBrowse) }
            Button(action: onLibrary) { HStack { Text(AudioL10n.text("libraryTitle")); Spacer(); Image(systemName: "arrow.right") }.font(.caption.weight(.semibold)).frame(minHeight: 44) }.foregroundStyle(AudioStyle.teal)
        }.task(id: account) { await model.load(account: account) }
            .onChange(of: controller.revision) { _, _ in Task { await model.load(account: account) } }
    }
}

@MainActor
struct AudioProfileSectionView: View {
    @StateObject private var model: AudioLibraryModel
    @ObservedObject var controller: AudioPlaybackController
    let account: String?
    var onBook: (Int) -> Void
    var onBrowse: () -> Void
    var onLibrary: () -> Void
    var onTab: (AudioLibraryTab) -> Void
    init(repository: AudioRepository, controller: AudioPlaybackController, account: String?, onBook: @escaping (Int) -> Void,
         onBrowse: @escaping () -> Void, onLibrary: @escaping () -> Void, onTab: @escaping (AudioLibraryTab) -> Void) {
        _model = StateObject(wrappedValue: AudioLibraryModel(repository: repository)); self.controller = controller; self.account = account
        self.onBook = onBook; self.onBrowse = onBrowse; self.onLibrary = onLibrary; self.onTab = onTab
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "headphones").font(.title2).foregroundStyle(AudioStyle.teal).padding(13).background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(AudioL10n.text("profileEyebrow")).font(.caption2).tracking(0.8).foregroundStyle(AudioStyle.muted)
                    Text(AudioL10n.text("profileTitle")).font(.headline)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onLibrary) { Image(systemName: "arrow.up.right").frame(width: 44, height: 44).background(.white).clipShape(Circle()) }
                    .accessibilityLabel(AudioL10n.text("libraryTitle"))
            }
            if let error = model.error { AudioErrorView(message: error) { Task { await model.load(account: account) } } }
            if let book = model.library?.resumeBook { AudioResumeCard(book: book) { onBook(book.id) } }
            else { AudioDiscoverPreview(action: onBrowse) }
            Text(AudioL10n.text("profileLibrary")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                shelf(.favorite, icon: "heart", key: "favoriteTab")
                shelf(.later, icon: "bookmark", key: "later")
                shelf(.listening, icon: "headphones", key: "active")
                shelf(.completed, icon: "checkmark.circle", key: "completedTab")
                shelf(.history, icon: "clock.arrow.circlepath", key: "historyTab")
                shelf(.saved, icon: "books.vertical", key: "savedTab")
            }
            Button(action: onLibrary) { HStack { Text(AudioL10n.text("journey")); Spacer(); Image(systemName: "arrow.right") }.font(.caption.weight(.semibold)).frame(minHeight: 44) }
        }.padding(18).foregroundStyle(AudioStyle.ink)
            .background(LinearGradient(colors: [Color(red: 0.95, green: 0.98, blue: 1), Color(red: 0.88, green: 0.94, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(AudioStyle.line, lineWidth: 1))
            .task(id: account) { await model.load(account: account) }
            .onChange(of: controller.revision) { _, _ in Task { await model.load(account: account) } }
    }
    private func shelf(_ tab: AudioLibraryTab, icon: String, key: String) -> some View {
        Button { onTab(tab) } label: {
            VStack(alignment: .leading, spacing: 15) {
                Label(AudioL10n.text(key), systemImage: icon).font(.caption).fixedSize(horizontal: false, vertical: true)
                Text(model.library.map { String($0.counts[tab.rawValue] ?? 0) } ?? "—").font(.title3.weight(.semibold)).foregroundStyle(AudioStyle.teal)
            }.frame(maxWidth: .infinity, minHeight: 66, alignment: .leading).padding(15).background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AudioStyle.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
@MainActor
private struct AudioDiscoverPreview: View {
    var action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(AudioL10n.text("storyVoice"), systemImage: "headphones").font(.caption2.weight(.bold)).tracking(0.7)
            Text(AudioL10n.text("profileEmptyTitle")).font(.system(.title2, design: .serif, weight: .bold))
            Text(AudioL10n.text("profileEmptyHint")).font(.subheadline).foregroundStyle(AudioStyle.muted)
            AudioActionButton(title: AudioL10n.text("profileDiscover"), icon: "play.fill", prominent: true, action: action)
        }.padding(20).foregroundStyle(AudioStyle.ink).background {
            GeometryReader { geometry in
                AudioArtwork(name: "audio_story_landscape").frame(width: geometry.size.width, height: geometry.size.height).clipped()
                LinearGradient(colors: [AudioStyle.cream.opacity(0.99), AudioStyle.paper.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 21))
    }
}
