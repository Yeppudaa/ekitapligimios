import SwiftUI
import EkitapligimCore

enum EKitapligimPalette {
    static let page = Color(red: 250 / 255, green: 252 / 255, blue: 252 / 255)
    static let paper = Color.white
    static let ink = Color(red: 16 / 255, green: 33 / 255, blue: 47 / 255)
    static let muted = Color(red: 114 / 255, green: 128 / 255, blue: 142 / 255)
    static let teal = Color(red: 7 / 255, green: 134 / 255, blue: 139 / 255)
    static let tealDark = Color(red: 0 / 255, green: 110 / 255, blue: 115 / 255)
    static let tealSoft = Color(red: 232 / 255, green: 247 / 255, blue: 247 / 255)
    static let cream = Color(red: 255 / 255, green: 248 / 255, blue: 234 / 255)
    static let amber = Color(red: 224 / 255, green: 154 / 255, blue: 18 / 255)
    static let amberSoft = Color(red: 255 / 255, green: 243 / 255, blue: 214 / 255)
    static let border = Color(red: 226 / 255, green: 232 / 255, blue: 234 / 255)
    static let surfaceAlt = Color(hex: 0xF4F8F9)
    static let success = Color(hex: 0x16847B)
    static let gold = Color(hex: 0xE09A12)

    static let pageGradient = LinearGradient(
        colors: [Color(red: 252 / 255, green: 254 / 255, blue: 254 / 255),
                 Color(red: 242 / 255, green: 250 / 255, blue: 250 / 255),
                 Color(red: 255 / 255, green: 251 / 255, blue: 242 / 255),
                 .white],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Profil

    static let profileInk = Color(hex: 0x172033)
    static let profileMuted = Color(hex: 0x687A80)
    static let profileTeal = Color(hex: 0x0E7C86)
    static let profileTealDeep = Color(hex: 0x0D747C)
    static let profileTealSoft = Color(hex: 0xEFF8FA)
    static let profileBorder = Color(hex: 0xDDE8EA)
    static let profileSurface = Color(hex: 0xF7FAFA)
    static let profileGold = Color(hex: 0xFFD06B)
    static let profileGoldDeep = Color(hex: 0x9A6900)
    static let profileSuccess = Color(hex: 0x16847B)

    static let profileHeroGradient = LinearGradient(
        colors: [Color(hex: 0x0B343B), Color(hex: 0x0E5960), Color(hex: 0x163D45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let profileBannerGradient = LinearGradient(
        colors: [Color(hex: 0x082A31), Color(hex: 0x136A70), Color(hex: 0x244954)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let quotaAdminGradient = LinearGradient(
        colors: [Color(hex: 0x264F73), Color(hex: 0x65A3BF)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let quotaPremiumGradient = LinearGradient(
        colors: [Color(hex: 0x5E4A7D), Color(hex: 0xD49D77)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let quotaReadGradient = LinearGradient(
        colors: [Color(hex: 0x1A776D), Color(hex: 0x79C6A5)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let quotaDownloadGradient = LinearGradient(
        colors: [Color(hex: 0x2D5E8A), Color(hex: 0x64B6C7)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: Kitap Gündemi

    static let agendaInk = Color(hex: 0x14212D)
    static let agendaMuted = Color(hex: 0x687685)
    static let agendaTeal = Color(hex: 0x078C90)
    static let agendaPurple = Color(hex: 0x6D4AFF)
    static let agendaPurpleSoft = Color(hex: 0xF2EEFF)
    static let agendaQuoteBackground = Color(hex: 0xF8F6FF)
    static let agendaQuoteBorder = Color(hex: 0xDDD5FF)
    static let agendaGold = Color(hex: 0xE19A11)
    static let agendaGreen = Color(hex: 0x27875F)
    static let agendaSurface = Color(hex: 0xF5F7FA)
    static let agendaBorder = Color(hex: 0xE0E6EC)
    static let agendaChipSelected = Color(hex: 0xEDE8FF)

    // MARK: Okur Sohbeti

    static let chatInk = Color(hex: 0x10212F)
    static let chatMuted = Color(hex: 0x667784)
    static let chatTeal = Color(hex: 0x07868B)
    static let chatTealSoft = Color(hex: 0xE8F7F7)
    static let chatAmber = Color(hex: 0xE19A18)
    static let chatBorder = Color(hex: 0xE1E8EA)
    static let chatSurface = Color(hex: 0xF5F8F9)
    static let chatBotBubble = Color(hex: 0xFFF8E9)
    static let chatAnnouncement = Color(hex: 0xFFF6DF)
    static let chatAnnouncementBorder = Color(hex: 0xF0D69C)
    static let chatAnnouncementInk = Color(hex: 0x76520E)

    // MARK: Canlı Aktivite

    static let liveSurface = Color(hex: 0xF6F8FB)
    static let liveBorder = Color(hex: 0xE1E7EC)
    static let liveBadgeBackground = Color(hex: 0xE8FBF4)
    static let liveBadgeBorder = Color(hex: 0xBFEBD9)
    static let liveBadgeInk = Color(hex: 0x08734E)
    static let liveDot = Color(hex: 0x21C786)
    static let liveRed = Color(hex: 0xD64545)
    static let liveOrange = Color(hex: 0xE8874A)

    // MARK: Ortak durumlar

    static let warningBackground = Color(hex: 0xFFF7E8)
    static let warningBorder = Color(hex: 0xEBD39F)
    static let warningInk = Color(hex: 0x75540E)
    static let successSoft = Color(hex: 0xE8F7F1)
    static let successInk = Color(hex: 0x16705D)
    static let danger = Color(hex: 0xB3261E)

    // MARK: Forum

    static let forumInk = Color(hex: 0x0E1B2B)
    static let forumMuted = Color(hex: 0x687385)
    static let forumTeal = Color(hex: 0x087A80)
    static let forumTealDeep = Color(hex: 0x06656A)
    static let forumTealSoft = Color(hex: 0xEDF7F5)
    static let forumGold = Color(hex: 0xCF8A18)
    static let forumGoldSoft = Color(hex: 0xF7F4EA)
    static let forumBorder = Color(hex: 0xE1ECEA)
    static let forumDivider = Color(hex: 0xE9D9BA)
    static let forumBlue = Color(hex: 0x3D75C5)
    static let forumBlueSoft = Color(hex: 0xEEF4FF)
    static let forumSurface = Color(hex: 0xFFFCF4)

    static let forumPageGradient = LinearGradient(
        colors: [Color(hex: 0xFFFCF4), Color(hex: 0xFAF6EC), Color(hex: 0xF5FBFA), .white],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct EKitapligimPageBackground: View {
    var body: some View {
        EKitapligimPalette.pageGradient
            .ignoresSafeArea()
    }
}

/// Shared light-theme chrome matching the Android app shell.
enum EKitapligimAppearance {
    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 251 / 255, green: 254 / 255, blue: 254 / 255, alpha: 1)
        nav.shadowColor = UIColor(red: 226 / 255, green: 232 / 255, blue: 234 / 255, alpha: 1)
        nav.titleTextAttributes = [.foregroundColor: UIColor(red: 16 / 255, green: 33 / 255, blue: 47 / 255, alpha: 1)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 16 / 255, green: 33 / 255, blue: 47 / 255, alpha: 1)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }
}

/// Standard page wrapper: gradient background behind all content screens.
struct EKitapligimScreen<Content: View>: View {
    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            content()
        }
    }
}

struct EKLoadingState: View {
    var message: String = L10n.commonLoading

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(EKitapligimPalette.teal)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EKEmptyState: View {
    let title: String
    var message: String?
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: message.map(Text.init))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EKErrorState: View {
    let title: String
    var message: String?
    var retryTitle: String = L10n.commonRetry
    var retry: (() -> Void)?

    var body: some View {
        if let retry {
            EKStateCard(title: title, message: message ?? "", retryTitle: retryTitle, retry: retry)
                .padding(.horizontal, 18)
        } else {
            EKEmptyState(title: title, message: message, systemImage: "exclamationmark.triangle")
        }
    }
}

struct EKitapligimBrandLogo: View {
    var body: some View {
        Image("EKitapligimWideLogo")
            .resizable()
            .scaledToFit()
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(EKitapligimPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 240 / 255, green: 223 / 255, blue: 194 / 255))
            }
            .accessibilityLabel("E-Kitaplığım")
    }
}

struct EKitapligimSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
            }
        }
    }
}

struct EKitapligimRemoteCover: View {
    let urlString: String
    var accessibilityTitle: String? = nil

    var body: some View {
        Group {
            if let url = secureURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .empty: ProgressView().tint(EKitapligimPalette.teal)
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EKitapligimPalette.tealSoft)
        .clipped()
        .accessibilityLabel(coverAccessibilityLabel ?? "")
        .accessibilityHidden(coverAccessibilityLabel == nil)
    }

    private var coverAccessibilityLabel: String? {
        guard let accessibilityTitle, !accessibilityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              secureURL != nil else { return nil }
        return L10n.libraryCoverAccessibility(accessibilityTitle)
    }

    private var secureURL: URL? {
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private var placeholder: some View {
        Image(systemName: "book.closed.fill")
            .font(.title2)
            .foregroundStyle(EKitapligimPalette.teal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum EKCollapsibleHeroMetrics {
    static let expandedHeight: CGFloat = 126
    static let collapsedHeight: CGFloat = 64
    static let threshold: CGFloat = 120
}

private struct EKScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct EKScrollOffsetTracker: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: EKScrollOffsetKey.self,
                value: proxy.frame(in: .named("ekCollapsibleScroll")).minY
            )
        }
        .frame(height: 0)
    }
}

struct EKCollapsibleHero<Expanded: View, Collapsed: View>: View {
    let progress: CGFloat
    var expandedHeight: CGFloat = EKCollapsibleHeroMetrics.expandedHeight
    var collapsedHeight: CGFloat = EKCollapsibleHeroMetrics.collapsedHeight
    @ViewBuilder var expanded: () -> Expanded
    @ViewBuilder var collapsed: () -> Collapsed

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        let height = expandedHeight
            - ((expandedHeight - collapsedHeight) * clamped)

        ZStack(alignment: .top) {
            expanded()
                .opacity(1 - clamped)
            collapsed()
                .opacity(clamped)
        }
        .frame(height: height, alignment: .top)
        .clipped()
        .animation(.easeOut(duration: 0.15), value: clamped)
    }
}

private struct EKitapligimCardModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(EKitapligimPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(EKitapligimPalette.border)
            }
    }
}

extension View {
    func ekitapligimCard(radius: CGFloat = 18) -> some View {
        modifier(EKitapligimCardModifier(radius: radius))
    }

    /// Applies the site gradient behind List/Form screens so dark mode never renders a black page.
    func ekitapligimScreenBackground() -> some View {
        background {
            EKitapligimPageBackground()
        }
    }

    func ekitapligimListScreen() -> some View {
        scrollContentBackground(.hidden)
            .listStyle(.plain)
            .background(.clear)
    }

    func ekCollapsibleScrollTracking(_ onProgressChange: @escaping (CGFloat) -> Void) -> some View {
        coordinateSpace(name: "ekCollapsibleScroll")
            .onPreferenceChange(EKScrollOffsetKey.self) { offset in
                let progress = min(max(-offset / EKCollapsibleHeroMetrics.threshold, 0), 1)
                onProgressChange(progress)
            }
    }
}
