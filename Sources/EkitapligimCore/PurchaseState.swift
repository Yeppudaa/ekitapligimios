import Foundation

public enum PurchaseState: Equatable, Sendable {
    case notLoaded
    case loading
    case available(products: [StoreProduct])
    case purchasing(productID: String)
    case purchased(productID: String, expiration: Date?)
    case restored
    case pending
    case failed(message: String)
}

public enum PremiumRenewalState: Equatable, Sendable {
    case none
    case active
    case cancelled
    case gracePeriod
    case billingRetry
    case expired
    case revoked
}

public struct PremiumEntitlement: Equatable, Sendable {
    public let productID: String?
    public let expiration: Date?
    public let renewalState: PremiumRenewalState
    public let willAutoRenew: Bool

    public init(
        productID: String? = nil,
        expiration: Date? = nil,
        renewalState: PremiumRenewalState = .none,
        willAutoRenew: Bool = false
    ) {
        self.productID = productID
        self.expiration = expiration
        self.renewalState = renewalState
        self.willAutoRenew = willAutoRenew
    }

    public static let none = PremiumEntitlement()

    public var isActive: Bool {
        switch renewalState {
        case .active, .cancelled, .gracePeriod:
            true
        case .none, .billingRetry, .expired, .revoked:
            false
        }
    }
}

public struct StoreProduct: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let displayPrice: String

    public init(id: String, displayName: String, displayPrice: String) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}
