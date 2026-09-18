import UIKit
import SwiftUI
import AppsFlyerLib

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let background = UIColor(named: "AppBackground") ?? UIColor(red: 0.243, green: 0.090, blue: 0.200, alpha: 1)
        window = KeyboardDismissWindow(windowScene: windowScene)
        window?.backgroundColor = background
        window?.rootViewController = LoadingManager.shared.makeRootViewController()
        window?.makeKeyAndVisible()
        handleDeepLinkConnectionOptions(connectionOptions)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        AppsFlyerLib.shared().handleOpen(url, options: nil)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        routePendingPushURLIfNeeded(in: scene)
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}

    private func handleDeepLinkConnectionOptions(_ options: UIScene.ConnectionOptions) {
        if let urlContext = options.urlContexts.first {
            AppsFlyerLib.shared().handleOpen(urlContext.url, options: nil)
        }
        if let activity = options.userActivities.first {
            AppsFlyerLib.shared().continue(activity, restorationHandler: nil)
        }
    }

    private func routePendingPushURLIfNeeded(in scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let url = PushNotificationURLRouter.shared.consumePendingURL() else { return }

        let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        window?.rootViewController = WebviewVC(url: url)
    }
}

final class KeyboardDismissWindow: UIWindow, UIGestureRecognizerDelegate {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            let typeName = String(describing: type(of: current))
            if typeName.contains("TextField") || typeName.contains("TextView") {
                return false
            }
            view = current.superview
        }
        return true
    }
}
