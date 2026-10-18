import SwiftUI
import EkitapligimCore

@MainActor
struct ModernHomeGenreStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var tileWidth = 148.0
    @ScaledMetric(relativeTo: .headline) private var tileHeight = 182.0
    private let genres = [
        ("6", "roman"), ("21", "fantastik"), ("13", "kisisel_gelisim"), ("7", "edebiyat"),
        ("12", "psikoloji"), ("10", "tarih"), ("9", "bilim"), ("15", "cocuk")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(genres, id: \.0) { genre in
                    NavigationLink { CatalogView(initialCategoryID: genre.0, embeddedInNavigationStack: true) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Spacer(minLength: 48)
                            genreTitle(HomeRefreshL10n.text("genre.\(genre.1)"))
                            HStack {
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(EKitapligimPalette.ink)
                                    .frame(width: 26, height: 26)
                                    .background(.white, in: Circle())
                                    .accessibilityHidden(true)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            min(tileWidth, max(1, length - 32))
                        }
                        .frame(minHeight: tileHeight, alignment: .bottomLeading)
                        .background {
                            GeometryReader { geometry in
                                Image("home_genre_\(genre.1)").resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                                    .overlay {
                                        LinearGradient(colors: [.clear, .black.opacity(0.88)],
                                                       startPoint: .top, endPoint: .bottom)
                                    }
                            }
                            .accessibilityHidden(true)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(HomeRefreshL10n.text("genre.\(genre.1)"))
                    .accessibilityIdentifier("home.genre.\(genre.0)")
                }
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.genres")
    }

    @ViewBuilder private func genreTitle(_ title: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
            } else {
                // The arrow has its own row so every title can use the full card width.
                Text(title).lineLimit(2, reservesSpace: true)
            }
        }
        .font(.system(.headline, design: .serif, weight: .bold))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModernHomeSpotlight: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var minimumCopyWidth = 180.0
    let book: BookDTO

    var body: some View {
        NavigationLink(value: book.id) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 16) { cover; copy }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            cover
                            copy.frame(minWidth: minimumCopyWidth)
                        }
                        VStack(alignment: .leading, spacing: 16) { cover; copy }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background {
                Image("home_next_scene").resizable().scaledToFill()
                    .overlay { LinearGradient(colors: [Color(hex: 0xFFFCF8), Color(hex: 0xFFFCF8).opacity(0.94), Color(hex: 0xFFFCF8).opacity(0.48)], startPoint: .leading, endPoint: .trailing) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(EKitapligimPalette.border) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.nextBook")
    }

    private var cover: some View {
        EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
            .frame(width: 84, height: 126)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title).font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(EKitapligimPalette.ink).fixedSize(horizontal: false, vertical: true)
            if !book.author.isEmpty {
                Text(book.author).font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(HomeRefreshL10n.text("next.caption"), systemImage: "book")
                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Label(HomeRefreshL10n.text("next.action"), systemImage: "arrow.right")
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(EKitapligimPalette.teal, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

struct ModernHomeReadingPanel: View {
    let item: LibraryItemDTO?
    let otherBooks: [LibraryItemDTO]
    let onRead: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(HomeRefreshL10n.text("continue.read"), systemImage: "book.pages")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(EKitapligimPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(HomeRefreshL10n.text("continue.subtitle"))
                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
            if let item {
                Button { onRead(item.bookId) } label: {
                    ModernLibraryResumeItem(item: item)
                }
                .buttonStyle(.plain)
                ProgressView(value: Double(item.displayProgressPercent), total: 100)
                    .tint(EKitapligimPalette.amber)
                    .accessibilityLabel(L10n.libraryReadingProgressLabel)
                    .accessibilityValue(L10n.commonPercent(item.displayProgressPercent))
                Button { onRead(item.bookId) } label: {
                    Label(HomeRefreshL10n.text("continue.read"), systemImage: "book.pages.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 18).padding(.vertical, 12).frame(minHeight: 48)
                        .background(EKitapligimPalette.teal, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.continueReading")
                if !otherBooks.isEmpty {
                    Divider()
                    Text(HomeRefreshL10n.text("continue.more")).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(otherBooks, id: \.bookId) { next in
                                Button { onRead(next.bookId) } label: {
                                    ModernLibraryResumeItem(item: next, compact: true)
                                        .padding(12)
                                        .containerRelativeFrame(.horizontal) { length, _ in
                                            min(244, max(1, length))
                                        }
                                        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                Text(L10n.continueReadingEmptySubtitle).font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0xFCF7EF), Color(hex: 0xFAF3E7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color(hex: 0xEDDFC9)) }
    }
}

private struct ModernLibraryResumeItem: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: LibraryItemDTO
    var compact = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout { cover; copy }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var cover: some View {
        EKitapligimRemoteCover(urlString: item.coverUrl, title: item.title, author: item.author)
            .frame(width: compact ? 38 : 74, height: compact ? 56 : 111)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 8))
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HomeRefreshL10n.page(max(1, item.lastReadPage)))
                .font(.caption.weight(.semibold)).foregroundStyle(EKitapligimPalette.amber)
            if compact {
                UniformCardText(item.title, lines: 3)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(EKitapligimPalette.ink)
                UniformCardText(item.author, lines: 1)
                    .font(.caption).foregroundStyle(EKitapligimPalette.muted)
            } else {
                Text(item.title).font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.author.isEmpty {
                    Text(item.author).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                }
            }
        }
    }
}

@MainActor
struct ModernHomePromoPair: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                promo(teal: true).frame(minWidth: 300)
                promo(teal: false).frame(minWidth: 300)
            }
            VStack(spacing: 12) { promo(teal: true); promo(teal: false) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.scenicPromos")
    }

    private func promo(teal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            UniformCardText(HomeRefreshL10n.text(teal ? "promo.reading.title" : "promo.new.title"), lines: 2)
                .font(.system(.title, design: .serif, weight: .bold))
            UniformCardText(HomeRefreshL10n.text(teal ? "promo.reading.subtitle" : "promo.new.subtitle"), lines: 2)
                .font(.subheadline)
            NavigationLink {
                CatalogView(initialOrder: "latest", embeddedInNavigationStack: true)
            } label: {
                Label {
                    UniformCardText(HomeRefreshL10n.text(teal ? "catalog.explore" : "promo.new.action"), lines: 1)
                } icon: {
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(EKitapligimPalette.ink)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .background(.white.opacity(0.96), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(teal ? "home.promo.explore" : "home.promo.newBooks")
        }
        .foregroundStyle(teal ? .white : EKitapligimPalette.ink)
        .padding(23)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .leading)
        .background {
            GeometryReader { proxy in
                if teal {
                    LinearGradient(colors: [Color(hex: 0x064A51), Color(hex: 0x51A18D)], startPoint: .leading, endPoint: .trailing)
                    Image("home_teal_books_scene").resizable().scaledToFit()
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.22), .init(color: .white, location: 1)], startPoint: .leading, endPoint: .trailing)
                        }
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.20), .init(color: .white, location: 1)], startPoint: .top, endPoint: .bottom)
                        }
                        .frame(width: proxy.size.width * 0.53, height: max(110, proxy.size.height - 105))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    Image("home_teal_leaves_scene").resizable().scaledToFit()
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.20), .init(color: .white, location: 0.80), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
                        }
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.20), .init(color: .white, location: 0.80), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                        }
                        .frame(width: 75, height: 105)
                        .padding(.trailing, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    LinearGradient(colors: [Color(hex: 0x064A51).opacity(0.9), Color(hex: 0x064A51).opacity(0.72), .clear], startPoint: .leading, endPoint: .trailing)
                } else {
                    Color(hex: 0xF0ECE2)
                    Image("home_new_promo_scene").resizable().scaledToFill()
                        .frame(width: proxy.size.width * 0.57, height: proxy.size.height)
                        .clipped()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    LinearGradient(colors: [Color(hex: 0xF0ECE2), Color(hex: 0xF0ECE2).opacity(0.94), Color(hex: 0xF0ECE2).opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                }
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

@MainActor
struct ModernHomeCategoryShowcase: View {
    let forums: [ForumDTO]
    let books: [BookDTO]
    let onExplore: () -> Void
    @ScaledMetric(relativeTo: .body) private var cardWidth = 236.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernHeroView(artwork: "home_section_genre_discovery", eyebrow: HomeRefreshL10n.text("showcase.eyebrow"),
                title: HomeRefreshL10n.text("genre.title"), subtitle: HomeRefreshL10n.text("showcase.subtitle"),
                minHeight: 200, actionTitle: HomeRefreshL10n.text("showcase.action"), action: onExplore)
            if forums.isEmpty {
                Text(HomeRefreshL10n.text("showcase.empty")).font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted).padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 11) {
                        ForEach(forums.prefix(8)) { forum in
                            NavigationLink {
                                CatalogView(initialCategoryID: forum.id, embeddedInNavigationStack: true)
                            } label: { categoryCard(forum) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.categoryShowcase.\(forum.id)")
                        }
                    }
                    .padding(1)
                }
            }
        }
        .padding(13)
        .background(EKitapligimPalette.paper, in: RoundedRectangle(cornerRadius: 23))
        .overlay { RoundedRectangle(cornerRadius: 23).stroke(EKitapligimPalette.border) }
        .accessibilityIdentifier("home.scenicCategories")
    }

    private func categoryCard(_ forum: ForumDTO) -> some View {
        let title = forum.title.replacingOccurrences(of: "📚", with: "").replacingOccurrences(of: "📖", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let book = books.first {
            let category = $0.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return !category.isEmpty && (category.localizedCaseInsensitiveContains(title) || title.localizedCaseInsensitiveContains(category))
        }
        let countLabel = forum.threadCount.flatMap { $0 > 0 ? HomeRefreshL10n.categoryBooks($0) : nil } ?? ""
        return HStack(alignment: .top, spacing: 12) {
            if let book {
                EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                    .frame(width: 55, height: 81).clipShape(RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "book.pages")
                    .font(.title2).foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 55, height: 81)
                    .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 7) {
                UniformCardText(countLabel, lines: 1)
                    .font(.caption2).foregroundStyle(EKitapligimPalette.muted)
                UniformCardText(title, lines: 2)
                    .font(.headline).foregroundStyle(EKitapligimPalette.ink)
                UniformCardText(book?.title ?? HomeRefreshL10n.text("showcase.discover"), lines: 2)
                    .font(.caption).foregroundStyle(EKitapligimPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .containerRelativeFrame(.horizontal) { length, _ in
            min(cardWidth, max(1, length - 2))
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(EKitapligimPalette.border) }
        .accessibilityElement(children: .combine)
    }
}

struct ModernHomeLibraryBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let stats: SiteStatsDTO?
    let onLibrary: () -> Void
    let onBooks: () -> Void
    let onAuthors: () -> Void
    let onCategories: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 11) {
                Text(HomeRefreshL10n.text("libraryBanner.title"))
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(HomeRefreshL10n.text("libraryBanner.subtitle"))
                    .font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onLibrary) {
                    Label(HomeRefreshL10n.text("libraryBanner.action"), systemImage: "arrow.right")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 18).padding(.vertical, 12).frame(minHeight: 48)
                        .background(EKitapligimPalette.teal, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.libraryBanner.open")
            }
            statistics
        }
        .padding(23).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color(hex: 0xF0EDE4)
                Image("home_library_scene").resizable().scaledToFill()
                    .frame(width: proxy.size.width * 0.43, height: min(proxy.size.height, 210))
                    .clipped().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                LinearGradient(colors: [Color(hex: 0xF0EDE4), Color(hex: 0xF0EDE4).opacity(0.9), Color(hex: 0xF0EDE4).opacity(0.55)], startPoint: .leading, endPoint: .trailing)
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.scenicLibrary")
    }

    @ViewBuilder private var statistics: some View {
        if dynamicTypeSize.isAccessibilitySize { verticalStatistics }
        else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    statistic(stats?.totalBooks, label: "libraryBanner.books", icon: "book.pages", action: onBooks).frame(minWidth: 90)
                    statistic(stats?.totalAuthors, label: "libraryBanner.authors", icon: "pencil", action: onAuthors).frame(minWidth: 90)
                    statistic(stats?.totalCategories, label: "libraryBanner.categories", icon: "person.2", action: onCategories).frame(minWidth: 90)
                }
                verticalStatistics
            }
        }
    }

    private var verticalStatistics: some View {
        VStack(spacing: 10) {
            statistic(stats?.totalBooks, label: "libraryBanner.books", icon: "book.pages", action: onBooks)
            statistic(stats?.totalAuthors, label: "libraryBanner.authors", icon: "pencil", action: onAuthors)
            statistic(stats?.totalCategories, label: "libraryBanner.categories", icon: "person.2", action: onCategories)
        }
    }

    private func statistic(_ value: Int?, label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 44, height: 44).background(.white.opacity(0.92), in: Circle())
                    .accessibilityHidden(true)
                UniformCardText(value.flatMap { $0 >= 0 ? EKitapligimFormat.count($0) : nil } ?? "—", lines: 1)
                    .font(.system(.title2, design: .serif, weight: .bold)).monospacedDigit()
                    .foregroundStyle(EKitapligimPalette.ink)
                UniformCardText(HomeRefreshL10n.text(label), lines: 2).font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, 9).frame(maxWidth: .infinity, minHeight: 48)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct ModernHomeEditorialPanel: View {
    let title: String
    let icon: String
    let books: [BookDTO]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.1))
            ForEach(books.prefix(4)) { book in
                NavigationLink(value: book.id) {
                    HStack(spacing: 14) {
                        EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                            .frame(width: 44, height: 66).clipShape(RoundedRectangle(cornerRadius: 5))
                        VStack(alignment: .leading, spacing: 5) {
                            UniformCardText(book.title, lines: 2)
                                .font(.subheadline.weight(.semibold)).foregroundStyle(EKitapligimPalette.ink)
                            UniformCardText(book.author, lines: 1)
                                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(tint)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if book.id != books.prefix(4).last?.id { Divider() }
            }
        }
        .background(EKitapligimPalette.paper, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(EKitapligimPalette.border) }
    }
}

enum ModernCatalogArtwork {
    static func asset(categoryID: String) -> String {
        let categories = ["6":"roman", "7":"edebiyat", "8":"egitim", "9":"bilim", "10":"tarih", "11":"din", "12":"psikoloji", "13":"kisisel_gelisim", "14":"ekonomi", "15":"cocuk", "16":"biyografi", "17":"felsefe", "18":"oyku", "19":"siyaset", "20":"romantik", "21":"fantastik", "22":"bilimkurgu", "23":"macera", "24":"polisiye", "25":"korku", "26":"genclik", "27":"saglik", "28":"turk_klasikleri", "29":"dunya_klasikleri", "30":"teknoloji", "32":"yabanci_dil", "33":"kultur_sanat", "34":"sinema_tiyatro", "35":"akademik", "36":"aile_yasam", "37":"yemek_mutfak"]
        return categories[categoryID].map { "catalog_category_\($0)" } ?? "catalog_scenic_reading"
    }
}
