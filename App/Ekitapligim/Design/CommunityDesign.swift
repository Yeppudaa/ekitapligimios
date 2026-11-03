import SwiftUI

enum CommunityStyle {
    static let ink = Color(hex: 0x193F43)
    static let teal = Color(hex: 0x26756B)
    static let muted = Color(hex: 0x637671)
    static let border = Color(hex: 0xDDE8E1)
    static let soft = Color(hex: 0xF0F5EB)
    static let cream = Color(hex: 0xFAF8F0)
    static let page = LinearGradient(colors: [Color(hex: 0xF6FAF7), Color(hex: 0xFFFCF5), Color(hex: 0xF3F8F5)],
                                     startPoint: .top, endPoint: .bottom)
}

struct CommunityCard<Content: View>: View {
    let padding: CGFloat
    private let content: () -> Content
    init(padding: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }
    var body: some View {
        content().padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(CommunityStyle.border) }
    }
}

struct CommunityHero: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil
    var minHeight: CGFloat = 176

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(eyebrow).font(.caption2.weight(.bold)).tracking(1.6)
                .foregroundStyle(Color(hex: 0xE5D6AB))
            Text(title).font(.system(.largeTitle, design: .serif).bold()).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Color(hex: 0xDBE9E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let badge {
                Text(badge).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.white.opacity(0.14), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(23)
        .frame(minHeight: minHeight, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Image("agenda_reader_community").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .overlay {
                        LinearGradient(colors: [CommunityStyle.ink.opacity(0.95), CommunityStyle.ink.opacity(0.42)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
            }.accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .accessibilityElement(children: .combine)
    }
}

struct CommunityButtonStyle: ButtonStyle {
    var primary = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(primary ? .white : CommunityStyle.ink)
            .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 15).frame(minHeight: 54)
            .background(primary ? CommunityStyle.teal : CommunityStyle.cream, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(primary ? .clear : CommunityStyle.border) }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
