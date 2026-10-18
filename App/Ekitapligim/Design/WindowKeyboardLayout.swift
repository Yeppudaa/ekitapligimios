import SwiftUI
import UIKit
import EkitapligimCore

private struct ReplyViewportHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = .infinity
}

extension EnvironmentValues {
    /// The current local content viewport, never a cached screen or keyboard height.
    var replyViewportHeight: CGFloat {
        get { self[ReplyViewportHeightKey.self] }
        set { self[ReplyViewportHeightKey.self] = newValue }
    }
}

/// Reads UIKit's live, window-local keyboard geometry without global keyboard notifications.
/// This view must be outside the region inset by the reported value to avoid a feedback loop.
@MainActor
struct WindowKeyboardLayoutReader: UIViewRepresentable {
    var dismissRequest: Int
    var onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> KeyboardLayoutProbeView {
        let view = KeyboardLayoutProbeView()
        view.dismissRequest = dismissRequest
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: KeyboardLayoutProbeView, context: Context) {
        view.onChange = onChange
        if view.dismissRequest != dismissRequest {
            view.dismissRequest = dismissRequest
            // Scope dismissal to the window containing this shell (iPad supports multiple scenes).
            view.window?.endEditing(true)
        }
        view.setNeedsLayout()
    }

    static func dismantleUIView(_ view: KeyboardLayoutProbeView, coordinator: ()) {
        view.onChange = nil
    }
}

@MainActor
final class KeyboardLayoutProbeView: UIView {
    var onChange: ((CGFloat) -> Void)?
    var dismissRequest = 0
    private let trackingView = KeyboardGuideTrackingView()
    private var measuredInset: CGFloat = -1
    private var measurementRevision = 0

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        // A floating/undocked iPad keyboard must not reserve the entire bottom of the window.
        keyboardLayoutGuide.followsUndockedKeyboard = false
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackingView)
        NSLayoutConstraint.activate([
            trackingView.leadingAnchor.constraint(equalTo: keyboardLayoutGuide.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: keyboardLayoutGuide.trailingAnchor),
            trackingView.topAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.bottomAnchor)
        ])
        trackingView.onLayout = { [weak self] in self?.reportGeometry() }
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportGeometry()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
        if window == nil { publish(0) }
    }

    private func reportGeometry() {
        guard window != nil, !bounds.isEmpty else { return }
        publish(KeyboardLayoutMetrics.bottomInset(viewBounds: bounds,
            keyboardFrame: keyboardLayoutGuide.layoutFrame, bottomSafeArea: safeAreaInsets.bottom))
    }

    private func publish(_ inset: CGFloat) {
        guard abs(inset - measuredInset) > 0.5 else { return }
        measuredInset = inset
        measurementRevision += 1
        let revision = measurementRevision
        // UIKit may report during SwiftUI's layout pass. Only publish the newest geometry afterward.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.measurementRevision == revision else { return }
            self.onChange?(inset)
        }
    }
}

@MainActor
private final class KeyboardGuideTrackingView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

private struct PinnedReplyEditorModifier: ViewModifier {
    @Environment(\.replyViewportHeight) private var viewportHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.frame(height: KeyboardLayoutMetrics.replyEditorHeight(
            availableHeight: viewportHeight, accessibility: dynamicTypeSize.isAccessibilitySize))
    }
}

extension View {
    func keyboardSizedReplyEditor() -> some View { modifier(PinnedReplyEditorModifier()) }
}
