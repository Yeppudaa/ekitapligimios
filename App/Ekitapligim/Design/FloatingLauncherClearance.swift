import SwiftUI

/// Height the shell's floating AI launcher occupies above the tab bar (52 pt button, 16 pt
/// margin and breathing room). Zero where the launcher is never shown, such as route sheets.
private struct FloatingLauncherClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var floatingLauncherClearance: CGFloat {
        get { self[FloatingLauncherClearanceKey.self] }
        set { self[FloatingLauncherClearanceKey.self] = newValue }
    }
}

private struct FloatingLauncherClearanceModifier: ViewModifier {
    @Environment(\.floatingLauncherClearance) private var clearance

    func body(content: Content) -> some View {
        // Extends the scrollable area only, so the last row and "load more" buttons can always be
        // scrolled clear of the floating launcher instead of staying underneath it.
        content.safeAreaPadding(.bottom, clearance)
    }
}

extension View {
    /// Apply to a screen's main vertical ScrollView.
    func floatingLauncherClearance() -> some View {
        modifier(FloatingLauncherClearanceModifier())
    }
}

enum ShellLayout {
    static let floatingLauncherClearance: CGFloat = 76
}
