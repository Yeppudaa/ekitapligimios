import SwiftUI
import UIKit
import EkitapligimCore

@MainActor final class GiftWheelModel: ObservableObject {
    @Published private(set) var state = GiftWheelState()
    let controller: GiftWheelController
    private var displayLink: CADisplayLink?
    private var displayTarget: WheelDisplayTarget?
    private var visible = false
    init(service: any GiftWheelServing, pendingStore: any GiftWheelPendingStoring) {
        controller = GiftWheelController(service: service, pendingStore: pendingStore)
        controller.didChange = { [weak self] state in
            guard let self else { return }
            self.state = state
            self.updateDisplayLink()
        }
    }
    func setVisible(_ visible: Bool) {
        self.visible = visible
        if !visible { controller.suspendAnimation() }
        updateDisplayLink()
    }
    private func updateDisplayLink() {
        if visible && state.spinning {
            guard displayLink == nil else { return }
            let target = WheelDisplayTarget { [weak self] time in self?.controller.frame(at: time) }
            let link = CADisplayLink(target: target, selector: #selector(WheelDisplayTarget.frame(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
            displayTarget = target; displayLink = link
            link.add(to: .main, forMode: .common)
        } else {
            displayLink?.invalidate(); displayLink = nil; displayTarget = nil
        }
    }
}

@MainActor private final class WheelDisplayTarget: NSObject {
    private let callback: (TimeInterval) -> Void
    init(callback: @escaping (TimeInterval) -> Void) { self.callback = callback }
    @objc func frame(_ link: CADisplayLink) { callback(link.timestamp) }
}

@MainActor struct GiftWheelDestination: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        GiftWheelView(model: container.giftWheelModel, isSignedIn: container.isSignedIn,
                      onLogin: { container.open(route: container.isSignedIn ? .profile : .login) },
                      onLiveActivity: { container.open(route: .liveActivity) })
    }
}
