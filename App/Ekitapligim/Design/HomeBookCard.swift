import SwiftUI
import EkitapligimCore

/// The slot, not the downloaded image's aspect ratio or loading phase, owns cover geometry.
struct HomeBookCoverSlot<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        Color.clear
            .aspectRatio(1 / 1.48, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    content
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct HomeBookCard: View {
    let book: BookDTO

    private var displayTitle: String {
        let title = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? L10n.bookCoverFallbackTitle : title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HomeBookCoverSlot {
                EKitapligimRemoteCover(urlString: book.coverUrl, title: displayTitle,
                                      author: book.author, contentMode: .fit)
            }
            .padding(10)
            .background(EKitapligimPalette.tealSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.libraryCoverAccessibility(displayTitle))
            .accessibilityIdentifier("home.book.cover.\(book.id)")

            VStack(alignment: .leading, spacing: 5) {
                Label {
                    UniformCardText(book.category, lines: 1)
                } icon: {
                    Image(systemName: "book.closed").accessibilityHidden(true)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.teal)
                .opacity(book.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
                .accessibilityHidden(book.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("home.book.category.\(book.id)")

                UniformCardText(displayTitle, lines: 2)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .accessibilityIdentifier("home.book.title.\(book.id)")

                UniformCardText(book.author, lines: 1)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .accessibilityHidden(book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("home.book.author.\(book.id)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .ekitapligimCard(radius: 18)
    }
}
