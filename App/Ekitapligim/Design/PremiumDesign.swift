import SwiftUI
import EkitapligimCore

/// Screen-local presentation matching the Android Premium artwork and palette.
enum PremiumStyle {
    static let page = Color("PremiumPage")
    static let surface = Color("PremiumSurface")
    static let ink = Color("PremiumInk")
    static let muted = Color("PremiumMuted")
    static let border = Color("PremiumBorder")
    static let accent = Color("PremiumAccent")
    static let highlight = Color("PremiumHighlight")
    static let success = Color("PremiumSuccess")
    static let danger = Color("PremiumDanger")
    static let navy = Color(hex: 0x153E43)
    static let gold = Color(hex: 0xF2D19A)
    static let cream = Color(hex: 0xFFF9EB)
}

struct PremiumHeroCard: View {
    var membershipStatus: String? = nil
    let onExplore: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32
    @ScaledMetric(relativeTo: .title2) private var headlineSize: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var bodySize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 8) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 23))
                    .accessibilityHidden(true)
                Text(L10n.premiumEyebrow)
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(PremiumStyle.gold)

            Text(PremiumDesignL10n.text("hero.title"))
                .font(.system(size: titleSize, weight: .bold, design: .serif))
                .foregroundStyle(PremiumStyle.cream)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(PremiumDesignL10n.text("hero.headline"))
                .font(.system(size: headlineSize, design: .serif))
                .foregroundStyle(PremiumStyle.gold)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(PremiumDesignL10n.text("hero.subtitle"))
                .font(.system(size: bodySize))
                .foregroundStyle(Color(hex: 0xE3EFEB))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            if let membershipStatus {
                Label(membershipStatus, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0xD9EEE1))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onExplore) {
                PremiumActionLabel(title: PremiumDesignL10n.text("hero.explore"), trailingSystemImage: "arrow.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PremiumStyle.navy)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(minHeight: 52)
                .background(PremiumStyle.gold, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("premium.explorePlans")
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            PremiumArtworkBackground(artwork: "catalog_scenic_reading", colors: [
                Color(hex: 0x0D363C).opacity(0.89),
                Color(hex: 0x123E43).opacity(0.84),
                Color(hex: 0x0B353A).opacity(0.98)
            ])
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("premium.hero")
    }
}

struct PremiumSectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(PremiumStyle.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PremiumStyle.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PremiumAudioBenefitCard: View {
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 27
    @ScaledMetric(relativeTo: .footnote) private var bodySize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(PremiumDesignL10n.text("audio.eyebrow"), systemImage: "headphones")
                .font(.caption.weight(.bold))
                .foregroundStyle(PremiumStyle.gold)
                .labelStyle(PremiumAudioLabelStyle())
            Text(PremiumDesignL10n.text("audio.title"))
                .font(.system(size: titleSize, weight: .bold, design: .serif))
                .foregroundStyle(PremiumStyle.cream)
                .accessibilityAddTraits(.isHeader)
            Text(PremiumDesignL10n.text("audio.subtitle"))
                .font(.system(size: bodySize))
                .foregroundStyle(Color(hex: 0xE1EFEB))
                .lineSpacing(6)
            Text(PremiumDesignL10n.text("audio.note"))
                .font(.caption2)
                .foregroundStyle(Color(hex: 0xF4DCAE))
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            PremiumArtworkBackground(artwork: "audio_story_landscape", colors: [
                Color(hex: 0x103D43).opacity(0.96),
                Color(hex: 0x174C50).opacity(0.90),
                Color(hex: 0x174C50).opacity(0.88)
            ], horizontal: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("premium.benefit.audio")
    }
}

private struct PremiumAudioLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 9) {
            if dynamicTypeSize <= .xLarge {
                configuration.icon.font(.title2).fixedSize().accessibilityHidden(true)
            }
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
    }
}

struct PremiumQuotaCards: View {
    let availableWidth: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stackCards = availableWidth < 340 || dynamicTypeSize > .xLarge
        let layout = stackCards
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            PremiumQuotaCard(kind: "reading", artwork: "audio_shelf_continue", systemImage: "book.fill")
            PremiumQuotaCard(kind: "downloads", artwork: "catalog_scenic_reading", systemImage: "icloud.and.arrow.down.fill")
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PremiumQuotaCard: View {
    let kind: String
    let artwork: String
    let systemImage: String
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(PremiumDesignL10n.text("\(kind).eyebrow"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(hex: 0xFFE5B1))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(hex: 0x143F43).opacity(0.92), in: RoundedRectangle(cornerRadius: 9))
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .bottomLeading)
                .background {
                    PremiumArtworkBackground(artwork: artwork, colors: [
                        .clear, Color(hex: 0x123F43).opacity(0.5)
                    ])
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text(PremiumDesignL10n.text("\(kind).value"))
                        .font(.system(size: valueSize, weight: .bold, design: .serif))
                        .foregroundStyle(PremiumStyle.accent)
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    PremiumBenefitIcon(systemImage: systemImage)
                }
                Text(PremiumDesignL10n.text("\(kind).title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PremiumStyle.ink)
                Text(PremiumDesignL10n.text("\(kind).subtitle"))
                    .font(.footnote)
                    .foregroundStyle(PremiumStyle.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
        .background(PremiumStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(PremiumStyle.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("premium.benefit.\(kind)")
    }
}

private struct PremiumBenefitIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 21))
            .foregroundStyle(PremiumStyle.accent)
            .frame(width: 40, height: 40)
            .background(PremiumStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }
}

struct PremiumExtraBenefitsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            benefit("adFree", systemImage: "nosign")
            Divider().overlay(PremiumStyle.border)
            benefit("requests", systemImage: "timer")
            Divider().overlay(PremiumStyle.border)
            benefit("themes", systemImage: "paintpalette.fill")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .premiumSurface()
        .accessibilityIdentifier("premium.benefits.more")
    }

    private func benefit(_ key: String, systemImage: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            PremiumBenefitIcon(systemImage: systemImage)
            VStack(alignment: .leading, spacing: 5) {
                Text(PremiumDesignL10n.text("\(key).title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PremiumStyle.ink)
                Text(PremiumDesignL10n.text("\(key).subtitle"))
                    .font(.footnote)
                    .foregroundStyle(PremiumStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}

/// A label for the existing purchase button; it has no selection or billing state.
struct PremiumPlanCard: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let name: String
    let price: String
    let period: String
    var tagline: String? = nil
    var isYearly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isYearly {
                Label(PremiumDesignL10n.text("plans.yearlyBadge"), systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PremiumStyle.navy)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PremiumStyle.gold, in: RoundedRectangle(cornerRadius: 8))
            }
            HStack(alignment: .top, spacing: 12) {
                Text(name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if dynamicTypeSize <= .xLarge {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PremiumStyle.accent)
                        .fixedSize()
                        .accessibilityHidden(true)
                }
            }
            Text(price)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(period)
                .font(.caption)
                .foregroundStyle(PremiumStyle.muted)
            Divider().overlay(PremiumStyle.border)
            if let tagline {
                Text(tagline)
                    .font(.caption)
                    .foregroundStyle(PremiumStyle.muted)
            }
            PremiumActionLabel(title: L10n.premiumPurchaseAction, systemImage: "lock.shield", trailingSystemImage: "arrow.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isEnabled ? PremiumStyle.navy : PremiumStyle.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(minHeight: 48)
                .background(isEnabled ? PremiumStyle.gold : PremiumStyle.border, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(PremiumStyle.ink)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [isYearly ? PremiumStyle.highlight : PremiumStyle.surface, PremiumStyle.surface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isYearly ? PremiumStyle.accent : PremiumStyle.border, lineWidth: isYearly ? 2 : 1)
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Decorative icons yield their width to the full, wrapping label at large text sizes.
struct PremiumActionLabel: View {
    let title: String
    var systemImage: String? = nil
    var trailingSystemImage: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            if dynamicTypeSize <= .xLarge, let systemImage {
                Image(systemName: systemImage)
                    .fixedSize()
                    .accessibilityHidden(true)
            }
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            if dynamicTypeSize <= .xLarge, let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .fixedSize()
                    .accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

private struct PremiumArtworkBackground: View {
    let artwork: String
    let colors: [Color]
    var horizontal = false

    var body: some View {
        GeometryReader { geometry in
            Image(artwork)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                .clipped()
                .overlay {
                    LinearGradient(colors: colors,
                                   startPoint: horizontal ? .leading : .top,
                                   endPoint: horizontal ? .trailing : .bottom)
                }
        }
        .background(PremiumStyle.navy)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func premiumSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(PremiumStyle.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(PremiumStyle.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
