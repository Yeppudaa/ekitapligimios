#if DEBUG
import Foundation

/// Small local PNGs exercise actual successful, delayed and failed AsyncImage responses.
/// These URLs are available only in the explicitly launched, fully intercepted UI harness.
enum ModernParityHomeCoverFixture {
    static var enabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-modern-parity-ui-fixture") &&
            ProcessInfo.processInfo.environment["MODERN_PARITY_HOME_COVERS"] == "1"
    }

    static func url(for index: Int) -> String? {
        guard enabled else { return nil }
        let name: String
        switch index {
        case 1: name = "tall"
        case 2: name = "wide"
        case 3: name = "missing"
        case 4: name = "delayed"
        default: return ""
        }
        return "https://ekitapligim.com/_offline_home_cover/\(name).png"
    }

    static func response(for url: URL) -> (status: Int, data: Data, delay: TimeInterval)? {
        guard enabled, url.scheme == "https", url.host == "ekitapligim.com",
              url.path.hasPrefix("/_offline_home_cover/") else { return nil }
        let tall = "iVBORw0KGgoAAAANSUhEUgAAACgAAABQCAIAAADk7aCWAAAAQUlEQVR4nO3NIREAAAgEMEJ8TjTxsTTA7G5+lZ4XJRaLxWKxWCwWi8VisVgsFovFYrFYLBaLxWKxWCwWi8XinHgB0h41tZ2zJqoAAAAASUVORK5CYII="
        let wide = "iVBORw0KGgoAAAANSUhEUgAAAFAAAAAoCAIAAADmAupWAAAAS0lEQVR4nO3PAQkAIBDAQDOZzkymNIawP1iA3bpnj2p9PwAGBgYGBgYeE3A94HrA9YDrAdcDrgdcD7gecD3gesD1gOsB1wOuB3ziPdutmvE3VPJSAAAAAElFTkSuQmCC"
        switch url.lastPathComponent {
        case "tall.png": return Data(base64Encoded: tall).map { (200, $0, 0) }
        case "wide.png": return Data(base64Encoded: wide).map { (200, $0, 0) }
        case "delayed.png": return Data(base64Encoded: tall).map { (200, $0, 2) }
        default: return (404, Data(), 0)
        }
    }
}
#endif
