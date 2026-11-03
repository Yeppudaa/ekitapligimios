import SwiftUI
import EkitapligimCore

@MainActor
struct AudioBooksView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: AudioCatalogModel
    @ObservedObject var controller: AudioPlaybackController
    let account: String?
    var onBook: (Int) -> Void
    var onLibrary: () -> Void
    var onLogin: () -> Void
    var onPremium: () -> Void
    @State private var filtersExpanded = false
    @State private var query = ""
    @ScaledMetric(relativeTo: .body) private var categoryCardWidth: CGFloat = 210
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
                features
                if !model.categories.isEmpty {
                    categorySection(model.categories)
                }
                filters
                if let personFilter = activePersonFilter { personFilterChip(personFilter) }
                if let error = model.error { AudioErrorView(message: error) { Task { await model.retry() } } }
                if model.loading && model.books.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(25) }
                if !model.filters.active, let sections = model.catalog?.sections {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        if !section.books.isEmpty { AudioShelfView(title: section.title, hint: section.hint, books: section.books, onBook: onBook) }
                    }
                }
                Text(AudioL10n.text("results")).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink)
                if !model.loading && model.books.isEmpty && model.error == nil { AudioEmptyView() }
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 14) {
                    ForEach(model.books) { book in AudioCardView(book: book) { onBook(book.id) } }
                }
                if model.hasMore {
                    AudioActionButton(title: AudioL10n.text("loadMore"), icon: "arrow.down") { Task { await model.more() } }.disabled(model.loading)
                }
            }.padding(16).padding(.bottom, 24).frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
        }.background(AudioStyle.paper).navigationTitle(AudioL10n.text("title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: onLibrary) { Image(systemName: "books.vertical") }.accessibilityLabel(AudioL10n.text("library")).accessibilityIdentifier("audio.catalog.library") } }
            .task(id: account) { await model.load() }
            .refreshable { await model.load() }
            .accessibilityIdentifier("audio.catalog")
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AudioL10n.text("heroEyebrow")).font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(AudioStyle.teal)
            Text(AudioL10n.text("heroTitle")).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink).fixedSize(horizontal: false, vertical: true)
            Text(AudioL10n.text("heroMessage")).font(.subheadline).foregroundStyle(AudioStyle.muted).fixedSize(horizontal: false, vertical: true)
            heroListen
                .frame(maxWidth: .infinity, alignment: .center)
            if let book = model.hero {
                AudioCoverView(book: book, width: 120).frame(maxWidth: .infinity).padding(.vertical, 6)
                Button { onBook(book.id) } label: {
                    HStack(spacing: 14) {
                        if !dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: "headphones").font(.title2).foregroundStyle(AudioStyle.teal).accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(AudioL10n.text("weeklyPick")).font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(AudioStyle.teal)
                            Text(book.title).font(.system(.title3, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                            Text(book.author).font(.caption).foregroundStyle(AudioStyle.muted).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "play.circle.fill").font(.system(size: 28)).accessibilityHidden(true)
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
            if let id = model.hero?.id { onBook(id) }
        }.disabled(model.hero == nil).accessibilityIdentifier("audio.catalog.start")
    }
    private var features: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        return layout {
            feature("featureAnywhere", icon: "headphones")
            feature("featureWorlds", icon: "book.pages")
            feature("featurePremium", icon: "rosette")
        }.frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .combine)
    }
    private func feature(_ key: String, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.body).foregroundStyle(AudioStyle.teal).accessibilityHidden(true)
            Text(AudioL10n.text(key)).font(.caption2).foregroundStyle(AudioStyle.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    private func categorySection(_ categories: [AudioCategoryDTO]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 5) {
                Text(AudioL10n.text("categoryHeading")).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink)
                Text(AudioL10n.text("categoryHint")).font(.subheadline).foregroundStyle(AudioStyle.muted)
            }.fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(categories) { category in
                        categoryCard(category)
                            .containerRelativeFrame(.horizontal) { length, _ in min(categoryCardWidth, max(1, length - 16)) }
                    }
                }.padding(.vertical, 1)
            }
        }.accessibilityIdentifier("audio.catalog.categories")
    }
    private func categoryCard(_ category: AudioCategoryDTO) -> some View {
        let selected = model.filters.category == category.id
        return Button {
            Task { await model.apply { $0.category = selected ? 0 : category.id } }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.pages").font(.title3).foregroundStyle(AudioStyle.teal).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(category.title).font(.subheadline.weight(.semibold)).foregroundStyle(AudioStyle.ink)
                    Text(AudioL10n.format("categoryBookCount", category.count)).font(.caption).foregroundStyle(AudioStyle.muted)
                }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(selected ? AudioStyle.teal.opacity(0.13) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AudioStyle.line, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("audio.category.\(category.id)")
    }
    private var activePersonFilter: String? {
        let author = model.filters.author.trimmingCharacters(in: .whitespacesAndNewlines)
        let narrator = model.filters.narrator.trimmingCharacters(in: .whitespacesAndNewlines)
        return !author.isEmpty ? author : (!narrator.isEmpty ? narrator : nil)
    }
    private func personFilterChip(_ name: String) -> some View {
        Button {
            Task { await model.apply { $0.author = ""; $0.narrator = "" } }
        } label: {
            HStack(spacing: 12) {
                Text(name).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "xmark.circle.fill").font(.body).accessibilityHidden(true)
            }.padding(.horizontal, 15).padding(.vertical, 10).frame(minHeight: 44)
                .foregroundStyle(AudioStyle.teal).background(AudioStyle.teal.opacity(0.1)).clipShape(Capsule())
        }.buttonStyle(.plain).accessibilityLabel(Text(name)).accessibilityHint(AudioL10n.text("removePersonFilter"))
            .accessibilityIdentifier("audio.filter.person.clear")
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { filtersExpanded.toggle() } } label: {
                HStack(spacing: 13) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(AudioStyle.teal).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AudioL10n.text("findStory")).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text(AudioL10n.text("filterHint")).font(.caption).foregroundStyle(AudioStyle.muted).fixedSize(horizontal: false, vertical: true)
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
                    HStack { clearButton; Spacer(); searchButton }.fixedSize(horizontal: true, vertical: false)
                    VStack { searchButton; clearButton }
                }
            }
        }.padding(18).foregroundStyle(AudioStyle.ink).background(.white).clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AudioStyle.line, lineWidth: 1))
    }
    private var clearButton: some View { Button(AudioL10n.text("clearFilters")) { query = ""; Task { await model.apply { $0 = AudioFilters() } } }.font(.caption).frame(minHeight: 44) }
    private var searchButton: some View { Button(action: search) { Label(AudioL10n.text("search"), systemImage: "magnifyingglass").foregroundStyle(.white).padding(.horizontal, 20).frame(minHeight: 44) }.buttonStyle(.borderedProminent).tint(AudioStyle.teal) }
    private func search() { Task { await model.apply { $0.query = query.trimmingCharacters(in: .whitespacesAndNewlines) } } }
    private func chipRow(_ values: [(String, String)], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ForEach(values, id: \.0) { value, key in chip(AudioL10n.text(key), selected: selected == value) { onSelect(value) } } } }
    }
    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.caption.weight(.semibold)).fixedSize(horizontal: true, vertical: true).padding(.horizontal, 14).padding(.vertical, 6).frame(minHeight: 44)
                .foregroundStyle(selected ? Color.white : AudioStyle.ink).background(selected ? AudioStyle.teal : .white)
                .clipShape(Capsule()).overlay(Capsule().stroke(AudioStyle.line, lineWidth: selected ? 0 : 1)) }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
