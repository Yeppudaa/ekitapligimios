import SwiftUI

/// Scoped to the November reading-room screens; purchase surfaces keep their own design.
struct ReadingRoomStyle {
    let scheme: ColorScheme
    var page: Color { scheme == .dark ? Color(hex: 0x132623) : Color(hex: 0xF5F7F1) }
    var paper: Color { scheme == .dark ? Color(hex: 0x1D322D) : Color(hex: 0xFFFAF0) }
    var card: Color { scheme == .dark ? Color(hex: 0x243D36) : Color(hex: 0xFFFEF9) }
    var ink: Color { scheme == .dark ? Color(hex: 0xF4F2E7) : Color(hex: 0x193F43) }
    var muted: Color { scheme == .dark ? Color(hex: 0xB6C9BF) : Color(hex: 0x607772) }
    var accent: Color { scheme == .dark ? Color(hex: 0xA3D4BD) : Color(hex: 0x285F56) }
    var border: Color { scheme == .dark ? Color(hex: 0x496257) : Color(hex: 0xDDE5D6) }
    var soft: Color { scheme == .dark ? Color(hex: 0x314B40) : Color(hex: 0xEDF3E7) }
    static let forest = Color(hex: 0x285F56)
    static let gold = Color(hex: 0xF2D194)
}

struct ReadingRoomArtwork: View {
    let name: String
    var height: CGFloat = 160
    var body: some View {
        Color.clear.frame(height: height)
            .overlay {
                GeometryReader { geometry in
                    Image(name).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
            .accessibilityHidden(true)
    }
}

struct ReadingRoomButtonStyle: ButtonStyle {
    var gold = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(gold ? Color(hex: 0x153E40) : .white)
            .padding(.horizontal, 20).padding(.vertical, 15)
            .frame(minHeight: 50)
            .background(gold ? ReadingRoomStyle.gold : ReadingRoomStyle.forest,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
