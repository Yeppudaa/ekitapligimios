import SwiftUI
import EkitapligimCore

@MainActor
struct PremiumView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        PremiumContentView(
            storeKit: container.storeKit,
            isSignedIn: isSignedIn,
            termsURL: container.config.termsURL,
            privacyURL: container.config.privacyPolicyURL
        )
    }

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }
}

@MainActor
private struct PremiumContentView: View {
    @ObservedObject var storeKit: StoreKitPurchaseService
    let isSignedIn: Bool
    let termsURL: URL
    let privacyURL: URL

    var body: some View {
        List {
            descriptionSection
            productsSection
            actionsSection
            legalSection
        }
        .navigationTitle(L10n.premiumTitle)
        .task { await storeKit.loadProducts() }
    }

    private var descriptionSection: some View {
        Section {
            Text(L10n.premiumDescription)
        }
    }

    private var productsSection: some View {
        Section(header: Text(L10n.premiumPlans)) {
            switch storeKit.state {
            case .notLoaded, .loading:
                ProgressView(L10n.premiumLoading)
            case .available(let products):
                ForEach(products) { product in
                    Button {
                        Task { await storeKit.purchase(productID: product.id) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                            Spacer()
                            Text(product.displayPrice)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!isSignedIn)
                }
                if !isSignedIn {
                    Label(L10n.premiumLoginRequired, systemImage: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
            case .purchasing:
                ProgressView(L10n.premiumPurchasing)
            case .purchased:
                Label(L10n.premiumPurchased, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .restored:
                Label(L10n.premiumRestored, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .pending:
                Label(L10n.premiumPending, systemImage: "clock")
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Button(L10n.commonRetry) {
                    Task { await storeKit.loadProducts() }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button(L10n.premiumRestore) {
                Task { await storeKit.restore() }
            }
            .disabled(!isSignedIn || isBusy)

            if let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                Link(L10n.premiumManageSubscriptions, destination: subscriptionsURL)
            }
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
}
