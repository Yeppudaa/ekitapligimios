import SwiftUI
import EkitapligimCore

/// Native artwork matching the site's `ek_book_cover_fallback` and Android cover.
/// Scale the whole design into each existing cover frame so its author band is never cropped.
struct EKitapligimMissingBookCover: View {
    let title: String
    var author: String = ""

    private let designWidth: CGFloat = 236
    private let designHeight: CGFloat = 358

    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.bookCoverFallbackTitle : trimmed
    }

    var body: some View {
        GeometryReader { geometry in
            artwork
                .frame(width: designWidth, height: designHeight)
                .scaleEffect(
                    x: geometry.size.width / designWidth,
                    y: geometry.size.height / designHeight,
                    anchor: .topLeading
                )
        }
        .clipped()
        // The enclosing card or cover supplies one useful VoiceOver label.
        .accessibilityHidden(true)
    }

    private var artwork: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: 0x1B4B50), Color(hex: 0x12363F)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [Color(hex: 0xFFFCF5), Color(hex: 0xF1EBDF)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 265)

            Rectangle()
                .fill(Color(hex: 0xC3894B))
                .frame(height: 1.79)
                .offset(y: 263.85)

            Text(L10n.bookCoverBrand)
                .font(.system(size: 9.676, weight: .semibold))
                .tracking(1.548)
                .foregroundStyle(Color(hex: 0x31595F))
                .frame(width: 191.16)
                .offset(x: 28.32, y: 30.42)

            VStack(spacing: 21.5) {
                BookCoverEmblem()
                    .frame(width: 59.2, height: 44.4)
                Text(displayTitle)
                    .font(.custom("Georgia-Bold", fixedSize: 29.5))
                    .tracking(-1.03)
                    .foregroundStyle(Color(hex: 0x173B43))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .minimumScaleFactor(17 / 29.5)
                Rectangle()
                    .fill(Color(hex: 0xC58A4B))
                    .frame(width: 34.08, height: 2)
            }
            .frame(width: 179.36, height: 175.42)
            .offset(x: 33.04, y: 75.18)

            Text(author.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 14.16, weight: .medium))
                .foregroundStyle(Color(hex: 0xF4F0E7))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(10 / 14.16)
                .frame(width: 179.36, height: 41, alignment: .top)
                .offset(x: 33.04, y: 282.82)

            Text(L10n.bookCoverCollection)
                .font(.system(size: 7.316))
                .tracking(0.878)
                .foregroundStyle(Color(hex: 0xA8C3C2))
                .frame(width: 191.16)
                .offset(x: 28.32, y: 329.88)

            LinearGradient(stops: [
                .init(color: Color(hex: 0x103941), location: 0),
                .init(color: Color(hex: 0x2B585F), location: 0.2),
                .init(color: Color(hex: 0x144048), location: 0.462),
                .init(color: Color(hex: 0x123840).opacity(0.24), location: 0.523),
                .init(color: Color(hex: 0x123840).opacity(0), location: 1)
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: 15.34)
        }
    }
}

private struct BookCoverEmblem: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 80, y: size.height / 60)
            var book = Path()
            book.move(to: CGPoint(x: 17, y: 30))
            book.addCurve(to: CGPoint(x: 40, y: 7), control1: CGPoint(x: 17, y: 17.297), control2: CGPoint(x: 27.297, y: 7))
            book.addCurve(to: CGPoint(x: 63, y: 30), control1: CGPoint(x: 52.703, y: 7), control2: CGPoint(x: 63, y: 17.297))
            book.move(to: CGPoint(x: 8, y: 32))
            book.addCurve(to: CGPoint(x: 40, y: 39), control1: CGPoint(x: 20, y: 29), control2: CGPoint(x: 30, y: 32))
            book.addLine(to: CGPoint(x: 40, y: 55))
            book.addCurve(to: CGPoint(x: 8, y: 48), control1: CGPoint(x: 30, y: 48), control2: CGPoint(x: 20, y: 45))
            book.closeSubpath()
            book.move(to: CGPoint(x: 72, y: 32))
            book.addCurve(to: CGPoint(x: 40, y: 39), control1: CGPoint(x: 60, y: 29), control2: CGPoint(x: 50, y: 32))
            book.addLine(to: CGPoint(x: 40, y: 55))
            book.addCurve(to: CGPoint(x: 72, y: 48), control1: CGPoint(x: 50, y: 48), control2: CGPoint(x: 60, y: 45))
            book.closeSubpath()
            book.move(to: CGPoint(x: 14, y: 39))
            book.addCurve(to: CGPoint(x: 34, y: 45), control1: CGPoint(x: 21, y: 39), control2: CGPoint(x: 27, y: 41))
            book.move(to: CGPoint(x: 66, y: 39))
            book.addCurve(to: CGPoint(x: 46, y: 45), control1: CGPoint(x: 59, y: 39), control2: CGPoint(x: 53, y: 41))
            context.stroke(book, with: .color(Color(hex: 0x397377).opacity(0.85)),
                           style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: 36, y: 13, width: 8, height: 8)),
                         with: .color(Color(hex: 0xC58A4B).opacity(0.85)))
        }
    }
}
