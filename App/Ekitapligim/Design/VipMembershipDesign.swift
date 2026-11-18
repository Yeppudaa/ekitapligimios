import SwiftUI
import EkitapligimCore

/// VIP Premium presentation shared by profiles, member pages and community surfaces.
/// Mirrors the Android `VipMembershipVisuals` palette and night-library artwork.
enum VipStyle {
    static let night = Color(hex: 0x11132D)
    static let deep = Color(hex: 0x0B0C22)
    static let mint = Color(hex: 0xA4F4F2)
    static let lilac = Color(hex: 0xD7BCFF)
    static let violet = Color(hex: 0xAC83F4)
    static let ink = Color(hex: 0x40305E)
    static let mist = Color(hex: 0xEBE4FA)
    static let rimLight = Color(hex: 0xF4EDFF)
    static let heroBorder = LinearGradient(
        colors: [Color(hex: 0x8C6BD6), mint.opacity(0.75), Color(hex: 0x5B4A9A), lilac],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let name = LinearGradient(colors: [.white, Color(hex: 0xEBDDFF), mint],
        startPoint: .leading, endPoint: .trailing)
    static let artwork = "vip_night_library"
}

/// The octagonal VIP portrait shape.
struct VipOctagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.28, y: y))
        path.addLine(to: CGPoint(x: x + w * 0.72, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y + h * 0.28))
        path.addLine(to: CGPoint(x: x + w, y: y + h * 0.72))
        path.addLine(to: CGPoint(x: x + w * 0.72, y: y + h))
        path.addLine(to: CGPoint(x: x + w * 0.28, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h * 0.72))
        path.addLine(to: CGPoint(x: x, y: y + h * 0.28))
        path.closeSubpath()
        return path
    }
}

/// Octagonal VIP frame whose rim carries a slow light sweep. The sweep stops with Reduce Motion,
/// in the background and off screen, exactly like the Premium gold frame.
struct VipAvatarFrame<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    let size: CGFloat
    var showsSeal = false
    private let content: (CGFloat) -> Content

    init(size: CGFloat, showsSeal: Bool = false, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.size = size
        self.showsSeal = showsSeal
        self.content = content
    }

    private var rimWidth: CGFloat { showsSeal ? 4 : max(1.6, size * 0.045) }
    private var gap: CGFloat { showsSeal ? 3 : 1 }

    private var running: Bool {
        showsSeal && PremiumAvatarAppearance.animates(isPremium: true, reduceMotion: reduceMotion,
            sceneActive: scenePhase == .active, visible: visible)
    }

    var body: some View {
        ZStack {
            Group {
                if running {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        rim(phase: PremiumAvatarAppearance.phase(elapsed: timeline.date.timeIntervalSinceReferenceDate,
                                                                   duration: 4.2))
                    }
                } else {
                    rim(phase: PremiumAvatarAppearance.restingPhase)
                }
            }
            .accessibilityHidden(true)
            let inner = size - (rimWidth + gap) * 2
            VipOctagon().fill(VipStyle.night)
                .frame(width: size - rimWidth * 2, height: size - rimWidth * 2)
            content(inner)
                .frame(width: inner, height: inner)
                .clipShape(VipOctagon())
            if showsSeal {
                Image(systemName: "book.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VipStyle.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VipStyle.night, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(VipStyle.mint, lineWidth: 1) }
                    .offset(y: size / 2 + 2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VipL10n.text("vipFrame"))
        .accessibilityIdentifier("vip.avatar.frame")
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }

    /// A wide band of light travels diagonally across the rim once per cycle.
    private func rim(phase: Double) -> some View {
        let offset = -1.0 + 2.0 * phase
        return VipOctagon()
            .fill(LinearGradient(stops: [
                .init(color: VipStyle.violet, location: 0),
                .init(color: VipStyle.mint, location: 0.25),
                .init(color: VipStyle.rimLight, location: 0.5),
                .init(color: VipStyle.violet, location: 0.75),
                .init(color: VipStyle.mint, location: 1)
            ], startPoint: UnitPoint(x: offset, y: 0), endPoint: UnitPoint(x: offset + 2, y: 1)))
            .frame(width: size, height: size)
    }
}

/// Avatar for community lists: VIP octagon, Premium gold ring or the plain circle.
struct MembershipAvatar: View {
    let tier: MembershipTier
    let urlString: String?
    let username: String
    var size: CGFloat = 44
    var background: Color = EKitapligimPalette.tealSoft
    var foreground: Color = EKitapligimPalette.teal

    var body: some View {
        switch tier {
        case .vip:
            VipAvatarFrame(size: size) { diameter in
                EKAvatar(urlString: urlString, username: username, size: diameter, cornerRadius: 0,
                         background: Color(hex: 0x2C2954), foreground: VipStyle.mint)
            }
        case .premium:
            EKAvatar(urlString: urlString, username: username, size: size - 9,
                     background: background, foreground: foreground)
                .padding(3)
                .overlay { Circle().strokeBorder(Color(hex: 0xC29347), lineWidth: 1.5) }
                .frame(width: size, height: size)
                .accessibilityLabel(username)
                .accessibilityValue(L10n.profileRolePremiumMember)
        case .member:
            EKAvatar(urlString: urlString, username: username, size: size,
                     background: background, foreground: foreground)
        }
    }
}

/// Name with the Android tier emoji (👑 Premium, 💎 VIP) and a lilac tint for VIP members.
struct MembershipName: View {
    let username: String
    let tier: MembershipTier
    var baseColor: Color = EKitapligimPalette.ink

    var body: some View {
        Text(tier.namePrefix + username)
            .foregroundStyle(tier == .vip ? Color(hex: 0x6A4BB0) : baseColor)
            .accessibilityLabel(username)
            .accessibilityValue(tier == .vip ? VipL10n.text("vipMember")
                : (tier == .premium ? L10n.profileRolePremiumMember : ""))
    }
}

/// Small "💎 VIP PREMIUM" capsule.
struct VipBadge: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            Text(MembershipTier.vip.emoji).font(compact ? Font.caption2 : Font.subheadline)
            Text(VipL10n.text("vipBadge"))
                .font((compact ? Font.caption2 : Font.caption).weight(.bold))
                .tracking(compact ? 1 : 2.2)
                .foregroundStyle(Color(hex: 0xF3EBFF))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, compact ? 8 : 14)
        .padding(.vertical, compact ? 3 : 6)
        .background(VipStyle.deep.opacity(0.72), in: Capsule())
        .overlay {
            Capsule().strokeBorder(LinearGradient(colors: [VipStyle.lilac, VipStyle.mint, VipStyle.lilac],
                startPoint: .leading, endPoint: .trailing), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VipL10n.text("vipMember"))
    }
}

/// VIP profile hero: the full night library above its reflection in a night lake, the portrait
/// resting on the water line, a glowing name and an ornament. Same composition as Android.
struct VipProfileHero<Footer: View>: View {
    let displayName: String
    let avatarUrl: String?
    var bannerUrl: String? = nil
    var detail: String? = nil
    @ViewBuilder var footer: () -> Footer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.58, 1.4), (0.17, 0.74, 1), (0.9, 0.6, 1.6), (0.83, 0.79, 1),
        (0.06, 0.9, 1.2), (0.94, 0.93, 1.3), (0.27, 0.95, 0.9), (0.73, 0.97, 1),
        (0.12, 0.1, 1.1), (0.04, 0.3, 0.9), (0.96, 0.2, 1)
    ]

    private var avatarSize: CGFloat { horizontalSizeClass == .compact ? 112 : 124 }
    private var haloSize: CGFloat { avatarSize + 56 }

    private var secureBannerURL: URL? {
        guard let bannerUrl, !bannerUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: bannerUrl), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    var body: some View {
        VStack(spacing: 0) {
            // Reserves exactly the 3:2 cover height for the current width.
            Color.clear.aspectRatio(1.5, contentMode: .fit)
            content.padding(.top, -(haloSize / 2) + 4)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) { scenery }
        .overlay { starField }
        .background(VipStyle.night)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(VipStyle.heroBorder, lineWidth: 1.2)
                .allowsHitTesting(false)
        }
        .shadow(color: VipStyle.violet.opacity(0.35), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vip.profile.hero")
    }

    private var content: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [VipStyle.violet.opacity(0.55), VipStyle.mint.opacity(0.18), .clear],
                                         center: .center, startRadius: 0, endRadius: haloSize / 2))
                    .frame(width: haloSize, height: haloSize)
                    .accessibilityHidden(true)
                VipAvatarFrame(size: avatarSize, showsSeal: true) { diameter in
                    EKAvatar(urlString: avatarUrl, username: displayName, size: diameter, cornerRadius: 0,
                             background: Color(hex: 0x3A2E6E), foreground: VipStyle.mint)
                }
            }
            .frame(width: haloSize, height: haloSize)
            VipBadge().padding(.top, 2)
            Text(displayName)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(VipStyle.name)
                .shadow(color: VipStyle.violet.opacity(0.75), radius: 11, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("profile.username")
            ornament.padding(.top, 10)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(VipStyle.lilac.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            VStack(spacing: 4) { footer() }
                .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }

    private var ornament: some View {
        HStack(spacing: 10) {
            LinearGradient(colors: [.clear, VipStyle.lilac], startPoint: .leading, endPoint: .trailing)
                .frame(width: 54, height: 1)
            Text("✦").font(.footnote).foregroundStyle(VipStyle.mint)
            LinearGradient(colors: [VipStyle.lilac, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 54, height: 1)
        }
        .accessibilityHidden(true)
    }

    /// The picture keeps its own 3:2 frame; its mirrored copy fills the card below it.
    /// Heights come from the measured width so the artwork always lines up with the content.
    private var scenery: some View {
        GeometryReader { geometry in
            let height = geometry.size.width / 1.5
            VStack(spacing: 0) {
                sceneryLayers(height: height)
            }
            .frame(width: geometry.size.width, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func sceneryLayers(height: CGFloat) -> some View {
            artwork
                .frame(height: height)
                .overlay {
                    LinearGradient(stops: [
                        .init(color: VipStyle.deep.opacity(0.3), location: 0),
                        .init(color: .clear, location: 0.18),
                        .init(color: .clear, location: 0.82),
                        .init(color: VipStyle.night.opacity(0.3), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, VipStyle.mint.opacity(0.35), VipStyle.lilac.opacity(0.5),
                                            VipStyle.mint.opacity(0.35), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(height: 1)
                        .padding(.horizontal, 36)
                }
            artwork
                .frame(height: height)
                .scaleEffect(x: 1, y: -1)
                .opacity(0.42)
                .overlay {
                    LinearGradient(stops: [
                        .init(color: VipStyle.night.opacity(0.25), location: 0),
                        .init(color: VipStyle.night.opacity(0.72), location: 0.45),
                        .init(color: VipStyle.night, location: 0.8)
                    ], startPoint: .top, endPoint: .bottom)
                }
    }

    private var artwork: some View {
        Color.clear
            .overlay {
                if let url = secureBannerURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Image(VipStyle.artwork).resizable().scaledToFill()
                        }
                    }
                } else {
                    Image(VipStyle.artwork).resizable().scaledToFill()
                }
            }
            .clipped()
    }

    private var starField: some View {
        Canvas { context, size in
            for (x, y, r) in Self.stars {
                let center = CGPoint(x: size.width * x, y: size.height * y)
                let glow = r * 5
                context.fill(Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
                             with: .radialGradient(Gradient(colors: [VipStyle.mint.opacity(0.45), .clear]),
                                                   center: center, startRadius: 0, endRadius: glow))
                let dot = r * 0.7
                context.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                             with: .color(.white.opacity(0.95)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension VipProfileHero where Footer == EmptyView {
    init(displayName: String, avatarUrl: String?, bannerUrl: String? = nil, detail: String? = nil) {
        self.init(displayName: displayName, avatarUrl: avatarUrl, bannerUrl: bannerUrl, detail: detail) { EmptyView() }
    }
}

/// VIP Premium offer on the Premium screen. The button exists only when the App Store returned
/// a price and the server confirmed it can grant VIP; otherwise an explanation is shown.
struct VipPremiumCard: View {
    let isActive: Bool
    let price: String?
    let isSignedIn: Bool
    let isPurchasable: Bool
    let isBusy: Bool
    let onPurchase: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 16) {
                quotas
                Text(VipL10n.text("vipPerks"))
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0xEDE7FB))
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Color(hex: 0x534E78)).frame(height: 1).accessibilityHidden(true)
                purchaseArea
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x242043), VipStyle.night, Color(hex: 0x0D1F32)],
                                   startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(hex: 0x534E78), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("premium.vip.card")
    }

    @ViewBuilder private var header: some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                ZStack(alignment: .leading) {
                    Image(VipStyle.artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 310, maxWidth: .infinity, minHeight: 190, maxHeight: 190)
                        .clipped()
                        .overlay {
                            LinearGradient(colors: [Color(hex: 0x211D3F), Color(hex: 0x211D3F).opacity(0.92), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                        }
                        .overlay {
                            LinearGradient(colors: [.clear, .clear, VipStyle.night], startPoint: .top, endPoint: .bottom)
                        }
                        .accessibilityHidden(true)
                    title.frame(width: 210, alignment: .leading).padding(20)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Image(VipStyle.artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 144, maxHeight: 144)
                    .clipped()
                    .accessibilityHidden(true)
                title.padding(.horizontal, 18).padding(.vertical, 14)
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(VipL10n.text("vipEyebrow"), systemImage: "diamond.fill")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(VipStyle.mint)
            Text(VipL10n.text("vipTitle"))
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(Color(hex: 0xF8F3FF))
                .accessibilityAddTraits(.isHeader)
            Text(VipL10n.text("vipSubtitle"))
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0xDCD3F2))
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var quotas: some View {
        let layout = dynamicTypeSize > .xLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            quota("50", VipL10n.text("vipDailyDownloads"), tint: VipStyle.mint)
            quota("20", VipL10n.text("vipMonthlyRequests"), tint: VipStyle.lilac)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func quota(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0xEDE7FB))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(hex: 0x23223F), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0x4A4670), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var purchaseArea: some View {
        if isActive {
            Label(VipL10n.text("vipActive"), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(VipStyle.mint)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("premium.vip.active")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if let price, isPurchasable {
                    Text(price)
                        .font(.system(.title, design: .serif).weight(.bold))
                        .foregroundStyle(.white)
                }
                Text(VipL10n.text("vipTerms"))
                    .font(.caption)
                    .foregroundStyle(VipStyle.lilac)
            }
            if isPurchasable, price != nil, isSignedIn {
                Button(action: onPurchase) {
                    PremiumActionLabel(title: VipL10n.text("vipBuy"), trailingSystemImage: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VipStyle.night)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .frame(minHeight: 50)
                        .background(isBusy ? Color(hex: 0x333450) : VipStyle.mint,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PremiumPressStyle())
                .disabled(isBusy)
                .accessibilityIdentifier("premium.vip.buy")
            } else {
                Text(isSignedIn ? VipL10n.text("vipUnavailable") : VipL10n.text("vipSignIn"))
                    .font(.footnote)
                    .foregroundStyle(Color(hex: 0xDFD8F0))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("premium.vip.unavailable")
            }
        }
    }
}
