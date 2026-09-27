import SwiftUI
import EkitapligimCore

enum GiftWheelPalette {
    static let ink = color(0x302845)
    static let muted = color(0x736D82)
    static let violet = color(0x7454BC)
    static let gold = color(0xD89D39)
    static let paper = color(0xFAF9FC)
    static let border = color(0xE9E5EF)
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

/// Native vector drawing at the Android reference's 560-unit geometry. Rim, hub and pointer stay fixed.
struct GiftWheelDisc: View {
    let rotation: Double
    let segments: [GiftWheelSegmentDTO]
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 560, y: size.height / 560)
            let center = CGPoint(x: 280, y: 280)
            func circle(_ radius: CGFloat, center: CGPoint = CGPoint(x: 280, y: 280)) -> Path {
                Path(ellipseIn: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
            }
            func fill(_ radius: CGFloat, _ hex: UInt32) { context.fill(circle(radius), with: .color(GiftWheelPalette.color(hex))) }
            context.stroke(circle(278), with: .color(GiftWheelPalette.color(0xD6C8DF)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            context.fill(circle(270, center: CGPoint(x: 280, y: 304)), with: .radialGradient(
                Gradient(colors: [GiftWheelPalette.violet.opacity(0.14), .clear]), center: CGPoint(x: 280, y: 304), startRadius: 210, endRadius: 270))
            fill(258, 0xDCC8EC)
            context.fill(circle(253), with: .linearGradient(Gradient(colors: [0xC1A0E3, 0x7A5798, 0x422254, 0xB58CCE].map(GiftWheelPalette.color)),
                startPoint: CGPoint(x: 45, y: 35), endPoint: CGPoint(x: 510, y: 530)))
            for i in 0..<96 {
                let angle = Double(i) * 2 * .pi / 96
                context.fill(circle(3.4, center: CGPoint(x: 280 + cos(angle)*245, y: 280 + sin(angle)*245)), with: .color(GiftWheelPalette.color(0xFFF4C4)))
            }
            fill(237, 0xFFFAF0)
            var disc = context
            disc.translateBy(x: 280, y: 280); disc.rotate(by: .degrees(rotation)); disc.translateBy(x: -280, y: -280)
            for segment in segments {
                let start = -90 + Double(segment.index) * 30
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: 232, startAngle: .degrees(start), endAngle: .degrees(start + 30), clockwise: false)
                wedge.closeSubpath()
                disc.fill(wedge, with: .color(GiftWheelPalette.color(segment.colorHex)))
                disc.stroke(wedge, with: .color(GiftWheelPalette.color(0xFFFAF0)), lineWidth: 2.8)
                let angle = (start + 15) * .pi / 180
                let position = CGPoint(x: 280 + 167 * cos(angle), y: 280 + 167 * sin(angle))
                let ink = segment.days == 0 || segment.days == 30 ? GiftWheelPalette.color(0x393052) : Color.white
                let title = segment.days == 0 ? WheelL10n.text("retryTop") : segment.label
                disc.draw(Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(ink), at: position, anchor: .bottom)
                disc.draw(Text(WheelL10n.text(segment.days == 0 ? "retryBottom" : "premiumCaps"))
                    .font(.system(size: 7.5, weight: .bold)).foregroundColor(ink), at: CGPoint(x: position.x, y: position.y + 17))
            }
            context.fill(circle(55, center: CGPoint(x: 280, y: 285)), with: .color(GiftWheelPalette.color(0x46304F).opacity(0.2)))
            fill(52, 0xFFF8DA)
            context.fill(circle(46), with: .linearGradient(Gradient(colors: [GiftWheelPalette.color(0xFFEAA3), GiftWheelPalette.color(0xE5B044)]),
                startPoint: CGPoint(x: 230, y: 230), endPoint: CGPoint(x: 320, y: 330)))
            context.stroke(circle(43), with: .color(GiftWheelPalette.color(0xDFB458)), lineWidth: 1.5)
            var book = Path()
            book.move(to: CGPoint(x: 280, y: 271))
            book.addCurve(to: CGPoint(x: 264, y: 267), control1: CGPoint(x: 273, y: 265), control2: CGPoint(x: 264, y: 265))
            book.addLine(to: CGPoint(x: 264, y: 288))
            book.addCurve(to: CGPoint(x: 280, y: 291), control1: CGPoint(x: 270, y: 286), control2: CGPoint(x: 275, y: 288))
            book.addCurve(to: CGPoint(x: 296, y: 288), control1: CGPoint(x: 285, y: 288), control2: CGPoint(x: 290, y: 286))
            book.addLine(to: CGPoint(x: 296, y: 267))
            book.addCurve(to: CGPoint(x: 280, y: 271), control1: CGPoint(x: 292, y: 264), control2: CGPoint(x: 285, y: 266))
            book.addLine(to: CGPoint(x: 280, y: 291))
            context.stroke(book, with: .color(GiftWheelPalette.color(0x75501C)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            context.draw(Text(WheelL10n.text("goodLuck")).font(.system(size: 8.5, weight: .bold)).foregroundColor(GiftWheelPalette.color(0x75501C)), at: CGPoint(x: 280, y: 308))
            var pointer = Path()
            pointer.move(to: CGPoint(x: 258, y: 8)); pointer.addLine(to: CGPoint(x: 302, y: 8))
            pointer.addLine(to: CGPoint(x: 280, y: 54)); pointer.closeSubpath()
            context.fill(pointer, with: .color(GiftWheelPalette.color(0xFFF6CB)))
            context.stroke(pointer, with: .color(GiftWheelPalette.color(0x735187)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            sparkle(context, x: 25, y: 38, radius: 16, color: 0xD9A650)
            sparkle(context, x: 535, y: 512, radius: 18, color: 0xA58AC4)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WheelL10n.text("discAccessibility"))
        .accessibilityIdentifier("gift-wheel-disc")
    }
    private func sparkle(_ context: GraphicsContext, x: CGFloat, y: CGFloat, radius: CGFloat, color: UInt32) {
        var star = Path()
        star.move(to: CGPoint(x: x, y: y-radius))
        star.addQuadCurve(to: CGPoint(x: x+radius, y: y), control: CGPoint(x: x+radius*0.22, y: y-radius*0.22))
        star.addQuadCurve(to: CGPoint(x: x, y: y+radius), control: CGPoint(x: x+radius*0.22, y: y+radius*0.22))
        star.addQuadCurve(to: CGPoint(x: x-radius, y: y), control: CGPoint(x: x-radius*0.22, y: y+radius*0.22))
        star.addQuadCurve(to: CGPoint(x: x, y: y-radius), control: CGPoint(x: x-radius*0.22, y: y-radius*0.22))
        context.fill(star, with: .color(GiftWheelPalette.color(color)))
    }
}
