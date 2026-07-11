import SwiftUI
import EkitapligimCore

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

private struct PremiumContentView: View {
    @ObservedObject var storeKit: StoreKitPurchaseService
    let isSignedIn: Bool
    let termsURL: URL
    let privacyURL: URL

    var body: some View {
        List {
            Section {
                Text(L10n.premiumDescription)
            }

            productsSection

            Section {
                Button(L10n.premiumRestore) {
                    Task { await storeKit.restore() }
                }
                .disabled(!isSignedIn || isBusy)

                if let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(L10n.premiumManageSubscriptions, destination: subscriptionsURL)
                }
            }

            Section(L10n.settingsLegalSection) {
                Link(L10n.settingsTerms, destination: termsURL)
                Link(L10n.settingsPrivacyPolicy, destination: privacyURL)
            } footer: {
                Text(L10n.premiumRenewalDisclosure)
            }
        }
        .navigationTitle(L10n.premiumTitle)
        .task { await storeKit.loadProducts() }
    }

    @ViewBuilder
    private var productsSection: some View {
        Section(L10n.premiumPlans) {
            switch storeKit.state {
            case .notLoaded, .loading:
                ProgressView(L10n.premiumLoading)
            case .available(let products):
                ForEach(products) { product in
                    Button {
                        Task { await storeKit.purchase(productID: product.id) }
                    } label: {
                        LabeledContent(product.displayName, value: product.displayPrice)
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

    private var isBusy: Bool {
        switch storeKit.state {
        case .loading, .purchasing: true
        default: false
        }
    }
}
