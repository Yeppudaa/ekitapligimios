import SwiftUI
import EkitapligimCore

struct PremiumAvatarFrame<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    let size: CGFloat
    private let content: (CGFloat) -> Content

    init(size: CGFloat, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.size = size
        self.content = content
    }

    private var running: Bool {
        PremiumAvatarAppearance.animates(isPremium: true, reduceMotion: reduceMotion,
            sceneActive: scenePhase == .active, visible: visible)
    }

    var body: some View {
        ZStack {
            content(size * PremiumAvatarAppearance.photoDiameterRatio)
                .frame(width: size * PremiumAvatarAppearance.photoDiameterRatio,
                       height: size * PremiumAvatarAppearance.photoDiameterRatio)
                .clipShape(Circle())
                .offset(y: size * (PremiumAvatarAppearance.photoCenterYRatio - 0.5))
            if running {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    PremiumAvatarArtwork(
                        cycle: PremiumAvatarAppearance.phase(elapsed: elapsed, duration: PremiumAvatarAppearance.sweepDuration),
                        sparkle: PremiumAvatarAppearance.phase(elapsed: elapsed, duration: PremiumAvatarAppearance.sparkleDuration)
                    )
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            } else {
                PremiumAvatarArtwork(cycle: PremiumAvatarAppearance.restingPhase, sparkle: PremiumAvatarAppearance.restingPhase)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PremiumAvatarL10n.frame)
        .accessibilityIdentifier("premium.avatar.frame")
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

/// The avatar and book stay still while two trails travel around the metal rim.
struct PremiumAvatarArtwork: View {
    let cycle: Double
    let sparkle: Double
    private static let gold = Color(hex: 0xEBCB86)
    private static let ink = Color(hex: 0x382A13)
    private static let center = CGPoint(x: 50, y: PremiumAvatarAppearance.photoCenterYRatio * 100)
    private static let gradient = Gradient(colors: [0xFFF4D2, 0xEBCB86, 0xA97C36, 0xF9E4AA, 0xD2A95E, 0x7C5B24, 0xE6C47F].map { Color(hex: $0) })

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.scaleBy(x: scale, y: scale)
            drawRing(in: context)
            drawTrails(in: context)
            drawSparkles(in: context)
            drawBook(in: context)
        }
        .allowsHitTesting(false)
    }

    private var goldShading: GraphicsContext.Shading {
        .linearGradient(Self.gradient, startPoint: CGPoint(x: 14, y: 8), endPoint: CGPoint(x: 79, y: 96))
    }

    private func circle(radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: Self.center.x - radius, y: Self.center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func drawRing(in context: GraphicsContext) {
        let pulse = 0.5 + 0.5 * sin(sparkle * 2 * .pi)
        for step in stride(from: 8, through: 1, by: -1) {
            context.stroke(circle(radius: 43 + Double(step) * 0.42),
                with: .color(Self.gold.opacity((0.018 + pulse * 0.010) * Double(9 - step))), lineWidth: 1.2)
        }
        context.stroke(circle(radius: PremiumAvatarAppearance.ringRadius), with: .color(Self.ink), lineWidth: 5.2)
        context.stroke(circle(radius: PremiumAvatarAppearance.ringRadius), with: goldShading, lineWidth: PremiumAvatarAppearance.ringWidth)
        context.stroke(circle(radius: 40.9), with: .color(Color(hex: 0xFFEEC3).opacity(0.88)), lineWidth: 0.8)
        context.stroke(circle(radius: 45.2), with: .color(Color(hex: 0x7C5B24).opacity(0.8)), lineWidth: 0.55)
    }

    private func drawTrails(in context: GraphicsContext) {
        for trail in 0..<2 {
            let angle = -90 + cycle * 360 + Double(trail) * 180
            for segment in 0..<12 {
                let strength = (1 - Double(segment) / 12) * (trail == 0 ? 0.95 : 0.70)
                let start = angle - Double(segment) * 3.5
                var arc = Path()
                arc.addArc(center: Self.center, radius: PremiumAvatarAppearance.ringRadius, startAngle: .degrees(start), endAngle: .degrees(start + 4), clockwise: false)
                context.stroke(arc, with: .color(Color(hex: 0xFFF9DC).opacity(strength)),
                    style: StrokeStyle(lineWidth: 3.1, lineCap: .round))
            }
        }
    }

    private func drawSparkles(in context: GraphicsContext) {
        for (index, angle) in [222.0, 320, 145, 18, 78, 182].enumerated() {
            let wave = 0.5 + 0.5 * sin((sparkle + Double(index) * 0.19) * 2 * .pi)
            let radians = angle * .pi / 180
            let point = CGPoint(x: Self.center.x + cos(radians) * PremiumAvatarAppearance.ringRadius,
                                y: Self.center.y + sin(radians) * PremiumAvatarAppearance.ringRadius)
            let radius = 1.5 + wave * 2.1
            var starContext = context
            starContext.translateBy(x: point.x, y: point.y)
            starContext.rotate(by: .degrees(sparkle * 90))
            let glow = Path(ellipseIn: CGRect(x: -radius * 2, y: -radius * 2, width: radius * 4, height: radius * 4))
            starContext.fill(glow, with: .radialGradient(Gradient(colors: [
                Color(hex: 0xFFE6A6).opacity(0.28 + wave * 0.28), Self.gold.opacity(0.10 + wave * 0.10), .clear
            ]), center: .zero, startRadius: 0, endRadius: radius * 2))
            var star = Path()
            star.move(to: CGPoint(x: 0, y: -radius))
            star.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: radius * 0.2, y: -radius * 0.2))
            star.addQuadCurve(to: CGPoint(x: 0, y: radius), control: CGPoint(x: radius * 0.2, y: radius * 0.2))
            star.addQuadCurve(to: CGPoint(x: -radius, y: 0), control: CGPoint(x: -radius * 0.2, y: radius * 0.2))
            star.addQuadCurve(to: CGPoint(x: 0, y: -radius), control: CGPoint(x: -radius * 0.2, y: -radius * 0.2))
            star.closeSubpath()
            starContext.fill(star, with: .color(Color(hex: 0xFFF9E8).opacity(0.5 + wave * 0.5)))
        }
    }

    private func drawBook(in context: GraphicsContext) {
        var book = Path()
        book.move(to: CGPoint(x: 50, y: 7))
        book.addCurve(to: CGPoint(x: 42, y: 5.6), control1: CGPoint(x: 47, y: 4.8), control2: CGPoint(x: 43.6, y: 4.8))
        book.addLine(to: CGPoint(x: 42, y: 15))
        book.addCurve(to: CGPoint(x: 50, y: 16.3), control1: CGPoint(x: 44.8, y: 14.3), control2: CGPoint(x: 47.8, y: 14.7))
        book.addCurve(to: CGPoint(x: 58, y: 15), control1: CGPoint(x: 52.2, y: 14.7), control2: CGPoint(x: 55.2, y: 14.3))
        book.addLine(to: CGPoint(x: 58, y: 5.6))
        book.addCurve(to: CGPoint(x: 50, y: 7), control1: CGPoint(x: 55.6, y: 4.8), control2: CGPoint(x: 52.8, y: 5))
        book.closeSubpath()
        context.stroke(book, with: .color(Self.ink), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        context.fill(book, with: goldShading)
        context.stroke(book, with: .color(Color(hex: 0xFFF2C6)), lineWidth: 0.65)
        strokeLine(from: CGPoint(x: 50, y: 7.5), to: CGPoint(x: 50, y: 14.6), color: Self.ink, width: 0.8, in: context)
        for line in [([44.0, 8.4], [48.0, 9.2]), ([52.0, 9.2], [56.0, 8.4]),
                     ([44.0, 11.1], [48.0, 11.9]), ([52.0, 11.9], [56.0, 11.1])] {
            strokeLine(from: CGPoint(x: line.0[0], y: line.0[1]), to: CGPoint(x: line.1[0], y: line.1[1]),
                color: Color(hex: 0x9A702D), width: 0.65, in: context)
        }
    }

    private func strokeLine(from start: CGPoint, to end: CGPoint, color: Color, width: CGFloat, in context: GraphicsContext) {
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

/// An inline badge follows the last username character even when the name wraps.
struct PremiumMemberName: View {
    let username: String
    let isPremium: Bool
    var isVerified = false
    var badgeColor: Color = Color(hex: 0xC89227)

    var body: some View {
        let showBadge = isPremium || isVerified
        let name = Text(username)
        let badge = Text(Image(systemName: "checkmark.seal.fill")).foregroundColor(badgeColor)
        (showBadge ? name + Text(" ") + badge : name)
            .accessibilityLabel(username)
            .accessibilityValue(isPremium ? PremiumAvatarL10n.verifiedMember : (isVerified ? L10n.membersVerified : ""))
    }
}

struct PremiumMemberPill: View {
    var body: some View {
        Label(L10n.profileRolePremium, systemImage: "medal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(hex: 0x84540D))
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(LinearGradient(colors: [Color(hex: 0xFFF7DF), Color(hex: 0xFFE9AF)],
                startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay { Capsule().strokeBorder(Color(hex: 0xE6BF68), lineWidth: 0.8) }
    }
}
