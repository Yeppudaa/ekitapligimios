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
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    _ = GoogleSignInService.handle(url)
                }
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-ai-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-gift-wheel-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-reader-ui-fixture") { return }
                    if ProcessInfo.processInfo.arguments.contains("-chat-ui-fixture") { return }
                    #endif
                    appDelegate.pushManager = container.pushManager
                    await container.bootstrap()
                }
        }
    }

    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ai-ui-fixture") { AIUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-gift-wheel-ui-fixture") { GiftWheelUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-reader-ui-fixture") { ReaderUITestHost() }
        else if ProcessInfo.processInfo.arguments.contains("-chat-ui-fixture") { ChatUITestHost() }
        else { RootView() }
        #else
        RootView()
        #endif
    }
}
