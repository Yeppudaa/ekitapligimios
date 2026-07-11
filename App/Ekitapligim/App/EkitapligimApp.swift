import SwiftUI
import EkitapligimCore

@main
@MainActor
struct EkitapligimApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .task {
                    await container.bootstrap()
                }
        }
    }
}
