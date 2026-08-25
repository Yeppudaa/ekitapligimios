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
        List {
            heroSection
            statusSection
            productsSection
            operationSection
            actionsSection
            legalSection
        }
        .ekitapligimListScreen()
        .navigationTitle(L10n.premiumTitle)
        .manageSubscriptionsSheet(isPresented: $isManagingSubscriptions)
        .task { await storeKit.prepare() }
    }

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.premiumTitle, systemImage: "crown.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.yellow)
                Text(L10n.premiumDescription)
                    .foregroundStyle(.secondary)
                Label(L10n.premiumBenefitReading, systemImage: "book.fill")
                Label(L10n.premiumBenefitDownloads, systemImage: "arrow.down.circle.fill")
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if hasPremium || storeKit.entitlement.renewalState != .none {
            Section(header: Text(L10n.premiumMembershipStatus)) {
                Label(statusTitle, systemImage: statusIcon)
                    .foregroundStyle(hasPremium ? .green : .secondary)
                if let expiration = effectiveExpiration {
                    Text(L10n.premiumValidUntil(Self.dateFormatter.string(from: expiration)))
                        .foregroundStyle(.secondary)
                }
                if let planName = subscription?.planName, !planName.isEmpty {
                    LabeledContent(L10n.premiumPlan, value: planName)
                }
            }
        }
    }

    private var productsSection: some View {
        Section(header: Text(L10n.premiumPlans)) {
            if storeKit.products.isEmpty {
                if case .loading = storeKit.state {
                    ProgressView(L10n.premiumLoading)
                } else {
                    Text(L10n.premiumProductsFailed).foregroundStyle(.secondary)
                }
            } else {
                ForEach(storeKit.products) { product in
                    Button {
                        Task { await storeKit.purchase(productID: product.id) }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.displayName).font(.headline)
                                Text(product.id.hasSuffix("yearly") ? L10n.premiumYearlyPeriod : L10n.premiumMonthlyPeriod)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice).fontWeight(.semibold)
                        }
                        .contentShape(Rectangle())
                    }
                    .disabled(!isSignedIn || isBusy)
                }
            }
            if !isSignedIn {
                Label(L10n.premiumLoginRequired, systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var operationSection: some View {
        switch storeKit.state {
        case .purchasing:
            Section { ProgressView(L10n.premiumPurchasing) }
        case .purchased:
            Section { Label(L10n.premiumPurchased, systemImage: "checkmark.seal.fill").foregroundStyle(.green) }
        case .restored:
            Section { Label(L10n.premiumRestored, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
        case .pending:
            Section { Label(L10n.premiumPending, systemImage: "clock").foregroundStyle(.secondary) }
        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                Button(L10n.commonRetry) { Task { await storeKit.prepare() } }
            }
        case .notLoaded, .loading, .available:
            EmptyView()
        }
    }

    private var actionsSection: some View {
        Section {
            Button(L10n.premiumRestore) { Task { await storeKit.restore() } }
                .disabled(!isSignedIn || isBusy)
            Button(L10n.premiumManageSubscriptions) { isManagingSubscriptions = true }
            Text(L10n.premiumCancellationNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var legalSection: some View {
        Section(header: Text(L10n.settingsLegalSection), footer: Text(L10n.premiumRenewalDisclosure)) {
            Link(L10n.settingsTerms, destination: termsURL)
            Link(L10n.settingsPrivacyPolicy, destination: privacyURL)
        }
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
