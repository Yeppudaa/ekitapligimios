import Foundation
import Security
import EkitapligimCore

protocol TokenStore: SessionTokenManaging {}

actor KeychainTokenStore: TokenStore {
    private let service: String
    private let account = "session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String) {
        self.service = service
    }

    func accessToken() async throws -> String? {
        try readSession()?.accessToken
    }

    func loadSession() async throws -> Session? {
        try readSession()
    }

    private func readSession() throws -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandled(status)
        }
        return try decoder.decode(Session.self, from: data)
    }

    func save(session: Session) async throws {
        try writeSession(session)
    }

    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool {
        guard try readSession() == expected else { return false }
        if let session { try writeSession(session) }
        else { try deleteSession() }
        return true
    }

    private func writeSession(_ session: Session) throws {
        let data = try encoder.encode(session)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func clear() async throws {
        try deleteSession()
    }

    private func deleteSession() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

enum KeychainError: Error, Equatable {
    case unhandled(OSStatus)
}
