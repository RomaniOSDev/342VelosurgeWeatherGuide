import Network
import UIKit
import SwiftUI
import AppTrackingTransparency

private let conversionDataMaxWaitInterval: TimeInterval = 30
private let maxLoadingTimeInterval: TimeInterval = 35
private let ordinaryStartDelayInterval: TimeInterval = 5
private let conversionDataFreshnessInterval: TimeInterval = 120

final class LoadingViewController: UIViewController {

    private let loadingHosting = UIHostingController(rootView: AnyView(LoadingView()))
    private var didFinishTransition = false
    private var timeoutWorkItem: DispatchWorkItem?
    private var conversionWaitWorkItem: DispatchWorkItem?
    private var conversionObserver: NSObjectProtocol?
    private var didStartConfigRequest = false
    private var ordinaryStartWorkItem: DispatchWorkItem?
    private var networkMonitor: NWPathMonitor?
    private var isConfigFlowInProgress = false
    private var isShowingNoInternet = false
    private var hasEnteredOnlineConfigFlow = false
    private var isAwaitingConversionData = false
    private var didRetryConfigAfterFailure = false
    private var didHandleATTGate = false
    private var becomeActiveObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(loadingHosting)
        view.addSubview(loadingHosting.view)
        loadingHosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingHosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingHosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingHosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            loadingHosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        loadingHosting.didMove(toParent: self)
        subscribeToConversionDataNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestTrackingAuthorizationThenContinue()
    }

    deinit {
        cancelScheduledWork()
        stopOfflineNetworkMonitoring()
        removeConversionObserver()
        if let becomeActiveObserver {
            NotificationCenter.default.removeObserver(becomeActiveObserver)
        }
        becomeActiveObserver = nil
    }

    private func requestTrackingAuthorizationThenContinue() {
        guard !didHandleATTGate else { return }
        didHandleATTGate = true

        let continueStartup: () -> Void = { [weak self] in
            AppDelegate.startAppsFlyerIfNeeded()
            self?.startConfigFlow()
        }

        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            continueStartup()
            return
        }

        let presentATT = {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    continueStartup()
                }
            }
        }

        if UIApplication.shared.applicationState == .active {
            presentATT()
        } else {
            becomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if let becomeActiveObserver = self.becomeActiveObserver {
                    NotificationCenter.default.removeObserver(becomeActiveObserver)
                    self.becomeActiveObserver = nil
                }
                guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
                    continueStartup()
                    return
                }
                presentATT()
            }
        }
    }

    private func startConfigFlow() {
        if didFinishTransition { return }
        if let pushURL = PushNotificationURLRouter.shared.consumePendingURL() {
            ordinaryStartWorkItem?.cancel()
            ordinaryStartWorkItem = nil
            isConfigFlowInProgress = true
            didFinishTransition = true
            replaceRoot(with: WebviewVC(url: pushURL))
            return
        }

        if isShowingNoInternet {
            retryAfterNoInternet()
            return
        }

        guard !isConfigFlowInProgress, ordinaryStartWorkItem == nil else { return }
        isConfigFlowInProgress = true
        showLoadingState()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ordinaryStartWorkItem = nil
            guard !self.didFinishTransition, self.isConfigFlowInProgress else { return }
            self.startConfigFlowWithoutPush()
        }
        ordinaryStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + ordinaryStartDelayInterval, execute: workItem)
    }

    private func retryAfterNoInternet() {
        guard !didFinishTransition else { return }
        stopOfflineNetworkMonitoring()
        isShowingNoInternet = false
        isConfigFlowInProgress = true
        hasEnteredOnlineConfigFlow = false
        didStartConfigRequest = false
        isAwaitingConversionData = false
        didRetryConfigAfterFailure = false
        showLoadingState()
        AppsFlyerManager.shared.clearConversionDataIfStale(olderThan: conversionDataFreshnessInterval)
        AppsFlyerManager.shared.restartConversionFetch()
        startConfigFlowWithoutPush()
    }

    private func startConfigFlowWithoutPush() {
        if didFinishTransition { return }
        isConfigFlowInProgress = true
        showLoadingState()

        NetworkAvailability.checkConnection { [weak self] isConnected in
            guard let self = self, !self.didFinishTransition else { return }
            if !isConnected {
                self.showNoInternetState()
                return
            }
            self.startConfigFlowWithInternet()
        }
    }

    private func startConfigFlowWithInternet() {
        if didFinishTransition { return }
        hasEnteredOnlineConfigFlow = true
        didStartConfigRequest = false

        timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finishByTimeout()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + maxLoadingTimeInterval, execute: timeoutWorkItem!)

        if ConfigManager.shared.isSavedURLValid, let url = ConfigManager.shared.savedURL {
            cancelScheduledWork()
            transitionToWebView(url: url)
            return
        }

        waitForConversionDataThenRequestConfig()
    }

    private func showLoadingState() {
        loadingHosting.rootView = AnyView(LoadingView())
    }

    private func showNoInternetState() {
        isShowingNoInternet = true
        isConfigFlowInProgress = false
        hasEnteredOnlineConfigFlow = false
        isAwaitingConversionData = false
        cancelScheduledWork()
        startOfflineNetworkMonitoring()
        loadingHosting.rootView = AnyView(
            NoInternetView(
                onRetry: { [weak self] in
                    self?.retryAfterNoInternet()
                }
            )
        )
    }

    private func startOfflineNetworkMonitoring() {
        stopOfflineNetworkMonitoring()
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self,
                      self.isShowingNoInternet,
                      !self.didFinishTransition,
                      path.status == .satisfied else { return }
                AppsFlyerManager.shared.restartConversionFetch()
            }
        }
        monitor.start(queue: DispatchQueue(label: "loading.offline.network"))
    }

    private func stopOfflineNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    private func subscribeToConversionDataNotifications() {
        guard conversionObserver == nil else { return }
        conversionObserver = NotificationCenter.default.addObserver(
            forName: .appsFlyerConversionDataReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleConversionDataReady()
        }
    }

    private func handleConversionDataReady() {
        guard !didFinishTransition else { return }

        if isShowingNoInternet {
            NetworkAvailability.checkConnection { [weak self] isConnected in
                guard let self, isConnected else { return }
                self.retryAfterNoInternet()
            }
            return
        }

        guard hasEnteredOnlineConfigFlow, !didStartConfigRequest else { return }
        isAwaitingConversionData = false
        conversionWaitWorkItem?.cancel()
        conversionWaitWorkItem = nil
        performConfigRequest()
    }

    private func cancelScheduledWork() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        ordinaryStartWorkItem?.cancel()
        ordinaryStartWorkItem = nil
        conversionWaitWorkItem?.cancel()
        conversionWaitWorkItem = nil
    }

    private func removeConversionObserver() {
        if let observer = conversionObserver {
            NotificationCenter.default.removeObserver(observer)
            conversionObserver = nil
        }
    }

    private func finishByTimeout() {
        guard !didFinishTransition else { return }
        if didStartConfigRequest { return }

        if AppsFlyerManager.shared.conversionDataString != nil {
            performConfigRequest()
            return
        }

        isAwaitingConversionData = false
        transitionToContentViewOrSavedWebView()
    }

    private func performConfigRequest() {
        guard !didFinishTransition, !didStartConfigRequest else { return }

        guard AppsFlyerManager.shared.conversionDataString != nil else {
            waitForConversionDataThenRequestConfig()
            return
        }

        didStartConfigRequest = true
        isAwaitingConversionData = false
        cancelScheduledWork()

        ConfigManager.shared.requestConfig { [weak self] result in
            guard let self = self, !self.didFinishTransition else { return }
            switch result {
            case .success(let response):
                if response.ok, let urlString = response.url, let url = URL(string: urlString) {
                    self.removeConversionObserver()
                    self.transitionToWebView(url: url)
                } else {
                    self.handleConfigFailure()
                }
            case .failure:
                self.handleConfigFailure()
            }
        }
    }

    private func handleConfigFailure() {
        didStartConfigRequest = false

        if ConfigManager.shared.isSavedURLValid, let url = ConfigManager.shared.savedURL {
            removeConversionObserver()
            transitionToWebView(url: url)
            return
        }

        if isAwaitingConversionData {
            return
        }

        if !didRetryConfigAfterFailure,
           !AppsFlyerManager.shared.hasFreshConversionData(within: conversionDataFreshnessInterval) {
            didRetryConfigAfterFailure = true
            AppsFlyerManager.shared.clearStoredConversionString()
            waitForConversionDataThenRequestConfig()
            return
        }

        removeConversionObserver()
        transitionToContentView()
    }

    private func waitForConversionDataThenRequestConfig() {
        subscribeToConversionDataNotifications()
        isAwaitingConversionData = true

        if AppsFlyerManager.shared.conversionDataString != nil {
            isAwaitingConversionData = false
            performConfigRequest()
            return
        }

        AppsFlyerManager.shared.restartConversionFetch()

        conversionWaitWorkItem?.cancel()
        conversionWaitWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.didFinishTransition, !self.didStartConfigRequest else { return }
            self.isAwaitingConversionData = false

            if AppsFlyerManager.shared.conversionDataString != nil {
                self.performConfigRequest()
            } else {
                self.transitionToContentViewOrSavedWebView()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + conversionDataMaxWaitInterval, execute: conversionWaitWorkItem!)
    }

    private func transitionToContentViewOrSavedWebView() {
        stopOfflineNetworkMonitoring()
        removeConversionObserver()
        if ConfigManager.shared.isSavedURLValid, let url = ConfigManager.shared.savedURL {
            transitionToWebView(url: url)
        } else {
            transitionToContentView()
        }
    }

    private func transitionToWebView(url: URL) {
        stopOfflineNetworkMonitoring()
        NotificationPermissionManager.shared.shouldShowCustomNotificationScreen { [weak self] shouldShow in
            guard let self = self, !self.didFinishTransition else { return }
            self.didFinishTransition = true
            self.removeConversionObserver()
            if shouldShow {
                let notificationVC = NotificationPermissionViewController(url: url, window: self.view.window)
                self.replaceRoot(with: notificationVC)
            } else {
                self.replaceRoot(with: WebviewVC(url: url))
            }
        }
    }

    private func transitionToContentView() {
        didFinishTransition = true
        stopOfflineNetworkMonitoring()
        removeConversionObserver()
        let content = UIHostingController(rootView: ContentView())
        replaceRoot(with: content)
    }

    private func replaceRoot(with vc: UIViewController) {
        guard let window = view.window else { return }
        window.rootViewController = vc
    }
}
