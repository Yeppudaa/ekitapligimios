import SwiftUI
import EkitapligimCore

enum DirectoryStyle {
    static let ink = Color(hex: 0x1B414A)
    static let muted = Color(hex: 0x5E736C)
    static let border = Color(hex: 0xDDE6E1)
    static let cream = Color(hex: 0xFCF8EF)
    static func accent(_ kind: DirectoryKind) -> Color {
        kind == .author ? Color(hex: 0x087A80) : Color(hex: 0x87652F)
    }
    static func symbol(_ kind: DirectoryKind) -> String {
        kind == .author ? "person.text.rectangle" : "building.2"
    }
}

struct DirectoryScenicHeader: View {
    let kind: DirectoryKind
    let totalEntries: Int
    let totalBooks: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var prefix: String { kind == .author ? "authors" : "publishers" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                Image(kind == .author ? "directory_authors_hero" : "directory_publishers_hero")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, DirectoryStyle.cream], startPoint: .top, endPoint: .bottom)
                            .frame(height: 48)
                    }
            }
            .frame(height: 150).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(CommunityRefreshL10n.text(kind == .author ? "directory.authorsEyebrow" : "directory.publishersEyebrow"))
                    .font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(DirectoryStyle.accent(kind))
                VStack(alignment: .leading, spacing: 0) {
                    Text(DirectoryDesignL10n.text("\(prefix).title")).foregroundStyle(DirectoryStyle.ink)
                    Text(DirectoryDesignL10n.text("\(prefix).emphasis")).italic().foregroundStyle(DirectoryStyle.accent(kind))
                }
                .font(.system(.title, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                Text(DirectoryDesignL10n.text("\(prefix).subtitle"))
                    .font(.subheadline).foregroundStyle(DirectoryStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    statistic(totalEntries, title: kind == .author ? L10n.homeAuthors : L10n.homePublishers,
                              symbol: DirectoryStyle.symbol(kind))
                    statistic(totalBooks, title: L10n.directoryStatBooks, symbol: "books.vertical")
                }.padding(.top, 4)
            }.padding(.horizontal, 20).padding(.bottom, 22)
        }
        .background(DirectoryStyle.cream, in: RoundedRectangle(cornerRadius: 26))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(DirectoryStyle.border) }
        .accessibilityIdentifier("directory.hero")
    }

    private func statistic(_ value: Int, title: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(DirectoryStyle.accent(kind)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(EKitapligimFormat.count(value)).font(.subheadline.weight(.bold)).foregroundStyle(DirectoryStyle.ink)
                Text(title).font(.caption).foregroundStyle(DirectoryStyle.muted)
            }.fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct DirectoryEntryCard: View {
    let kind: DirectoryKind
    let item: DirectoryItemDTO
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [DirectoryStyle.accent(kind).opacity(0.13), DirectoryStyle.cream], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: kind == .author ? "text.book.closed" : "books.vertical")
                    .font(.system(size: 28, weight: .light)).foregroundStyle(DirectoryStyle.accent(kind))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Image(systemName: kind == .author ? "pencil.tip" : "building.2")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(DirectoryStyle.accent(kind))
                    .padding(5).background(.white, in: Circle()).padding(4)
            }.frame(width: 62, height: 68).accessibilityHidden(true)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.name).font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(DirectoryStyle.ink).fixedSize(horizontal: false, vertical: true)
                    Label(L10n.directoryBookCount(item.bookCount), systemImage: "book.closed")
                        .font(.caption).foregroundStyle(DirectoryStyle.accent(kind))
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(DirectoryStyle.accent(kind)).accessibilityHidden(true)
            }
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 21))
        .overlay { RoundedRectangle(cornerRadius: 21).strokeBorder(DirectoryStyle.border) }
        .accessibilityElement(children: .combine)
    }
}
