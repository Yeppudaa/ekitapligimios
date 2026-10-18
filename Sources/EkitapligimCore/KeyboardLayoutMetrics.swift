import Foundation

/// Pure layout policy for a keyboard guide measured in its owning view's coordinates.
/// A guide that is hidden or floating must not reserve a keyboard-sized blank region.
public enum KeyboardLayoutMetrics {
    public static func bottomInset(
        viewBounds: CGRect,
        keyboardFrame: CGRect,
        bottomSafeArea: CGFloat
    ) -> CGFloat {
        guard isValid(viewBounds), isValid(keyboardFrame), bottomSafeArea.isFinite else { return 0 }

        let intersection = viewBounds.intersection(keyboardFrame)
        guard isValid(intersection) else { return 0 }

        // Accommodate subpixel rounding, while rejecting side, floating and undocked guides.
        let tolerance: CGFloat = 0.5
        guard intersection.minX <= viewBounds.minX + tolerance,
              intersection.maxX >= viewBounds.maxX - tolerance,
              keyboardFrame.maxY >= viewBounds.maxY - tolerance,
              intersection.maxY >= viewBounds.maxY - tolerance else { return 0 }

        // UIKeyboardLayoutGuide includes the home-indicator safe area even when hidden.
        let safeBottom = min(viewBounds.height, max(0, bottomSafeArea))
        return min(viewBounds.height, max(0, intersection.height - safeBottom))
    }

    /// Leaves room for the transcript and send controls in short keyboard-visible viewports.
    public static func replyEditorHeight(availableHeight: CGFloat, accessibility: Bool) -> CGFloat {
        guard availableHeight.isFinite else { return accessibility ? 100 : 76 }

        let preferred: CGFloat
        if availableHeight < 300 {
            preferred = accessibility ? 52 : 40
        } else {
            preferred = accessibility ? 100 : 76
        }
        return max(36, min(100, min(preferred, max(0, availableHeight) * 0.25)))
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        !rect.isInfinite && !rect.isNull && !rect.isEmpty
            && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.size.width.isFinite && rect.size.height.isFinite
            && rect.minX.isFinite && rect.maxX.isFinite
            && rect.minY.isFinite && rect.maxY.isFinite
            && rect.size.width > 0 && rect.size.height > 0
    }
}
