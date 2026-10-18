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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var storeKit: StoreKitPurchaseService
    let subscription: SubscriptionDTO?
    let isSignedIn: Bool
    let termsURL: URL
    let privacyURL: URL
    @State private var isManagingSubscriptions = false
    @State private var operationErrorMessage: String?
    @State private var operationErrorTitle = L10n.premiumPurchaseFailed

    private var hasPremium: Bool {
        subscription?.isPremium == true || storeKit.entitlement.isActive
    }

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        PremiumHeroCard(membershipStatus: hasPremium ? statusTitle : nil) {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                                proxy.scrollTo("premium.plans", anchor: .top)
                            }
                        }
                        benefitsSection(availableWidth: min(600, max(0, geometry.size.width - 32)))
                        statusSection
                        productsSection.id("premium.plans")
                        operationSection
                        actionsSection
                        legalSection
                    }
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
                .background(PremiumStyle.page)
            }
        }
        .foregroundStyle(PremiumStyle.ink)
        .multilineTextAlignment(.leading)
        .tint(PremiumStyle.accent)
        .navigationTitle(L10n.premiumTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PremiumStyle.page, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .manageSubscriptionsSheet(isPresented: $isManagingSubscriptions)
        .alert(operationErrorTitle, isPresented: Binding(
            get: { operationErrorMessage != nil },
            set: { if !$0 { operationErrorMessage = nil } }
        )) {
            Button(L10n.commonClose, role: .cancel) { operationErrorMessage = nil }
        } message: {
            Text(operationErrorMessage ?? L10n.premiumPurchaseFailed)
        }
        .confirmationDialog(L10n.premiumPurchaseNoticeTitle, isPresented: Binding(
            get: { storeKit.purchaseNotice != nil },
            set: { if !$0 { storeKit.dismissPurchaseNotice() } }
        ), titleVisibility: .visible, presenting: storeKit.purchaseNotice) { notice in
            Button(L10n.premiumManageSubscriptions) {
                storeKit.dismissPurchaseNotice()
                isManagingSubscriptions = true
            }
            Button(L10n.premiumContinuePurchase) {
                Task {
                    await storeKit.confirmPurchase(notice)
                    if case .failed(let message) = storeKit.state {
                        operationErrorTitle = L10n.premiumPurchaseFailed
                        operationErrorMessage = message
                    }
                }
            }
            Button(L10n.commonClose, role: .cancel) { storeKit.dismissPurchaseNotice() }
        } message: { notice in
            Text(notice.message)
        }
        .task { await storeKit.prepare() }
        .preference(key: AILauncherHiddenKey.self, value: true)
    }

    private func benefitsSection(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PremiumSectionHeading(title: L10n.premiumBenefitsTitle, subtitle: PremiumDesignL10n.text("benefits.subtitle"))
            PremiumAudioBenefitCard()
            PremiumQuotaCards(availableWidth: availableWidth)
            PremiumExtraBenefitsCard()
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
        VStack(alignment: .leading, spacing: 12) {
            PremiumSectionHeading(title: L10n.premiumPlans, subtitle: PremiumDesignL10n.text("plans.subtitle"))
            if storeKit.products.isEmpty {
                if case .loading = storeKit.state {
                    ProgressView(L10n.premiumLoading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .premiumSurface()
                } else {
                    PremiumNotice(message: L10n.premiumProductsFailed, systemImage: "info.circle", tone: PremiumStyle.muted)
                }
            } else {
                ForEach(storeKit.products) { product in
                    Button {
                        Task {
                            await storeKit.purchase(productID: product.id)
                            if case .failed(let message) = storeKit.state {
                                operationErrorTitle = L10n.premiumPurchaseFailed
                                operationErrorMessage = message
                            }
                        }
                    } label: {
                        PremiumPlanCard(
                            name: product.displayName,
                            price: product.displayPrice,
                            period: PremiumProductCatalog.period(for: product.id),
                            tagline: PremiumProductCatalog.tagline(for: product.id),
                            isYearly: PremiumProductCatalog.subscriptionMonths(for: product.id) == 12
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
                .fixedSize(horizontal: false, vertical: true)
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
                Button {
                    Task {
                        await storeKit.restore()
                        if case .failed(let message) = storeKit.state {
                            operationErrorTitle = L10n.premiumRestoreFailed
                            operationErrorMessage = message
                        }
                    }
                } label: {
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
        PremiumActionLabel(title: title, systemImage: systemImage, trailingSystemImage: "chevron.right")
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
        PurchaseOfferPolicy.displayedExpiration(entitlement: storeKit.entitlement, serverExpiration: subscription?.expirationTime)
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

struct PremiumPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled && configuration.isPressed ? 0.85 : 1)
    }
}
