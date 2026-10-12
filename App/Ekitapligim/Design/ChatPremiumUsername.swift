import SwiftUI
import EkitapligimCore

/// Native rendering of the site's gold `.username--style5` presentation.
struct ChatPremiumUsername: View {
    let username: String
    @ScaledMetric(relativeTo: .caption) private var em = 13.0

    var body: some View {
        HStack(spacing: 0) {
            ChatPremiumCrown()
                .frame(width: em * 0.95, height: em * 0.95)
                .accessibilityHidden(true)
            Rectangle()
                .fill(Color(hex: 0xB38523).opacity(0.32))
                .frame(width: 1, height: em)
                .padding(.leading, em * 0.28)
                .padding(.trailing, em * 0.35)
                .accessibilityHidden(true)
            Text(username)
                .font(.system(size: em, weight: .bold))
                .tracking(em * 0.01)
                .foregroundStyle(Color(hex: 0x765217))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, em * 0.42)
        .padding(.trailing, em * 0.65)
        .padding(.vertical, em * 0.18)
        .background {
            GeometryReader { geometry in
                // CSS 115deg: right and slightly down, with its 55% middle stop.
                let dx: CGFloat = 0.9063078
                let dy: CGFloat = 0.4226183
                let width = max(geometry.size.width, 1)
                let height = max(geometry.size.height, 1)
                let halfLength = (width * dx + height * dy) / 2
                LinearGradient(stops: [
                    .init(color: Color(hex: 0xFFFDF5), location: 0),
                    .init(color: Color(hex: 0xFFF1CC), location: 0.55),
                    .init(color: Color(hex: 0xF5E2AD), location: 1)
                ], startPoint: UnitPoint(x: 0.5 - dx * halfLength / width, y: 0.5 - dy * halfLength / height),
                   endPoint: UnitPoint(x: 0.5 + dx * halfLength / width, y: 0.5 + dy * halfLength / height))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xD8BD79), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(username)
        .accessibilityValue(L10n.profileRolePremiumMember)
    }
}

private struct ChatPremiumCrown: View {
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(scaleX: size.width / 24, y: size.height / 24)
            var crown = Path()
            crown.move(to: CGPoint(x: 4.5, y: 17.5))
            for point in [CGPoint(x: 3.3, y: 7.6), CGPoint(x: 8.4, y: 11),
                          CGPoint(x: 12, y: 4.8), CGPoint(x: 15.6, y: 11),
                          CGPoint(x: 20.7, y: 7.6), CGPoint(x: 19.5, y: 17.5)] {
                crown.addLine(to: point)
            }
            crown.closeSubpath()
            crown = crown.applying(transform)
            context.fill(crown, with: .color(Color(hex: 0xEBC569)))
            context.stroke(crown, with: .color(Color(hex: 0x9A711E)),
                           style: StrokeStyle(lineWidth: size.width * 1.4 / 24, lineJoin: .round))
            var base = Path()
            base.move(to: CGPoint(x: 5.5, y: 20))
            base.addLine(to: CGPoint(x: 18.5, y: 20))
            context.stroke(base.applying(transform), with: .color(Color(hex: 0x9A711E)),
                           style: StrokeStyle(lineWidth: size.width * 1.6 / 24, lineCap: .round))
        }
    }
}
