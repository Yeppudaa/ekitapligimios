import SwiftUI
import EkitapligimCore

@MainActor
struct ModernProfileBooksSection: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onLibrary: (LibraryTab) -> Void
    let onDownloads: () -> Void
    let onComments: () -> Void
    let onJourney: () -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            ModernSectionHeading(title: ShellRefreshL10n.text("profileWrittenTitle"),
                subtitle: ShellRefreshL10n.text("profileWrittenEyebrow"), actionTitle: L10n.menuLibrary,
                action: { onLibrary(.reading) })
            continueCard
            ModernSectionHeading(title: ShellRefreshL10n.text("profileShelves"),
                subtitle: ShellRefreshL10n.text("profileShelvesNote"))
            LazyVGrid(columns: columns, spacing: 10) {
                ModernShelfTile(title: L10n.libraryTabFavorites, value: String(container.favoriteBooks.count), icon: "heart", tint: Color(hex: 0xAC7967)) { onLibrary(.favorites) }
                    .accessibilityIdentifier("profile.ebook.shelf.3")
                ModernShelfTile(title: L10n.profileActionReadLater, value: String(container.wantToRead.count), icon: "bookmark") { onLibrary(.wantToRead) }
                    .accessibilityIdentifier("profile.ebook.shelf.1")
                ModernShelfTile(title: L10n.profileActionReadingNow, value: String(container.currentlyReading.count), icon: "book.pages") { onLibrary(.reading) }
                ModernShelfTile(title: L10n.profileActionFinished, value: String(container.finishedBooks.count), icon: "checkmark.circle.fill", tint: Color(hex: 0x72875D)) { onLibrary(.finished) }
                    .accessibilityIdentifier("profile.ebook.shelf.2")
                ModernShelfTile(title: L10n.profileActionDownloads, value: String(container.downloadedBooks.count), icon: "arrow.down.circle.fill", action: onDownloads)
                ModernShelfTile(title: L10n.profileActionMyComments, value: "→", icon: "text.bubble", tint: Color(hex: 0xB48A40), action: onComments)
            }
            Button(action: onJourney) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { completedNote; Spacer(minLength: 0); journeyLabel }
                    VStack(alignment: .leading, spacing: 10) { completedNote; journeyLabel }
                }
                .padding(.vertical, 8).frame(minHeight: 48)
            }
            .buttonStyle(.plain)
        }
        .padding(17).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0xF8FCF8), Color(hex: 0xE9F4EF)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25))
        .overlay { RoundedRectangle(cornerRadius: 25).stroke(Color(hex: 0xD4E5DF)) }
        .accessibilityIdentifier("profile-ebook-space")
    }

    private var completedNote: some View {
        Label(ShellRefreshL10n.count(container.finishedBooks.count), systemImage: "clock")
            .font(.caption).foregroundStyle(EKitapligimPalette.muted)
    }

    private var journeyLabel: some View {
        Label(ShellRefreshL10n.text("profileJourney"), systemImage: "arrow.right")
            .font(.caption.weight(.bold)).foregroundStyle(EKitapligimPalette.tealDark)
    }

    private var continueCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(ShellRefreshL10n.text("profileContinueEyebrow"))
                .font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(EKitapligimPalette.tealDark)
            if let item = container.continueReadingItem {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 13))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
                layout {
                    EKitapligimRemoteCover(urlString: item.coverUrl, title: item.title, author: item.author, accessibilityTitle: item.title)
                        .frame(width: 69, height: 104).clipShape(RoundedRectangle(cornerRadius: 9))
                        .shadow(color: EKitapligimPalette.teal.opacity(0.12), radius: 7, y: 5)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(item.title).font(.headline).foregroundStyle(Color(hex: 0x173E48))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.author).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                        ProgressView(value: Double(item.displayProgressPercent), total: 100)
                            .tint(EKitapligimPalette.teal)
                            .accessibilityValue(L10n.commonPercent(item.displayProgressPercent))
                        Text(item.positionType == "epub" ? L10n.commonPercent(item.displayProgressPercent) : L10n.continueReadingFromPage(max(item.lastReadPage, 1)))
                            .font(.caption).foregroundStyle(EKitapligimPalette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let bookID = Int(item.bookId), bookID > 0 {
                    Button { container.open(route: .reader(bookID)) } label: {
                        Label(L10n.homeContinueAction, systemImage: "book.pages")
                            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                            .padding(.horizontal, 15).padding(.vertical, 13)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .background(LinearGradient(colors: [Color(hex: 0x37858A), Color(hex: 0x245A65)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("profile-ebook-continue")
                }
            } else {
                Text(L10n.continueReadingEmptyTitle).font(.headline).foregroundStyle(EKitapligimPalette.ink)
                Text(L10n.continueReadingEmptySubtitle).font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
                Button { container.open(route: .catalog) } label: {
                    Label(L10n.homeHeroPrimaryAction, systemImage: "arrow.right").font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.tealDark).frame(minHeight: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xE9F2ED), in: RoundedRectangle(cornerRadius: 21))
        .overlay { RoundedRectangle(cornerRadius: 21).stroke(Color(hex: 0xD2E4DE)) }
    }
}
