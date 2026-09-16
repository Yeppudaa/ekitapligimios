import Network
import EkitapligimCore

@MainActor
final class ReaderProgressConnectivity {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.ekitapligim.reader-connectivity")

    func start(onConnected: @escaping @MainActor @Sendable () async -> Void) {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await onConnected() }
        }
        self.monitor = monitor
        monitor.start(queue: queue)
    }

    func stop() { monitor?.cancel(); monitor = nil }
}
