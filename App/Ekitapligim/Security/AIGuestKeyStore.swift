import Foundation
import Security
import EkitapligimCore

/// Separate from the signed-in session: logout and clearing conversations never rotate this identity.
actor AIGuestKeyStore: AIGuestKeyProviding {
    private let service = "com.ekitapligim.app.ai"
    func guestKey() async throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "guest-key"]
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8),
           value.count == 64, value.allSatisfy({ "0123456789abcdef".contains($0) }) { return value }
        // A corrupt or locked record must not silently grant a new anonymous quota.
        guard status == errSecItemNotFound else { throw KeychainError.unhandled(status) }
        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else { throw KeychainError.unhandled(randomStatus) }
        let value = bytes.map { String(format: "%02x", $0) }.joined()
        var insert = query
        insert[kSecValueData as String] = Data(value.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let result = SecItemAdd(insert as CFDictionary, nil)
        guard result == errSecSuccess else { throw KeychainError.unhandled(result) }
        return value
    }
}
