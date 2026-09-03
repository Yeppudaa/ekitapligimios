import SwiftUI
import EkitapligimCore

@main
@MainActor
struct EkitapligimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    _ = GoogleSignInService.handle(url)
                }
                .task {
                    appDelegate.pushManager = container.pushManager
                    await container.bootstrap()
                }
        }
    }
}
