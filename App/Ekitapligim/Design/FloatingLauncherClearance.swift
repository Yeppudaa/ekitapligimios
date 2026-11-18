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
        // Plain bottom padding on the scroll content, so the last row and "load more" buttons can
        // always be scrolled clear of the floating launcher. Safe-area padding is deliberately not
        // used here: on a ScrollView it fed back into layout and froze large-text screens.
        content.padding(.bottom, clearance)
    }
}

extension View {
    /// Apply to the content inside a screen's main vertical ScrollView (not to the ScrollView).
    func floatingLauncherClearance() -> some View {
        modifier(FloatingLauncherClearanceModifier())
    }
}

enum ShellLayout {
    static let floatingLauncherClearance: CGFloat = 76
}
