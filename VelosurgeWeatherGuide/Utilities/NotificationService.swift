import Foundation
import UserNotifications

enum AppNotify {
    static let reminderId = "daily-moisture-reminder"

    static func requestAccess(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func scheduleReminder(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderId])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Check soil moisture"
        content.body = "Log a reading so today isn't a gap in your charts."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger))
    }

    static func scheduleWaterCheck(bed: String, hours: Int) {
        guard hours > 0 else { return }
        let identifier = "water-check-\(bed)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Check \(bed)"
        content.body = "Moisture should have settled after watering. Log a new reading."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(hours * 3600), repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func fireThreshold(bed: String, kind: String, percent: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(bed): \(kind)"
        content.body = "Latest moisture is \(percent)%."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.4, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "threshold-\(UUID().uuidString)", content: content, trigger: trigger)
        )
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
