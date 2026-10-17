import SwiftUI
import EkitapligimCore

@main
@MainActor
struct EkitapligimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            appContent
                .environmentObject(container)
                .preferredColorScheme(appColorScheme)
                .onOpenURL { url in
                    _ = GoogleSignInService.handle(url)
                }
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-modern-parity-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-ai-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-gift-wheel-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-reader-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-chat-ui-fixture") { return }
                    if isUnitTestHost { return }
                    #endif
                    appDelegate.pushManager = container.pushManager
                    await container.bootstrap()
                }
        }
    }

    private var appColorScheme: ColorScheme {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-modern-parity-ui-fixture"),
           ProcessInfo.processInfo.environment["MODERN_PARITY_DARK"] == "1" { return .dark }
        #endif
        return .light
    }

    #if DEBUG
    private var isUnitTestHost: Bool {
        // Hosted XCTest bundles run their own injected services. Rendering RootView would start
        // unrelated Home polling and bootstrap while those tests are exercising AVFoundation.
        ProcessInfo.processInfo.environment["MODERN_PARITY_UNIT_HOST"] == "1"
    }
    #endif

    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-modern-parity-ui-fixture") { ModernParityUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-ai-ui-fixture") { AIUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-gift-wheel-ui-fixture") { GiftWheelUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-reader-ui-fixture") { ReaderUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-chat-ui-fixture") { ChatUITestHost() }
        else if isUnitTestHost { Color.clear.accessibilityHidden(true) }
        else { RootView() }
        #else
        RootView()
        #endif
    }
}
