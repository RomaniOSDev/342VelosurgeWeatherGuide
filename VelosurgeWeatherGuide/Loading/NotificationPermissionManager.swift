import Foundation
import UserNotifications

enum NotificationPermissionKeys {
    static let lastCustomDeclineDate = "NotificationPermissionLastCustomDeclineDate"
    static let shouldSendTokenOnce = "NotificationPermissionShouldSendTokenOnce"
    static let acceptedOnce = "NotificationPermissionAcceptedOnce"
}

private let customDeclineCooldownDays: Int = 3

final class NotificationPermissionManager {

    static let shared = NotificationPermissionManager()

    private init() {}

    func recordCustomDecline() {
        UserDefaults.standard.set(Date(), forKey: NotificationPermissionKeys.lastCustomDeclineDate)
    }

    func recordCustomAccept() {
        UserDefaults.standard.set(true, forKey: NotificationPermissionKeys.acceptedOnce)
    }

    func markShouldSendTokenOnce() {
        UserDefaults.standard.set(true, forKey: NotificationPermissionKeys.shouldSendTokenOnce)
    }

    func consumeShouldSendTokenOnce() -> Bool {
        let flag = UserDefaults.standard.bool(forKey: NotificationPermissionKeys.shouldSendTokenOnce)
        if flag {
            UserDefaults.standard.set(false, forKey: NotificationPermissionKeys.shouldSendTokenOnce)
        }
        return flag
    }

    func shouldShowCustomNotificationScreen(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let shouldShow: Bool
            if let date = UserDefaults.standard.object(forKey: NotificationPermissionKeys.lastCustomDeclineDate) as? Date {
                let interval = Date().timeIntervalSince(date)
                let threeDays: TimeInterval = TimeInterval(customDeclineCooldownDays * 24 * 60 * 60)
                shouldShow = interval >= threeDays
            } else {
                shouldShow = true
            }
            DispatchQueue.main.async { completion(shouldShow) }
        }
    }
}
