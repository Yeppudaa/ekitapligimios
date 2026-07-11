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
