import UIKit
import SwiftUI
import UserNotifications

final class NotificationPermissionViewController: UIViewController {

    private let url: URL
    private weak var window: UIWindow?

    init(url: URL, window: UIWindow?) {
        self.url = url
        self.window = window
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let swiftUIView = NotificationPermissionView(
            onAccept: { [weak self] in self?.handleAccept() },
            onDecline: { [weak self] in self?.handleDecline() }
        )
        let hosting = UIHostingController(rootView: swiftUIView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    private func handleAccept() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            NotificationPermissionManager.shared.recordCustomAccept()
                            NotificationPermissionManager.shared.markShouldSendTokenOnce()
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        self?.showWebView()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                NotificationPermissionManager.shared.recordCustomAccept()
                DispatchQueue.main.async { [weak self] in
                    self?.showWebView()
                }
            case .denied:
                DispatchQueue.main.async { [weak self] in
                    self?.showWebView()
                }
            @unknown default:
                DispatchQueue.main.async { [weak self] in
                    self?.showWebView()
                }
            }
        }
    }

    private func handleDecline() {
        NotificationPermissionManager.shared.recordCustomDecline()
        showWebView()
    }

    private func showWebView() {
        let webVC = WebviewVC(url: url)
        window?.rootViewController = webVC
    }
}
