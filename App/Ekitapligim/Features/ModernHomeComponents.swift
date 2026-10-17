import SwiftUI
import EkitapligimCore

struct ModernHomeGenreStrip: View {
    @ScaledMetric(relativeTo: .headline) private var tileWidth = 132.0
    @ScaledMetric(relativeTo: .headline) private var tileHeight = 154.0
    private let genres = [
        ("6", "roman"), ("21", "fantastik"), ("13", "kisisel_gelisim"), ("7", "edebiyat"),
        ("12", "psikoloji"), ("10", "tarih"), ("9", "bilim"), ("15", "cocuk")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(genres, id: \.0) { genre in
                    NavigationLink { CatalogView(initialCategoryID: genre.0) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Spacer(minLength: 40)
                            HStack(alignment: .bottom, spacing: 8) {
                                Text(HomeRefreshL10n.text("genre.\(genre.1)"))
                                    .font(.system(.headline, design: .serif, weight: .bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EKitapligimPalette.ink)
                                    .frame(width: 26, height: 26)
                                    .background(.white, in: Circle())
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(width: tileWidth, alignment: .bottomLeading)
                        .frame(minHeight: tileHeight, alignment: .bottomLeading)
                        .background {
                            Image("home_genre_\(genre.1)").resizable().scaledToFill()
                                .overlay { LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.genre.\(genre.0)")
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct ModernHomeSpotlight: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: BookDTO

    var body: some View {
        NavigationLink(value: book.id) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 16) { cover; copy }
                } else {
                    HStack(alignment: .top, spacing: 16) { cover; copy }
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
        .accessibilityIdentifier("home.editorialSpotlight")
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
            if !book.author.isEmpty { Text(book.author).font(.subheadline).foregroundStyle(EKitapligimPalette.muted) }
            Label(HomeRefreshL10n.text("next.caption"), systemImage: "book")
                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
            Label(HomeRefreshL10n.text("next.action"), systemImage: "arrow.right")
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(EKitapligimPalette.teal, in: Capsule())
        }
        .multilineTextAlignment(.leading)
    }
}

struct ModernHomeReadingPanel: View {
    let item: LibraryItemDTO?
    let otherBooks: [LibraryItemDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(HomeRefreshL10n.text("continue.read"), systemImage: "book.pages")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(EKitapligimPalette.ink)
            Text(HomeRefreshL10n.text("continue.subtitle"))
                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
            if let item {
                NavigationLink(value: item.bookId) {
                    ModernLibraryResumeItem(item: item)
                }
                .buttonStyle(.plain)
                ProgressView(value: Double(item.displayProgressPercent), total: 100)
                    .tint(EKitapligimPalette.amber)
                    .accessibilityLabel(L10n.libraryReadingProgressLabel)
                    .accessibilityValue(L10n.commonPercent(item.displayProgressPercent))
                NavigationLink(value: item.bookId) {
                    Label(HomeRefreshL10n.text("continue.read"), systemImage: "book.pages.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12).frame(minHeight: 48)
                        .background(EKitapligimPalette.teal, in: Capsule())
                }
                .buttonStyle(.plain)
                if !otherBooks.isEmpty {
                    Divider()
                    Text(HomeRefreshL10n.text("continue.more")).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(otherBooks, id: \.bookId) { next in
                                NavigationLink(value: next.bookId) {
                                    ModernLibraryResumeItem(item: next, compact: true)
                                        .frame(width: 220, alignment: .leading).padding(12)
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
            Text(item.title).font(compact ? .subheadline.weight(.semibold) : .system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
            if !item.author.isEmpty { Text(item.author).font(.caption).foregroundStyle(EKitapligimPalette.muted) }
        }
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
                            Text(book.title).font(.subheadline.weight(.semibold)).foregroundStyle(EKitapligimPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(book.author).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)
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
