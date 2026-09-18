import UIKit

enum UserAgentBuilder {

    static func build() -> String {
        let device = UIDevice.current
        let osVersion = device.systemVersion
        let osVersionUnderscore = osVersion.replacingOccurrences(of: ".", with: "_")
        let model = device.model
        let platform: String
        let cpuPart: String
        if model.hasPrefix("iPad") {
            platform = "iPad"
            cpuPart = "CPU OS \(osVersionUnderscore)"
        } else if model.hasPrefix("iPod") {
            platform = "iPod touch"
            cpuPart = "CPU iPhone OS \(osVersionUnderscore)"
        } else {
            platform = "iPhone"
            cpuPart = "CPU iPhone OS \(osVersionUnderscore)"
        }

        return [
            "Mozilla/5.0 (\(platform); \(cpuPart) like Mac OS X)",
            "AppleWebKit/605.1.15 (KHTML, like Gecko)",
            "Version/\(osVersion)",
            "Safari/604.1"
        ].joined(separator: " ")
    }
}
