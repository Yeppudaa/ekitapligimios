import SwiftUI
import EkitapligimCore

/// Installed inside the active shell stack, never inside an independent sheet or audio child page.
@MainActor
private struct AudioPageNavigationModifier: ViewModifier {
    @EnvironmentObject private var container: AppContainer
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.navigationDestination(item: $container.audioPageRoute) { route in
                Group {
                    if route.requiresAuthentication && !container.isSignedIn {
                        LoginRequiredView()
                            .navigationTitle(AudioL10n.text("libraryTitle"))
                            .navigationBarTitleDisplayMode(.inline)
                    } else {
                        AudioRouteDestination(route: route)
                    }
                }
                .toolbar(.visible, for: .navigationBar)
                .tint(EKitapligimPalette.teal)
            }
        } else {
            content
        }
    }
}

extension View {
    @MainActor
    func audioPageNavigation(enabled: Bool = true) -> some View {
        modifier(AudioPageNavigationModifier(enabled: enabled))
    }
}
