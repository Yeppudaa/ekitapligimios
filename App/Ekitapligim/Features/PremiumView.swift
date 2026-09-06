import SwiftUI
import StoreKit
import EkitapligimCore

@MainActor
struct PremiumView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        EKitapligimScreen {
            PremiumContentView(
                storeKit: container.storeKit,
                subscription: container.subscription,
                isSignedIn: container.isSignedIn,
                termsURL: container.config.termsURL,
                privacyURL: container.config.privacyPolicyURL
            )
        }
    }
}

@MainActor
private struct PremiumContentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var storeKit: StoreKitPurchaseService
    let subscription: SubscriptionDTO?
    let isSignedIn: Bool
    let termsURL: URL
    let privacyURL: URL
    @State private var isManagingSubscriptions = false

    private var hasPremium: Bool {
        subscription?.isPremium == true || storeKit.entitlement.isActive
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection
                    benefitsSection(compact: geometry.size.width < 400 || dynamicTypeSize > .large)
                    statusSection
                    productsSection
                    operationSection
                    actionsSection
                    legalSection
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .background(PremiumStyle.page)
        }
        .foregroundStyle(PremiumStyle.ink)
        .tint(PremiumStyle.accent)
        .navigationTitle(L10n.premiumTitle)
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $isManagingSubscriptions)
        .task { await storeKit.prepare() }
        .preference(key: AILauncherHiddenKey.self, value: true)
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PremiumStyle.ink)
                .frame(width: 68, height: 68)
                .background {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0xFAEBC6), PremiumStyle.gold, Color(hex: 0xC39B53)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay {
                            RoundedRectangle(cornerRadius: 23, style: .continuous)
                                .strokeBorder(.white.opacity(0.65), lineWidth: 1)
                        }
                }
                .shadow(color: PremiumStyle.accent.opacity(0.12), radius: 12, y: 6)
                .accessibilityHidden(true)

            Text(L10n.premiumEyebrow)
                .font(.caption2.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(PremiumStyle.accent)

            Text(L10n.premiumTitle)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            Capsule()
                .fill(PremiumStyle.accent.opacity(0.7))
                .frame(width: 36, height: 2)
                .accessibilityHidden(true)

            Text(L10n.premiumHeroSubtitle)
                .font(.subheadline)
                .foregroundStyle(PremiumStyle.muted)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xFFFCF5), Color(hex: 0xF5EAD4), Color(hex: 0xF0DFBE)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay { PremiumHeroOrbits() }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(PremiumStyle.goldBorder, lineWidth: 1)
                }
        }
        .accessibilityIdentifier("premium.hero")
    }

    private func benefitsSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(L10n.premiumBenefitsTitle)
            let layout = compact
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                PremiumBenefitCard(
                    title: L10n.premiumReadingTitle,
                    message: L10n.premiumBenefitReading,
                    systemImage: "book.closed.fill"
                )
                PremiumBenefitCard(
                    title: L10n.premiumDownloadsTitle,
                    message: L10n.premiumBenefitDownloads,
                    systemImage: "arrow.down.circle.fill"
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(L10n.premiumDescription)
                .font(.footnote)
                .foregroundStyle(PremiumStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if hasPremium || storeKit.entitlement.renewalState != .none {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading(L10n.premiumMembershipStatus)
                Label(statusTitle, systemImage: statusIcon)
                    .font(.headline)
                    .foregroundStyle(hasPremium ? PremiumStyle.success : PremiumStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let expiration = effectiveExpiration {
                    Text(L10n.premiumValidUntil(Self.dateFormatter.string(from: expiration)))
                        .font(.subheadline)
                        .foregroundStyle(PremiumStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let planName = subscription?.planName, !planName.isEmpty {
                    premiumDivider
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.premiumPlan)
                            .font(.caption)
                            .foregroundStyle(PremiumStyle.muted)
                        Text(planName).font(.subheadline.weight(.semibold))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(22)
            .premiumSurface()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("premium.membership")
        }
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(L10n.premiumPlans)
            if storeKit.products.isEmpty {
                if case .loading = storeKit.state {
                    ProgressView(L10n.premiumLoading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .premiumSurface()
                } else {
                    PremiumNotice(message: L10n.premiumProductsFailed, systemImage: "info.circle", tone: PremiumStyle.muted)
                }
            } else {
                ForEach(storeKit.products) { product in
                    Button {
                        Task { await storeKit.purchase(productID: product.id) }
                    } label: {
                        PremiumPlanCard(
                            name: product.displayName,
                            price: product.displayPrice,
                            period: product.id.hasSuffix("yearly") ? L10n.premiumYearlyPeriod : L10n.premiumMonthlyPeriod
                        )
                    }
                    .buttonStyle(PremiumPressStyle())
                    .disabled(!isSignedIn || isBusy)
                    .accessibilityIdentifier("premium.product.\(product.id)")
                }
            }
            if !isSignedIn {
                PremiumNotice(
                    message: L10n.premiumLoginRequired,
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    tone: PremiumStyle.muted
                )
            }
        }
    }

    @ViewBuilder
    private var operationSection: some View {
        switch storeKit.state {
        case .purchasing:
            ProgressView(L10n.premiumPurchasing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .premiumSurface()
        case .purchased:
            PremiumNotice(message: L10n.premiumPurchased, systemImage: "checkmark.seal.fill", tone: PremiumStyle.success)
        case .restored:
            PremiumNotice(message: L10n.premiumRestored, systemImage: "checkmark.circle.fill", tone: PremiumStyle.success)
        case .pending:
            PremiumNotice(message: L10n.premiumPending, systemImage: "clock", tone: PremiumStyle.muted)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(PremiumStyle.danger)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Task { await storeKit.prepare() } } label: {
                    actionLabel(L10n.commonRetry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(PremiumPressStyle())
            }
            .padding(22)
            .premiumSurface()
        case .notLoaded, .loading, .available:
            EmptyView()
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                Button { Task { await storeKit.restore() } } label: {
                    actionLabel(L10n.premiumRestore, systemImage: "arrow.clockwise")
                }
                .disabled(!isSignedIn || isBusy)
                .accessibilityIdentifier("premium.restore")
                premiumDivider
                Button { isManagingSubscriptions = true } label: {
                    actionLabel(L10n.premiumManageSubscriptions, systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("premium.manage")
            }
            .buttonStyle(PremiumPressStyle())
            .padding(.horizontal, 18)
            .premiumSurface()
            Text(L10n.premiumCancellationNote)
                .font(.footnote)
                .foregroundStyle(PremiumStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(L10n.settingsLegalSection)
            VStack(spacing: 0) {
                Link(destination: termsURL) {
                    actionLabel(L10n.settingsTerms, systemImage: "doc.text")
                }
                premiumDivider
                Link(destination: privacyURL) {
                    actionLabel(L10n.settingsPrivacyPolicy, systemImage: "hand.raised")
                }
            }
            .buttonStyle(PremiumPressStyle())
            .padding(.horizontal, 18)
            .premiumSurface()
            Text(L10n.premiumRenewalDisclosure)
                .font(.footnote)
                .foregroundStyle(PremiumStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var premiumDivider: some View {
        Rectangle()
            .fill(PremiumStyle.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PremiumStyle.accent)
        .multilineTextAlignment(.leading)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var isBusy: Bool {
        switch storeKit.state {
        case .loading, .purchasing: true
        default: false
        }
    }

    private var effectiveExpiration: Date? {
        storeKit.entitlement.expiration
            ?? subscription.flatMap { $0.expirationTime > 0 ? Date(timeIntervalSince1970: TimeInterval($0.expirationTime)) : nil }
    }

    private var statusTitle: String {
        switch storeKit.entitlement.renewalState {
        case .cancelled: L10n.premiumStatusCancelled
        case .gracePeriod: L10n.premiumStatusGracePeriod
        case .billingRetry: L10n.premiumStatusBillingRetry
        case .expired: L10n.premiumStatusExpired
        case .revoked: L10n.premiumStatusRevoked
        case .none, .active: hasPremium ? L10n.premiumStatusActive : L10n.premiumStatusExpired
        }
    }

    private var statusIcon: String {
        hasPremium ? "checkmark.seal.fill" : "xmark.seal"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

// Presentation is local to this screen; the shared app theme and purchase service stay independent.
private enum PremiumStyle {
    static let page = Color(hex: 0xF8F6F1)
    static let surface = Color(hex: 0xFFFEFB)
    static let ink = Color(hex: 0x101E36)
    static let muted = Color(hex: 0x566171)
    static let accent = Color(hex: 0x78551A)
    static let gold = Color(hex: 0xE8C77D)
    static let goldBorder = Color(hex: 0xE3CFAB)
    static let border = Color(hex: 0xE3E2DD)
    static let success = Color(hex: 0x216A50)
    static let danger = Color(hex: 0xB3261E)
}

private struct PremiumHeroOrbits: View {
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width * 0.95, y: geometry.size.height * 0.08)
            Path { path in
                for scale in [0.46, 0.65, 0.84] {
                    let radius = geometry.size.width * scale
                    path.addEllipse(in: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    ))
                }
            }
            .stroke(PremiumStyle.accent.opacity(0.10), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PremiumBenefitCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(PremiumStyle.accent)
                .frame(width: 44, height: 44)
                .background(PremiumStyle.gold.opacity(0.20), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PremiumStyle.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .premiumSurface()
        .accessibilityElement(children: .combine)
    }
}

private struct PremiumPlanCard: View {
    let name: String
    let price: String
    let period: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text(name)
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "crown.fill")
                    .font(.subheadline)
                    .foregroundStyle(PremiumStyle.accent)
                    .padding(10)
                    .background(PremiumStyle.gold.opacity(0.20), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
            }
            Text(price)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            Text(period)
                .font(.subheadline)
                .foregroundStyle(PremiumStyle.muted)
            Rectangle()
                .fill(PremiumStyle.goldBorder.opacity(0.65))
                .frame(height: 1)
                .accessibilityHidden(true)
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .accessibilityHidden(true)
                Text(L10n.premiumPurchaseAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 48)
            .background(PremiumStyle.gold.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(PremiumStyle.ink)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(22)
        .premiumSurface(border: PremiumStyle.goldBorder)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PremiumNotice: View {
    let message: String
    let systemImage: String
    let tone: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tone)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .premiumSurface()
            .accessibilityElement(children: .combine)
    }
}

private struct PremiumPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.50)
    }
}

private extension View {
    func premiumSurface(border: Color = PremiumStyle.border) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(PremiumStyle.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: PremiumStyle.ink.opacity(0.025), radius: 12, y: 5)
    }
}
