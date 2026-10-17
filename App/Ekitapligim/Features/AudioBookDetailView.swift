import SwiftUI
import EkitapligimCore

@MainActor
struct AudioBookDetailView: View {
    @StateObject private var model: AudioDetailModel
    @ObservedObject var controller: AudioPlaybackController
    let account: String?
    var onBook: (Int) -> Void
    var onLogin: () -> Void
    var onPremium: () -> Void
    var onPlayer: () -> Void
    var onFilterCatalog: ((String, String) -> Void)?
    @State private var premiumPresented = false
    @State private var metadataOpen = false
    @State private var descriptionOpen = false
    @State private var selectedAnchor = 0
    init(bookID: Int, repository: AudioRepository, controller: AudioPlaybackController, account: String?,
         onBook: @escaping (Int) -> Void, onLogin: @escaping () -> Void, onPremium: @escaping () -> Void, onPlayer: @escaping () -> Void,
         onFilterCatalog: ((String, String) -> Void)? = nil) {
        _model = StateObject(wrappedValue: AudioDetailModel(bookID: bookID, repository: repository)); self.controller = controller; self.account = account
        self.onBook = onBook; self.onLogin = onLogin; self.onPremium = onPremium; self.onPlayer = onPlayer; self.onFilterCatalog = onFilterCatalog
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                    if let detail = model.detail {
                        hero(detail.book, proxy: proxy)
                        if let error = model.error { AudioErrorView(message: error) { Task { await model.load() } } }
                        Section {
                            chapters(detail.book).id("audioChapters")
                                .onAppear { traceDetail("chapters.appear") }
                            if !detail.book.description.isEmpty { about(detail.book).id("audioAbout") }
                            if !detail.related.isEmpty { AudioShelfView(title: AudioL10n.text("similar"), books: detail.related, artwork: "audio_shelf_recommended", onBook: onBook).id("audioRelated") }
                            if !detail.sameAuthor.isEmpty { AudioShelfView(title: AudioL10n.text("sameAuthor"), books: detail.sameAuthor, artwork: "audio_shelf_editor", onBook: onBook,
                                onBrowse: onFilterCatalog.map { callback in { callback("author", detail.book.author) } }) }
                        } header: { anchors(proxy: proxy) }
                    } else if model.loading { ProgressView().frame(maxWidth: .infinity).padding(50) }
                    else if let error = model.error { AudioErrorView(message: error) { Task { await model.load() } } }
                }.padding(14).padding(.bottom, 28).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }.background(AudioStyle.paper).accessibilityIdentifier("audio.detail.scroll")
        }.navigationTitle(AudioL10n.text("detailTitle")).navigationBarTitleDisplayMode(.inline)
            .task(id: account) {
                traceDetail("task.enter")
                model.activate(account: account); await model.load()
                traceDetail("task.load-complete")
            }.refreshable { await model.load() }
            .onChange(of: controller.revision) { _, _ in Task { await model.load() } }
            .sheet(isPresented: $premiumPresented) { AudioPremiumAccessView(onPremium: onPremium, onLogin: account == nil ? onLogin : nil) }
            .accessibilityIdentifier("audio.detail")
    }
    private func anchors(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(sectionAnchors.enumerated()), id: \.offset) { index, item in
                    Button { selectedAnchor = index; withAnimation { proxy.scrollTo(item.1, anchor: .top) } } label: {
                        Label(AudioL10n.text(item.0), systemImage: item.2).font(.caption.weight(.semibold)).padding(.horizontal, 13).frame(minHeight: 46)
                            .foregroundStyle(selectedAnchor == index ? Color.white : AudioStyle.ink)
                            .background(selectedAnchor == index ? AudioStyle.teal : Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityAddTraits(selectedAnchor == index ? .isSelected : [])
                }
            }.padding(6)
        }.background(.white).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AudioStyle.line, lineWidth: 1))
            .padding(.vertical, 4).background(AudioStyle.paper).accessibilityIdentifier("audio.detail.anchors")
            .onAppear { traceDetail("anchors.appear") }
            .onDisappear { traceDetail("anchors.disappear") }
    }
    /// Explicit offline diagnostics only: no titles, identifiers, account information or URLs.
    private func traceDetail(_ phase: StaticString) {
        #if DEBUG
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("-modern-parity-ui-fixture"),
              process.environment["MODERN_PARITY_DETAIL_TRACE"] == "1" else { return }
        NSLog("MODERN_DETAIL_PHASE %@ loaded=%d playerVisible=%d playerPlaying=%d playerLoading=%d",
              String(describing: phase), model.detail != nil ? 1 : 0,
              controller.visible ? 1 : 0, controller.playing ? 1 : 0, controller.loading ? 1 : 0)
        #endif
    }
    private var sectionAnchors: [(String, String, String)] {
        var anchors = [("chapters", "audioChapters", "headphones")]
        if model.detail?.book.description.isEmpty == false { anchors.append(("about", "audioAbout", "doc.text")) }
        if model.detail?.related.isEmpty == false { anchors.append(("similar", "audioRelated", "square.grid.2x2")) }
        return anchors
    }
    private func hero(_ book: AudioBookDTO, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                AudioArtwork(name: book.title.localizedCaseInsensitiveContains("Küçük Prens") ? "audio_detail_prince_landscape" : "audio_story_landscape")
                    .frame(height: 315).clipped()
                LinearGradient(colors: [AudioStyle.ink.opacity(0.05), AudioStyle.ink], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 20) {
                    Label(AudioL10n.text(book.isDemo ? "demo" : "storyVoice"), systemImage: "headphones")
                        .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(AudioStyle.cream).padding(.horizontal, 14).padding(.vertical, 9)
                        .background(AudioStyle.ink.opacity(0.8)).clipShape(Capsule())
                    AudioCoverView(book: book, width: 154).rotationEffect(.degrees(-3)).rotation3DEffect(.degrees(-5), axis: (x: 0, y: 1, z: 0))
                }.padding(.bottom, 22).padding(.top, 18)
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(book.title).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                if let onFilterCatalog, !book.author.isEmpty {
                    Button { onFilterCatalog("author", book.author) } label: { Label(book.author, systemImage: "pencil").font(.subheadline).frame(minHeight: 44) }.buttonStyle(.plain).foregroundStyle(AudioStyle.cream.opacity(0.9))
                } else { Text(book.author).font(.subheadline).foregroundStyle(AudioStyle.cream.opacity(0.9)) }
                if let url = URL(string: book.url), url.scheme == "https", url.user == nil, url.password == nil {
                    ShareLink(item: url) { Label(AudioL10n.text("share"), systemImage: "square.and.arrow.up").font(.caption.weight(.semibold)).frame(minHeight: 44) }.foregroundStyle(AudioStyle.cream)
                }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                    Label(book.durationLabel.isEmpty ? AudioL10n.duration(book.duration) : book.durationLabel, systemImage: "headphones")
                    Text("·"); Text(AudioL10n.format("chapterCount", book.chapterCount))
                } }.font(.caption).foregroundStyle(AudioStyle.cream.opacity(0.85))
                Button { play(book) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "play.fill").font(.title3).foregroundStyle(.white).frame(width: 40, height: 40).background(AudioStyle.ink).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(AudioL10n.text("listen")).font(.headline)
                            Text(AudioL10n.text(account != nil && book.canListen && book.state.progress > 0 ? "resumeListeningHint" : "listenHint")).font(.caption)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                    }.padding(15).frame(minHeight: 64).foregroundStyle(AudioStyle.ink)
                        .background(LinearGradient(colors: [Color(red: 1, green: 0.91, blue: 0.71), Color(red: 0.95, green: 0.82, blue: 0.6)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 19))
                }.buttonStyle(.plain).accessibilityIdentifier("audio.detail.listen")
                if account == nil || !book.canListen { Label(AudioL10n.text("premiumHint"), systemImage: "crown.fill").font(.caption).foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.6)) }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(AudioStyle.ink)
            }.clipShape(RoundedRectangle(cornerRadius: 25))
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack { chaptersAction(book, proxy: proxy); saveAction }
                    VStack { chaptersAction(book, proxy: proxy); saveAction }
                }
                ViewThatFits(in: .horizontal) { HStack { favoriteAction; noteAction(book) }; VStack { favoriteAction; noteAction(book) } }
                if !book.categories.isEmpty {
                    Divider()
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                        ForEach(book.categories) { category in
                            if let onFilterCatalog { Button { onFilterCatalog("category", String(category.id)) } label: { categoryLabel(category) }.buttonStyle(.plain) }
                            else { categoryLabel(category) }
                        }
                    } }
                }
                if !book.description.isEmpty {
                    Button { withAnimation { proxy.scrollTo("audioAbout", anchor: .top) } } label: { HStack { Text(AudioL10n.text("discoverBookWorld")); Spacer(); Image(systemName: "arrow.right") }.font(.subheadline.weight(.semibold)).frame(minHeight: 44) }.buttonStyle(.plain).foregroundStyle(AudioStyle.ink)
                }
            }.padding(15).background(.white).clipShape(RoundedRectangle(cornerRadius: 23)).overlay(RoundedRectangle(cornerRadius: 23).stroke(AudioStyle.line, lineWidth: 1))
            DisclosureGroup(isExpanded: $metadataOpen) {
                VStack(alignment: .leading, spacing: 14) {
                    metadataRow("narrator", value: book.narrator, icon: "mic")
                    metadataRow("publisher", value: book.publisher, icon: "building.columns")
                    metadataRow("language", value: book.language, icon: "globe")
                    metadataRow("published", value: book.publicationDate, icon: "calendar")
                }.padding(.vertical, 12)
            } label: { Label(AudioL10n.text("metadata"), systemImage: "info.circle").font(.subheadline.weight(.semibold)) }
                .tint(AudioStyle.ink).padding(20).background(AudioStyle.teal.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(AudioStyle.line, lineWidth: 1))
        }
    }
    private func categoryLabel(_ category: AudioCategoryDTO) -> some View { Text(category.title).font(.caption.weight(.semibold)).foregroundStyle(AudioStyle.ink).padding(.horizontal, 12).frame(minHeight: 44).background(AudioStyle.teal.opacity(0.08)).clipShape(Capsule()) }
    private var saveAction: some View { AudioActionButton(title: AudioL10n.text(model.saved ? "saved" : "save"), icon: model.saved ? "checkmark.circle.fill" : "books.vertical") { shelf(.saved) }.disabled(model.shelfBusy) }
    private func chaptersAction(_ book: AudioBookDTO, proxy: ScrollViewProxy) -> some View { AudioActionButton(title: AudioL10n.text("showChapters"), icon: "list.bullet") { if book.isDemo, let first = book.chapters.first { play(book, chapterID: first.id) } else { withAnimation { proxy.scrollTo("audioChapters", anchor: .top) } } } }
    private func noteAction(_ book: AudioBookDTO) -> some View { AudioActionButton(title: AudioL10n.text("note"), icon: "square.and.pencil") { play(book); if book.canListen, account != nil { controller.noteRequested = true } } }
    private var favoriteAction: some View { AudioActionButton(title: AudioL10n.text(model.favorite ? "favorited" : "favorite"), icon: model.favorite ? "heart.fill" : "heart") { shelf(.favorite) }.disabled(model.shelfBusy) }
    private var laterAction: some View { AudioActionButton(title: AudioL10n.text(model.later ? "laterAdded" : "later"), icon: "bookmark") { shelf(.later) }.disabled(model.shelfBusy) }
    private func metadataRow(_ key: String, value: String, icon: String) -> some View {
        Group { if !value.isEmpty { Label { VStack(alignment: .leading, spacing: 4) { Text(AudioL10n.text(key)).font(.caption).foregroundStyle(AudioStyle.muted); Text(value).font(.subheadline) } } icon: { Image(systemName: icon).foregroundStyle(AudioStyle.teal) } } }
    }
    private func chapters(_ book: AudioBookDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(AudioL10n.text("chapters"), systemImage: "headphones").font(.system(.title2, design: .serif, weight: .bold))
            ForEach(book.chapters) { chapter in
                Button { play(book, chapterID: chapter.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: book.canListen ? "play.circle.fill" : "lock.fill").font(.title2).foregroundStyle(AudioStyle.teal)
                        Text(chapter.title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(AudioPolicy.time(chapter.duration)).font(.caption).foregroundStyle(AudioStyle.muted)
                    }.padding(16).frame(minHeight: 54).background(AudioStyle.paper).clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityIdentifier("audio.detail.chapter.\(chapter.id)")
            }
        }.padding(20).foregroundStyle(AudioStyle.ink).frame(maxWidth: .infinity, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 22))
    }
    private func about(_ book: AudioBookDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(AudioL10n.text("about"), systemImage: "doc.text").font(.system(.title2, design: .serif, weight: .bold))
            Text(book.description).font(.body).foregroundStyle(AudioStyle.muted).lineSpacing(5).lineLimit(descriptionOpen ? nil : 6).textSelection(.enabled)
            Button(AudioL10n.text(descriptionOpen ? "readLess" : "readMore")) { withAnimation { descriptionOpen.toggle() } }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            laterAction
        }.padding(20).foregroundStyle(AudioStyle.ink).frame(maxWidth: .infinity, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 22))
    }
    private func play(_ book: AudioBookDTO, chapterID: Int? = nil) {
        guard account != nil, book.canListen else { premiumPresented = true; return }
        controller.start(bookID: book.id, chapterID: chapterID); onPlayer()
    }
    private func shelf(_ field: AudioShelfField) {
        guard let owner = account else { onLogin(); return }
        let bookID = model.bookID
        Task {
            guard await model.toggle(field, account: owner) else { return }
            let acknowledged: Bool
            switch field { case .saved: acknowledged = model.saved; case .favorite: acknowledged = model.favorite; case .later: acknowledged = model.later }
            await controller.acknowledgeShelfChange(bookID: bookID, field: field, value: acknowledged, account: owner)
        }
    }
}
