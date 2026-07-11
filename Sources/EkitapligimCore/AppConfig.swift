import Foundation

public enum AppEnvironment: String, Sendable {
    case development
    case staging
    case production
}

public struct AppConfig: Sendable, Equatable {
    public let environment: AppEnvironment
    public let apiBaseURL: URL
    public let webBaseURL: URL

    public init(environment: AppEnvironment, apiBaseURL: URL, webBaseURL: URL) {
        self.environment = environment
        self.apiBaseURL = apiBaseURL
        self.webBaseURL = webBaseURL
    }

    public var supportURL: URL {
        webBaseURL.appending(path: "diger/iletisim")
    }

    public var privacyPolicyURL: URL {
        webBaseURL.appending(path: "yardim/gizlilik-politikasi/")
    }

    public var termsURL: URL {
        webBaseURL.appending(path: "yardim/kurallar/")
    }

    public static func production() throws -> AppConfig {
        guard
            let apiURL = URL(string: "https://ekitapligim.com/mobile-api/v1/"),
            let webURL = URL(string: "https://ekitapligim.com/")
        else {
            throw ConfigurationError.invalidDefaultURL
        }
        AppConfig(
            environment: .production,
            apiBaseURL: apiURL,
            webBaseURL: webURL
        )
    }

    public func validateForRelease() throws {
        guard environment == .production else { return }
        guard apiBaseURL.scheme == "https" else { throw ConfigurationError.insecureProductionURL }
        let host = apiBaseURL.host?.lowercased() ?? ""
        if host == "localhost" || host == "127.0.0.1" || host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            throw ConfigurationError.localProductionURL
        }
    }
}

public enum ConfigurationError: Error, Equatable {
    case invalidDefaultURL
    case insecureProductionURL
    case localProductionURL
}
