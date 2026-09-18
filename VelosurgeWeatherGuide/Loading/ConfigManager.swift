import Foundation
import AppsFlyerLib

struct ConfigResponse {
    let ok: Bool
    let url: String?
    let expires: Int64?
    let message: String?
}

enum ConfigManagerKeys {
    static let savedRecord = "ConfigManagerStoredConfig"
    static let savedURL = "ConfigManagerSavedURL"
    static let savedExpires = "ConfigManagerSavedExpires"
}

enum ConfigManagerOptionalData {
    static var pushToken: String?
    static var firebaseProjectId: String?
}

final class ConfigManager {

    static let shared = ConfigManager()

    var configEndpointURL: URL? = URL(string: "https://velosurgeweatherguide.com/config.php")

    var storeId: String = "id6807215460"

    private init() {
        migrateLegacyKeysIfNeeded()
    }

    var savedURL: URL? {
        storedConfig?.url
    }

    var savedExpires: Int64? {
        storedConfig?.expires
    }

    var isSavedURLValid: Bool {
        guard let record = storedConfig else { return false }
        guard record.expires > Int64(Date().timeIntervalSince1970) else {
            clearStoredConfig()
            return false
        }
        return true
    }

    private var storedConfig: StoredConfig? {
        guard let data = UserDefaults.standard.data(forKey: ConfigManagerKeys.savedRecord) else {
            return nil
        }
        guard let record = try? JSONDecoder().decode(StoredConfig.self, from: data) else {
            clearStoredConfig()
            return nil
        }
        return record
    }

    func buildRequestBody() -> Data? {
        var body: [String: Any] = [:]

        if let conversionString = AppsFlyerManager.shared.conversionDataString,
           let data = conversionString.data(using: .utf8),
           let conversion = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in conversion {
                body[key] = value
            }
        }

        if body["af_id"] == nil {
            body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        }
        if body["bundle_id"] == nil {
            body["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        }
        if body["os"] == nil {
            body["os"] = "iOS"
        }
        if body["store_id"] == nil {
            body["store_id"] = storeId
        }
        if body["locale"] == nil {
            body["locale"] = Locale.current.identifier
        }
        if let token = ConfigManagerOptionalData.pushToken, body["push_token"] == nil {
            body["push_token"] = token
        }
        if let projectId = ConfigManagerOptionalData.firebaseProjectId, body["firebase_project_id"] == nil {
            body["firebase_project_id"] = projectId
        }

        return try? JSONSerialization.data(withJSONObject: body)
    }

    func requestConfig(completion: @escaping (Result<ConfigResponse, Error>) -> Void) {
        guard let endpoint = configEndpointURL else {
            completion(.failure(ConfigError.missingEndpoint))
            return
        }
        guard let body = buildRequestBody() else {
            completion(.failure(ConfigError.failedToBuildBody))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            let parsed = self?.parseConfigResponse(data: data, statusCode: statusCode) ?? .failure(ConfigError.invalidResponse)
            if case .success(let config) = parsed,
               config.ok,
               let url = config.url,
               let expires = config.expires,
               URL(string: url) != nil {
                self?.saveStoredConfig(urlString: url, expires: expires)
            }
            DispatchQueue.main.async {
                switch parsed {
                case .success(let c):
                    completion(.success(c))
                case .failure(let e):
                    completion(.failure(e))
                }
            }
        }
        task.resume()
    }

    private func parseConfigResponse(data: Data?, statusCode: Int) -> Result<ConfigResponse, Error> {
        guard statusCode == 200 else {
            return .failure(ConfigError.invalidResponse)
        }
        guard let data else {
            return .failure(ConfigError.invalidResponse)
        }
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ConfigPayload.self, from: data) else {
            return .failure(ConfigError.invalidResponse)
        }
        let expires = payload.expires?.int64Value
        let url = payload.url?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidURL = url.flatMap { URL(string: $0) } != nil
        let ok = payload.ok && hasValidURL && expires != nil
        return .success(
            ConfigResponse(
                ok: ok,
                url: url,
                expires: expires,
                message: payload.message
            )
        )
    }

    private func saveStoredConfig(urlString: String, expires: Int64) {
        guard let url = URL(string: urlString) else { return }
        let record = StoredConfig(url: url, expires: expires)
        guard let data = try? JSONEncoder().encode(record) else { return }
        UserDefaults.standard.set(data, forKey: ConfigManagerKeys.savedRecord)
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedURL)
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedExpires)
    }

    private func clearStoredConfig() {
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedRecord)
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedURL)
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedExpires)
    }

    private func migrateLegacyKeysIfNeeded() {
        if storedConfig != nil {
            UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedURL)
            UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedExpires)
            return
        }
        let rawURL = UserDefaults.standard.string(forKey: ConfigManagerKeys.savedURL)
        let expires = UserDefaults.standard.object(forKey: ConfigManagerKeys.savedExpires) as? Int64
            ?? (UserDefaults.standard.object(forKey: ConfigManagerKeys.savedExpires) as? Int).map { Int64($0) }
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedURL)
        UserDefaults.standard.removeObject(forKey: ConfigManagerKeys.savedExpires)
        guard let rawURL, let url = URL(string: rawURL), let expires, expires > 0 else { return }
        saveStoredConfig(urlString: url.absoluteString, expires: expires)
    }
}

private struct StoredConfig: Codable {
    let url: URL
    let expires: Int64
}

private struct ConfigPayload: Decodable {
    let ok: Bool
    let url: String?
    let expires: FlexibleExpires?
    let message: String?
}

private enum FlexibleExpires: Decodable {
    case int(Int64)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int64.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(Int64(value))
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "expires")
    }

    var int64Value: Int64? {
        switch self {
        case .int(let value):
            return value
        case .string(let raw):
            return Int64(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

enum ConfigError: LocalizedError {
    case missingEndpoint
    case failedToBuildBody
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .missingEndpoint: return "Config endpoint URL not set"
        case .failedToBuildBody: return "Failed to build request body"
        case .invalidResponse: return "Invalid config response"
        }
    }
}
