import Foundation

public struct RedactedLogger: Sendable {
    private let sensitiveKeys = [
        "authorization",
        "cookie",
        "password",
        "access_token",
        "refresh_token",
        "purchase_token",
        "identity_token",
        "authorization_code",
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
                of: #"(?i)\#(key)[=:]\s*[^&\s]+"#,
                with: "\(key)=[REDACTED]",
                options: .regularExpression
            )
        }
    }
}
