import Foundation

enum GoogleOAuthCredentials {
  static let iosClientID =
    "258534406055-trcoiet648ohvijagtpli1h1556i2cjq.apps.googleusercontent.com"
  static let serverClientID =
    "258534406055-v8lmgd6moijakv1kcurgit788uk5v2el.apps.googleusercontent.com"
  static let urlScheme =
    "com.googleusercontent.apps.258534406055-trcoiet648ohvijagtpli1h1556i2cjq"

  static func reversedClientID(from clientID: String) -> String {
    let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    return "com.googleusercontent.apps.\(prefix)"
  }

  static func resolvedPlistString(forKey key: String, fallback: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return fallback
    }
    return sanitized(value) ?? fallback
  }

  static func sanitized(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
    return trimmed
  }
}
