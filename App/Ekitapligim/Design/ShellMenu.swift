import SwiftUI
import EkitapligimCore

/// A measured control shared by native navigation bars and Home's custom header.
@MainActor
struct EKitapligimMenuButton: View {
    @EnvironmentObject private var container: AppContainer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EKitapligimMenuButtonFace(hasUnread: container.totalUnread > 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.menuTitle)
        .accessibilityValue(container.totalUnread > 0 ? L10n.unreadCountAccessibility(container.totalUnread) : "")
        .accessibilityIdentifier("shell.menu")
    }
}

/// One opaque surface for both the custom Home header and native toolbar placements.
@MainActor
struct EKitapligimMenuButtonFace: View {
    let hasUnread: Bool

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(EKitapligimPalette.ink)
            .frame(width: 44, height: 44)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if hasUnread {
                    Circle()
                        .fill(EKitapligimPalette.amber)
                        .frame(width: 6, height: 6)
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// iOS 26 otherwise wraps custom toolbar content in a second, shared glass capsule.
@MainActor
struct EKitapligimMenuToolbarItem: ToolbarContent {
    let action: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            menuItem.sharedBackgroundVisibility(.hidden)
        } else {
            menuItem
        }
        #else
        menuItem
        #endif
    }

    private var menuItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            EKitapligimMenuButton(action: action)
        }
    }
}

extension View {
    /// Install on the root page inside its NavigationStack, so the bar allocates each action a slot.
    /// Hidden navigation bars and independently presented pages retain their own controls.
    @MainActor
    func shellMenu(action: (() -> Void)?) -> some View {
        toolbar {
            if let action {
                EKitapligimMenuToolbarItem(action: action)
            }
        }
    }
}
