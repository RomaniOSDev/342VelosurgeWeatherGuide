import Foundation
import Combine

extension Notification.Name {
    static let dataReset = Notification.Name("dataReset")
}

@MainActor
final class AppDataStore: ObservableObject {
    static let shared = AppDataStore()

    @Published var moistureLogs: [MoistureLog] = []
    @Published var alerts: [MoistureAlert] = []
    @Published var wateringEvents: [WateringEvent] = []
    @Published var bedProfiles: [BedProfile] = []
    @Published var graphRange: String = "week"
    @Published var lastAlertTime: Date?
    @Published var calibrationOffset: Double = 0
    @Published var reminderEnabled = false
    @Published var reminderHour = 9
    @Published var reminderMinute = 0
    @Published var lastBedName = ""
    @Published var lastMoistureValue: Double = 40
    @Published var checkHoursAfterWatering = 24

    private let defaults = UserDefaults.standard
    private let logsKey = "moistureLogs"
    private let alertsKey = "alerts"
    private let rangeKey = "graphRange"
    private let lastAlertKey = "lastAlertTime"
    private let wateringKey = "wateringEvents"
    private let profilesKey = "bedProfiles"
    private let calibrationKey = "calibrationOffset"
    private let reminderEnabledKey = "reminderEnabled"
    private let reminderHourKey = "reminderHour"
    private let reminderMinuteKey = "reminderMinute"
    private let lastBedKey = "lastBedName"
    private let lastValueKey = "lastMoistureValue"
    private let checkHoursKey = "checkHoursAfterWatering"

    private init() {
        load()
        if reminderEnabled {
            AppNotify.scheduleReminder(enabled: true, hour: reminderHour, minute: reminderMinute)
        }
    }

    func load() {
        moistureLogs = (decode([MoistureLog].self, key: logsKey) ?? []).sorted { $0.timestamp > $1.timestamp }
        alerts = decode([MoistureAlert].self, key: alertsKey) ?? []
        wateringEvents = (decode([WateringEvent].self, key: wateringKey) ?? []).sorted { $0.timestamp > $1.timestamp }
        bedProfiles = decode([BedProfile].self, key: profilesKey) ?? []
        graphRange = defaults.string(forKey: rangeKey) ?? "week"
        lastAlertTime = defaults.object(forKey: lastAlertKey) as? Date
        calibrationOffset = defaults.object(forKey: calibrationKey) as? Double ?? 0
        reminderEnabled = defaults.bool(forKey: reminderEnabledKey)
        reminderHour = defaults.object(forKey: reminderHourKey) as? Int ?? 9
        reminderMinute = defaults.object(forKey: reminderMinuteKey) as? Int ?? 0
        lastBedName = defaults.string(forKey: lastBedKey) ?? ""
        lastMoistureValue = defaults.object(forKey: lastValueKey) as? Double ?? 40
        checkHoursAfterWatering = defaults.object(forKey: checkHoursKey) as? Int ?? 24
    }

    func save() {
        encode(moistureLogs, key: logsKey)
        encode(alerts, key: alertsKey)
        encode(wateringEvents, key: wateringKey)
        encode(bedProfiles, key: profilesKey)
        defaults.set(graphRange, forKey: rangeKey)
        defaults.set(lastAlertTime, forKey: lastAlertKey)
        defaults.set(calibrationOffset, forKey: calibrationKey)
        defaults.set(reminderEnabled, forKey: reminderEnabledKey)
        defaults.set(reminderHour, forKey: reminderHourKey)
        defaults.set(reminderMinute, forKey: reminderMinuteKey)
        defaults.set(lastBedName, forKey: lastBedKey)
        defaults.set(lastMoistureValue, forKey: lastValueKey)
        defaults.set(checkHoursAfterWatering, forKey: checkHoursKey)
    }

    func display(_ raw: Double) -> Double {
        min(100, max(0, raw + calibrationOffset))
    }

    func upsertLog(_ log: MoistureLog) -> String? {
        if moistureLogs.contains(where: { $0.id != log.id && abs($0.timestamp.timeIntervalSince(log.timestamp)) < 30 && $0.bedName == log.bedName }) {
            return "Another reading already exists for this bed at that time."
        }
        if let index = moistureLogs.firstIndex(where: { $0.id == log.id }) {
            moistureLogs[index] = log
        } else {
            moistureLogs.insert(log, at: 0)
        }
        moistureLogs.sort { $0.timestamp > $1.timestamp }
        lastBedName = log.bedName
        lastMoistureValue = log.value
        ensureProfile(name: log.bedName, plantKind: nil)
        evaluateAlerts(for: log)
        save()
        return nil
    }

    func deleteLog(_ id: UUID) {
        moistureLogs.removeAll { $0.id == id }
        save()
    }

    func upsertAlert(_ alert: MoistureAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index] = alert
        } else {
            alerts.append(alert)
        }
        save()
    }

    func deleteAlert(_ id: UUID) {
        alerts.removeAll { $0.id == id }
        save()
    }

    func upsertWatering(_ event: WateringEvent) {
        if let index = wateringEvents.firstIndex(where: { $0.id == event.id }) {
            wateringEvents[index] = event
        } else {
            wateringEvents.insert(event, at: 0)
        }
        wateringEvents.sort { $0.timestamp > $1.timestamp }
        ensureProfile(name: event.bedName, plantKind: nil)
        if checkHoursAfterWatering > 0 {
            AppNotify.scheduleWaterCheck(bed: event.bedName, hours: checkHoursAfterWatering)
        }
        save()
    }

    func deleteWatering(_ id: UUID) {
        wateringEvents.removeAll { $0.id == id }
        save()
    }

    func upsertProfile(_ profile: BedProfile) {
        if let index = bedProfiles.firstIndex(where: { $0.id == profile.id || $0.name == profile.name }) {
            bedProfiles[index] = BedProfile(id: bedProfiles[index].id, name: profile.name, plantKind: profile.plantKind, dryBelow: profile.dryBelow, wetAbove: profile.wetAbove)
        } else {
            bedProfiles.append(profile)
        }
        save()
    }

    func ensureProfile(name: String, plantKind: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let index = bedProfiles.firstIndex(where: { $0.name == trimmed }) {
            if let plantKind, bedProfiles[index].plantKind != plantKind, let kind = PlantKind(rawValue: plantKind) {
                bedProfiles[index].plantKind = kind.rawValue
                bedProfiles[index].dryBelow = kind.dryBelow
                bedProfiles[index].wetAbove = kind.wetAbove
            }
            return
        }
        let kind = PlantKind(rawValue: plantKind ?? "") ?? .general
        bedProfiles.append(BedProfile(id: UUID(), name: trimmed, plantKind: kind.rawValue, dryBelow: kind.dryBelow, wetAbove: kind.wetAbove))
    }

    func profile(for name: String) -> BedProfile {
        if let existing = bedProfiles.first(where: { $0.name == name }) { return existing }
        let kind = PlantKind.general
        return BedProfile(id: UUID(), name: name, plantKind: kind.rawValue, dryBelow: kind.dryBelow, wetAbove: kind.wetAbove)
    }

    func applyPlantKind(_ kind: PlantKind, to name: String) {
        var item = profile(for: name)
        item.plantKind = kind.rawValue
        item.dryBelow = kind.dryBelow
        item.wetAbove = kind.wetAbove
        upsertProfile(item)
    }

    var latest: MoistureLog? { moistureLogs.first }

    func latestLog(for bed: String) -> MoistureLog? {
        moistureLogs.first { $0.bedName == bed }
    }

    var allBedNames: [String] {
        let names = moistureLogs.map(\.bedName) + bedProfiles.map(\.name) + wateringEvents.map(\.bedName)
        return Array(Set(names.filter { !$0.isEmpty })).sorted()
    }

    func zoneLabel(for log: MoistureLog) -> String {
        zoneLabel(value: display(log.value), bed: log.bedName)
    }

    func zoneLabel(value: Double, bed: String) -> String {
        let band = profile(for: bed)
        if value < band.dryBelow { return "Dry" }
        if value > band.wetAbove { return "Saturated" }
        return "Optimal"
    }

    var breachedAlerts: [MoistureAlert] {
        guard let latest else { return [] }
        return alertsMatching(log: latest)
    }

    func alertsMatching(log: MoistureLog) -> [MoistureAlert] {
        let value = display(log.value)
        return alerts.filter { alert in
            guard alert.enabled else { return false }
            if !alert.bedName.isEmpty && alert.bedName != log.bedName { return false }
            if alert.kind == AlertKind.dry.rawValue {
                return value < alert.moistureThreshold
            }
            return value > alert.moistureThreshold
        }
    }

    var bedSnapshots: [BedSnapshot] {
        allBedNames.map { name in
            let log = latestLog(for: name)
            let shown = display(log?.value ?? 0)
            return BedSnapshot(
                name: name,
                latest: log,
                profile: profile(for: name),
                displayed: shown,
                zone: zoneLabel(value: shown, bed: name),
                wateringHint: wateringHint(for: name),
                isAlerting: log.map { !alertsMatching(log: $0).isEmpty } ?? false
            )
        }
        .sorted { ($0.latest?.timestamp ?? .distantPast) > ($1.latest?.timestamp ?? .distantPast) }
    }

    func logs(in range: String, periodOffset: Int = 0) -> [MoistureLog] {
        let days = range == "month" ? 30 : (range == "quarter" ? 90 : 7)
        let calendar = Calendar.current
        let end = periodOffset == 0 ? Date() : (calendar.date(byAdding: .day, value: -days * periodOffset, to: Date()) ?? Date())
        let start = calendar.date(byAdding: .day, value: -days * (periodOffset + 1), to: Date()) ?? Date()
        return moistureLogs.filter { $0.timestamp >= start && $0.timestamp <= end }.sorted { $0.timestamp < $1.timestamp }
    }

    func evaluateAlerts(for log: MoistureLog) {
        let value = display(log.value)
        var didNotify = false
        for index in alerts.indices where alerts[index].enabled {
            let alert = alerts[index]
            if !alert.bedName.isEmpty && alert.bedName != log.bedName { continue }
            let hit = alert.kind == AlertKind.dry.rawValue ? value < alert.moistureThreshold : value > alert.moistureThreshold
            guard hit else { continue }
            lastAlertTime = Date()
            let cooldown: TimeInterval = 6 * 3600
            let stale = alert.lastTriggered.map { Date().timeIntervalSince($0) > cooldown } ?? true
            if stale {
                alerts[index].lastTriggered = Date()
                AppNotify.fireThreshold(bed: log.bedName, kind: alert.kind, percent: Int(value.rounded()))
                didNotify = true
            }
        }
        if !didNotify {
            let band = profile(for: log.bedName)
            let dryHit = value < band.dryBelow
            let wetHit = value > band.wetAbove
            if dryHit || wetHit {
                lastAlertTime = Date()
            }
        }
    }

    func lastWatering(for bed: String) -> WateringEvent? {
        wateringEvents.first { $0.bedName == bed }
    }

    func dryDown(for bed: String) -> (ratePerDay: Double, daysUntilDry: Double?)? {
        let readings = moistureLogs.filter { $0.bedName == bed }.sorted { $0.timestamp < $1.timestamp }
        let startDate = lastWatering(for: bed)?.timestamp
        let window = startDate.map { watered in readings.filter { $0.timestamp >= watered } } ?? readings.suffix(6).map { $0 }
        guard window.count >= 2 else { return nil }
        let first = window.first!
        let last = window.last!
        let days = last.timestamp.timeIntervalSince(first.timestamp) / 86_400
        guard days > 0.2 else { return nil }
        let rate = (display(first.value) - display(last.value)) / days
        let band = profile(for: bed)
        let current = display(latestLog(for: bed)?.value ?? last.value)
        let daysUntil = rate > 0.4 ? max(0, (current - band.dryBelow) / rate) : nil
        return (rate, daysUntil)
    }

    func wateringHint(for bed: String) -> String {
        if let result = dryDown(for: bed) {
            let rateText = "Drying \(abs(Int(result.ratePerDay.rounded())))%/day"
            if result.ratePerDay < 0 {
                return "Holding moisture · \(rateText.replacingOccurrences(of: "Drying ", with: "Rising "))"
            }
            if let days = result.daysUntilDry {
                if days < 0.5 { return "\(rateText) · water now" }
                return "\(rateText) · water in \(max(1, Int(days.rounded())))d"
            }
            return rateText
        }
        if let watering = lastWatering(for: bed) {
            return "Watered \(watering.timestamp.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Log a watering to track dry-down"
    }

    func applyReminderSettings() {
        save()
        AppNotify.scheduleReminder(enabled: reminderEnabled, hour: reminderHour, minute: reminderMinute)
    }

    var trendInsight: String {
        let week = logs(in: "week")
        guard week.count >= 2 else { return "Log a few readings to see dry or wet patterns." }
        let avg = week.map { display($0.value) }.reduce(0, +) / Double(week.count)
        if avg < 35 { return "Beds are trending dry this week. Water sooner." }
        if avg > 70 { return "Beds are staying wet. Hold off on extra watering." }
        return "Moisture is holding in a balanced band this week."
    }

    func resetAllData() {
        [logsKey, alertsKey, rangeKey, lastAlertKey, wateringKey, profilesKey, calibrationKey, reminderEnabledKey, reminderHourKey, reminderMinuteKey, lastBedKey, lastValueKey, checkHoursKey].forEach { defaults.removeObject(forKey: $0) }
        moistureLogs = []
        alerts = []
        wateringEvents = []
        bedProfiles = []
        graphRange = "week"
        lastAlertTime = nil
        calibrationOffset = 0
        reminderEnabled = false
        reminderHour = 9
        reminderMinute = 0
        lastBedName = ""
        lastMoistureValue = 40
        checkHoursAfterWatering = 24
        AppNotify.cancelAll()
        NotificationCenter.default.post(name: .dataReset, object: nil)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
