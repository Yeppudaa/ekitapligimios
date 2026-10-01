import Foundation

public struct RedactedLogger: Sendable {
    private let sensitiveKeys = [
        "authorization",
        "x-guest-key",
        "guest_key",
        "confirmation_token",
        "cookie",
        "password",
        "access_token",
        "refresh_token",
        "purchase_token",
        "app_account_token",
        "appaccounttoken",
        "identity_token",
        "authorization_code",
        "signed_transaction",
        "signed_renewal_info",
        "signedpayload",
        "signed_payload",
        "payment",
        "private_message",
        "message_body",
        "nonce"
    ]

    public init() {}

    public func redact(headers: [String: String]) -> [String: String] {
        headers.reduce(into: [String: String]()) { result, item in
            result[item.key] = sensitiveKeys.contains(item.key.lowercased()) ? "[REDACTED]" : item.value
        }
    }

    public func redact(message: String) -> String {
        sensitiveKeys.reduce(message) { partial, key in
            partial.replacingOccurrences(
                of: #"(?i)(?<![\w])["']?\#(key)["']?\s*[=:]\s*(?:"(?:\\.|[^"\\])*"|'[^']*'|[^&\r\n]+)"#,
                with: "\(key)=[REDACTED]",
                options: .regularExpression
            )
        }
    }
}
