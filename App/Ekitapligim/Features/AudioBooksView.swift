import SwiftUI
import EkitapligimCore

@MainActor
struct AudioBooksView: View {
    @StateObject private var model: AudioCatalogModel
    @ObservedObject var controller: AudioPlaybackController
    let account: String?
    var onBook: (Int) -> Void
    var onLibrary: () -> Void
    var onLogin: () -> Void
    var onPremium: () -> Void
    @State private var filtersExpanded = false
    @State private var query = ""
    init(repository: AudioRepository, controller: AudioPlaybackController, account: String?, initialFilters: AudioFilters = .init(), onBook: @escaping (Int) -> Void,
         onLibrary: @escaping () -> Void, onLogin: @escaping () -> Void, onPremium: @escaping () -> Void) {
        _model = StateObject(wrappedValue: AudioCatalogModel(repository: repository, filters: initialFilters)); _query = State(initialValue: initialFilters.query)
        self.controller = controller; self.account = account
        self.onBook = onBook; self.onLibrary = onLibrary; self.onLogin = onLogin; self.onPremium = onPremium
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                hero
                filters
                if let categories = model.catalog?.categories, !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip(AudioL10n.text("allCategories"), selected: model.filters.category == 0) { Task { await model.apply { $0.category = 0 } } }
                            ForEach(categories) { category in chip(category.title, selected: model.filters.category == category.id) { Task { await model.apply { $0.category = category.id } } } }
                        }
                    }
                }
                if let error = model.error { AudioErrorView(message: error) { Task { await model.retry() } } }
                if model.loading && model.books.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(25) }
                if !model.filters.active, let sections = model.catalog?.sections {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        if !section.books.isEmpty { AudioShelfView(title: section.title, hint: section.hint, books: section.books, onBook: onBook) }
                    }
                }
                Text(AudioL10n.text("results")).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink)
                if !model.loading && model.books.isEmpty && model.error == nil { AudioEmptyView() }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 14) {
                    ForEach(model.books) { book in AudioCardView(book: book) { onBook(book.id) } }
                }
                if model.filters.page < (model.catalog?.pagination.pages ?? 1) {
                    AudioActionButton(title: AudioL10n.text("loadMore"), icon: "arrow.down") { Task { await model.more() } }.disabled(model.loading)
                }
            }.padding(16).padding(.bottom, 24).frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
        }.background(AudioStyle.paper).navigationTitle(AudioL10n.text("title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: onLibrary) { Image(systemName: "books.vertical") }.accessibilityLabel(AudioL10n.text("library")) } }
            .task(id: account) { await model.load() }
            .refreshable { await model.load() }
            .accessibilityIdentifier("audio.catalog")
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AudioL10n.text("heroEyebrow")).font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(AudioStyle.teal)
            Text(AudioL10n.text("heroTitle")).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink).fixedSize(horizontal: false, vertical: true)
            Text(AudioL10n.text("heroMessage")).font(.subheadline).foregroundStyle(AudioStyle.muted).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack { heroListen; Button(AudioL10n.text("library"), action: onLibrary).frame(minHeight: 44) }
                VStack { heroListen; Button(AudioL10n.text("library"), action: onLibrary).frame(minHeight: 44) }
            }.tint(AudioStyle.ink)
            if let book = model.catalog?.hero {
                AudioCoverView(book: book, width: 120).frame(maxWidth: .infinity).padding(.vertical, 6)
                Button { onBook(book.id) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "headphones").font(.title2).foregroundStyle(AudioStyle.teal)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(AudioL10n.text("weeklyPick")).font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(AudioStyle.teal)
                            Text(book.title).font(.system(.title3, design: .serif, weight: .bold))
                            Text(book.author).font(.caption).foregroundStyle(AudioStyle.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "play.circle.fill").font(.title)
                    }.padding(16).background(.white.opacity(0.93)).clipShape(RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).foregroundStyle(AudioStyle.ink)
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geometry in
                    AudioArtwork(name: "audio_story_landscape").frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    LinearGradient(colors: [AudioStyle.cream.opacity(0.99), AudioStyle.paper.opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 25))
    }
    private var heroListen: some View {
        AudioActionButton(title: AudioL10n.text("startListening"), icon: "headphones", prominent: true) {
            if let id = model.catalog?.hero?.id { onBook(id) }
        }.disabled(model.catalog?.hero == nil)
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { filtersExpanded.toggle() } } label: {
                HStack(spacing: 13) {
                    Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(AudioStyle.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AudioL10n.text("findStory")).font(.headline)
                        Text(AudioL10n.text("filterHint")).font(.caption).foregroundStyle(AudioStyle.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: filtersExpanded ? "chevron.up" : "chevron.down")
                }.frame(minHeight: 48).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(AudioL10n.text(filtersExpanded ? "filtersOpen" : "filtersClosed")).accessibilityIdentifier("audio.filter.toggle")
            if filtersExpanded {
                TextField(AudioL10n.text("searchPlaceholder"), text: $query).textFieldStyle(.roundedBorder).foregroundStyle(AudioStyle.ink)
                    .submitLabel(.search).onSubmit { search() }.accessibilityIdentifier("audio.filter.query")
                chipRow([("new", "sortNew"), ("popular", "sortPopular"), ("title", "sortTitle")], selected: model.filters.sort) { value in Task { await model.apply { $0.sort = value } } }
                chipRow([("0", "allDurations"), ("1800", "under30"), ("3600", "under60"), ("10800", "under180")], selected: String(model.filters.maxDuration)) { value in Task { await model.apply { $0.maxDuration = Int(value) ?? 0 } } }
                chipRow([("", "allLanguages"), ("Türkçe", "turkish")], selected: model.filters.language) { value in Task { await model.apply { $0.language = value } } }
                ViewThatFits(in: .horizontal) {
                    HStack { clearButton; Spacer(); searchButton }
                    VStack { searchButton; clearButton }
                }
            }
        }.padding(18).foregroundStyle(AudioStyle.ink).background(.white).clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AudioStyle.line, lineWidth: 1))
    }
    private var clearButton: some View { Button(AudioL10n.text("clearFilters")) { query = ""; Task { await model.apply { $0 = AudioFilters() } } }.font(.caption).frame(minHeight: 44) }
    private var searchButton: some View { Button(action: search) { Label(AudioL10n.text("search"), systemImage: "magnifyingglass").padding(.horizontal, 20).frame(minHeight: 44) }.buttonStyle(.borderedProminent).tint(AudioStyle.teal) }
    private func search() { Task { await model.apply { $0.query = query.trimmingCharacters(in: .whitespacesAndNewlines) } } }
    private func chipRow(_ values: [(String, String)], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ForEach(values, id: \.0) { value, key in chip(AudioL10n.text(key), selected: selected == value) { onSelect(value) } } } }
    }
    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.caption.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(selected ? Color.white : AudioStyle.ink).background(selected ? AudioStyle.teal : .white)
                .clipShape(Capsule()).overlay(Capsule().stroke(AudioStyle.line, lineWidth: selected ? 0 : 1)) }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
