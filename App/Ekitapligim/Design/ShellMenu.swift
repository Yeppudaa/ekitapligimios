import SwiftUI
import EkitapligimCore

/// A measured control shared by native navigation bars and Home's custom header.
@MainActor
struct EKitapligimMenuButton: View {
    @EnvironmentObject private var container: AppContainer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(EKitapligimPalette.border)
                }
                .overlay(alignment: .topTrailing) {
                    if container.totalUnread > 0 {
                        Circle()
                            .fill(EKitapligimPalette.amber)
                            .frame(width: 8, height: 8)
                            .padding(3)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.menuTitle)
        .accessibilityIdentifier("shell.menu")
    }
}

extension View {
    /// Install on the root page inside its NavigationStack, so the bar allocates each action a slot.
    /// Hidden navigation bars and independently presented pages retain their own controls.
    @MainActor
    func shellMenu(action: (() -> Void)?) -> some View {
        toolbar {
            if let action {
                ToolbarItem(placement: .topBarTrailing) {
                    EKitapligimMenuButton(action: action)
                }
            }
        }
    }
}
