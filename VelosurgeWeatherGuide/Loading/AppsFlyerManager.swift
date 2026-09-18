import Foundation
import AppsFlyerLib

extension Notification.Name {
    static let appsFlyerConversionDataReady = Notification.Name("appsFlyerConversionDataReady")
}

enum AppsFlyerManagerKeys {
    static let conversionDataString = "AppsFlyerConversionDataString"
    static let conversionDataUpdatedAt = "AppsFlyerConversionDataUpdatedAt"
}

final class AppsFlyerManager: NSObject {

    static let shared = AppsFlyerManager()

    private let serial = DispatchQueue(label: "appsflyer.manager.serial")

    private(set) var conversionDataString: String? {
        get {
            UserDefaults.standard.string(forKey: AppsFlyerManagerKeys.conversionDataString)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppsFlyerManagerKeys.conversionDataString)
        }
    }

    private(set) var conversionDataUpdatedAt: TimeInterval? {
        get {
            let value = UserDefaults.standard.double(forKey: AppsFlyerManagerKeys.conversionDataUpdatedAt)
            return value > 0 ? value : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: AppsFlyerManagerKeys.conversionDataUpdatedAt)
            } else {
                UserDefaults.standard.removeObject(forKey: AppsFlyerManagerKeys.conversionDataUpdatedAt)
            }
        }
    }

    func hasFreshConversionData(within seconds: TimeInterval) -> Bool {
        guard conversionDataString != nil, let updatedAt = conversionDataUpdatedAt else { return false }
        return Date().timeIntervalSince1970 - updatedAt <= seconds
    }

    private var currentConversionData: [AnyHashable: Any]?
    private var deepLinkData: [AnyHashable: Any]?
    private var conversionReady = false
    private var retryInFlight = false
    private var isOrganicRetryScheduled = false
    private var retainedOrganicPayload: [AnyHashable: Any]?
    private var didFinalizeOrganicFallback = false

    private let organicRetryDelay: TimeInterval = 5

    private override init() {
        super.init()
    }

    func handleConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        serial.async { [weak self] in
            self?.handleConversionDataSuccessLocked(installData)
        }
    }

    func handleConversionDataFail(_ error: Error?) {
    }

    func handleDeepLinkData(_ deepLinkPayload: [AnyHashable: Any]) {
        serial.async { [weak self] in
            guard let self else { return }
            self.deepLinkData = deepLinkPayload
            if self.conversionReady {
                self.persistMergedPayload(publish: false)
            }
        }
    }

    func restartConversionFetch() {
        serial.async { [weak self] in
            self?.startRetryIfNeeded()
        }
    }

    func clearConversionDataIfStale(olderThan seconds: TimeInterval) {
        serial.async { [weak self] in
            guard let self else { return }
            guard !self.hasFreshConversionData(within: seconds) else { return }
            self.clearStoredConversionStringLocked()
        }
    }

    func clearStoredConversionString() {
        serial.async { [weak self] in
            self?.clearStoredConversionStringLocked()
        }
    }

    private func handleConversionDataSuccessLocked(_ installData: [AnyHashable: Any]) {
        let status = (installData["af_status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if status == "Organic", !conversionReady {
            if !isOrganicRetryScheduled {
                retainedOrganicPayload = installData
                currentConversionData = installData
                isOrganicRetryScheduled = true
                scheduleOrganicRetryLocked()
            }
            return
        }

        applyConversionDataLocked(installData)
    }

    private func applyConversionDataLocked(_ installData: [AnyHashable: Any]) {
        currentConversionData = installData
        persistMergedPayload(publish: true)
    }

    private func scheduleOrganicRetryLocked() {
        serial.asyncAfter(deadline: .now() + organicRetryDelay) { [weak self] in
            self?.startRetryIfNeeded()
        }
    }

    private func startRetryIfNeeded() {
        guard !retryInFlight else { return }
        retryInFlight = true
        DispatchQueue.main.async { [weak self] in
            AppsFlyerLib.shared().start(completionHandler: { dictionary, error in
                self?.serial.async {
                    self?.handleRetryStartResponse(dictionary as? [AnyHashable: Any], error: error)
                }
            })
        }
    }

    private func handleRetryStartResponse(_ dictionary: [AnyHashable: Any]?, error: Error?) {
        defer {
            retryInFlight = false
            isOrganicRetryScheduled = false
        }

        if let dict = dictionary, let status = dict["af_status"] as? String, !status.isEmpty {
            applyConversionDataLocked(dict)
            return
        }

        if !conversionReady, !didFinalizeOrganicFallback, let organic = retainedOrganicPayload {
            didFinalizeOrganicFallback = true
            applyConversionDataLocked(organic)
        }
    }

    private func persistMergedPayload(publish: Bool) {
        guard currentConversionData != nil else { return }

        var merged: [String: Any] = [:]

        if let conversion = currentConversionData {
            for (key, value) in conversion {
                guard let k = key as? String else { continue }
                if merged[k] == nil {
                    merged[k] = value
                }
            }
        }

        if let udl = deepLinkData {
            for (key, value) in udl {
                guard let k = key as? String else { continue }
                if merged[k] == nil {
                    merged[k] = value
                }
            }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: merged),
              let string = String(data: jsonData, encoding: .utf8) else {
            return
        }

        conversionDataString = string
        conversionDataUpdatedAt = Date().timeIntervalSince1970

        let shouldPublish = publish && !conversionReady
        if publish {
            conversionReady = true
        }
        if shouldPublish {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .appsFlyerConversionDataReady, object: nil)
            }
        }
    }

    private func clearStoredConversionStringLocked() {
        conversionDataString = nil
        conversionDataUpdatedAt = nil
        currentConversionData = nil
        deepLinkData = nil
        conversionReady = false
        retryInFlight = false
        isOrganicRetryScheduled = false
        retainedOrganicPayload = nil
        didFinalizeOrganicFallback = false
    }
}
