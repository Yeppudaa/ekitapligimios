import SwiftUI
import EkitapligimCore

/// The site's original landscape artwork, with content-led height for Dynamic Type.
struct ModernHeroView: View {
    let artwork: String
    let eyebrow: String
    let title: String
    let subtitle: String
    var accent: Color = EKitapligimPalette.teal
    var minHeight: CGFloat = 210
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
                Text(title)
                    .font(dynamicTypeSize.isAccessibilitySize ? .title.bold() : .system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color(hex: 0x123E49))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x4D6D78))
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 10) {
                            Text(actionTitle).font(.subheadline.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                            if !dynamicTypeSize.isAccessibilitySize {
                                Image(systemName: "arrow.right").fixedSize().accessibilityHidden(true)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 19)
                        .padding(.vertical, 12)
                        .frame(minHeight: 48)
                        .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 23)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Image(artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: Color(hex: 0xFFFCF0).opacity(0.98), location: 0),
                            .init(color: Color(hex: 0xFFFCF0).opacity(0.90), location: 0.28),
                            .init(color: Color(hex: 0xFFFCF0).opacity(0.63), location: 0.62),
                            .init(color: Color(hex: 0xFFFCF0).opacity(0.06), location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .multilineTextAlignment(.leading)
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color(hex: 0xDCE5DF)) }
        .accessibilityElement(children: .contain)
    }
}

struct ModernSectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) { heading.fixedSize(); Spacer(minLength: 0); actionButton.fixedSize() }
            VStack(alignment: .leading, spacing: 8) { heading; actionButton }
        }
        .multilineTextAlignment(.leading)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Color(hex: 0x143E49))
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(EKitapligimPalette.muted) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var actionButton: some View {
        if let actionTitle, let action {
            Button(action: action) {
                Label(actionTitle, systemImage: "arrow.right").font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(EKitapligimPalette.tealDark).padding(.vertical, 10)
            }
            .buttonStyle(.plain).frame(minHeight: 44)
        }
    }
}

struct ModernShelfTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: String
    let icon: String
    var tint: Color = EKitapligimPalette.teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                let layout = dynamicTypeSize > .xLarge
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                layout {
                    Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint).frame(width: 31, height: 31)
                        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                    UniformCardText(title, lines: 2).font(.subheadline).foregroundStyle(EKitapligimPalette.ink)
                }
                UniformCardText(value, lines: 1).font(.title3.weight(.bold)).foregroundStyle(tint)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
            .overlay { RoundedRectangle(cornerRadius: 19).stroke(tint.opacity(0.17)) }
            .contentShape(RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
