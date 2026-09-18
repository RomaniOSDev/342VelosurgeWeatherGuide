import Foundation
import Network

enum NetworkAvailability {
    static func checkConnection(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "network.availability.check")
        var completed = false

        func finish(_ connected: Bool) {
            guard !completed else { return }
            completed = true
            monitor.cancel()
            DispatchQueue.main.async {
                completion(connected)
            }
        }

        monitor.pathUpdateHandler = { path in
            finish(path.status == .satisfied)
        }

        monitor.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 1.0) {
            finish(false)
        }
    }
}
