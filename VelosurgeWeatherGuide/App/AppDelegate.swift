import UIKit
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    private static var didStartAppsFlyer = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAppsFlyer()
        configurePushNotifications(application)
        capturePushURLFromLaunchOptions(launchOptions)
        return true
    }

    private func configureAppsFlyer() {
        AppsFlyerLib.shared().appsFlyerDevKey = "cqTiFvvyhL5a2SNAqqAna3"
        AppsFlyerLib.shared().appleAppID = "6807215460"
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self

        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            if let app = FirebaseApp.app() {
                ConfigManagerOptionalData.firebaseProjectId = app.options.gcmSenderID
            }
        }
    }

    static func startAppsFlyerIfNeeded() {
        let start: () -> Void = {
            guard !didStartAppsFlyer else { return }
            didStartAppsFlyer = true
            AppsFlyerLib.shared().start()
        }
        if Thread.isMainThread {
            start()
        } else {
            DispatchQueue.main.sync(execute: start)
        }
    }

    private func configurePushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            case .notDetermined, .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func capturePushURLFromLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
              let url = PushNotificationURLRouter.shared.extractURL(from: userInfo) else { return }
        PushNotificationURLRouter.shared.setPendingURL(url)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let url = PushNotificationURLRouter.shared.extractURL(from: userInfo) {
            DispatchQueue.main.async { [weak self] in
                self?.openPushURLInWebView(url)
            }
        }
        completionHandler()
    }

    private func openPushURLInWebView(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            PushNotificationURLRouter.shared.setPendingURL(url)
            return
        }
        window.rootViewController = WebviewVC(url: url)
    }
}

extension AppDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        ConfigManagerOptionalData.pushToken = fcmToken
        if let app = FirebaseApp.app() {
            ConfigManagerOptionalData.firebaseProjectId = app.options.gcmSenderID
        }
        if NotificationPermissionManager.shared.consumeShouldSendTokenOnce() {
            ConfigManager.shared.requestConfig { _ in }
        }
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        AppsFlyerManager.shared.handleConversionDataSuccess(installData)
    }

    func onConversionDataFail(_ error: Error!) {
        AppsFlyerManager.shared.handleConversionDataFail(error)
    }
}

extension AppDelegate: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard result.status == .found, let deepLink = result.deepLink else { return }
        var payload: [AnyHashable: Any] = [:]
        for (key, value) in deepLink.clickEvent {
            payload[key] = value
        }
        payload["is_deferred"] = deepLink.isDeferred
        AppsFlyerManager.shared.handleDeepLinkData(payload)
    }
}
