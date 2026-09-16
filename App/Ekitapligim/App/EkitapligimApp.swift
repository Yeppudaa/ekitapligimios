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
                    #endif
                    appDelegate.pushManager = container.pushManager
                    await container.bootstrap()
                }
        }
    }

    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ai-ui-fixture") { AIUITestHost() }
        else { RootView() }
        #else
        RootView()
        #endif
    }
}
