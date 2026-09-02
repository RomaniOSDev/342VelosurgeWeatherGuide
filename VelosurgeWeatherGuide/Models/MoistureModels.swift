import Foundation

struct MoistureLog: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var value: Double
    var bedName: String
    var note: String
}

struct MoistureAlert: Codable, Identifiable, Hashable {
    var id: UUID
    var moistureThreshold: Double
    var kind: String
    var enabled: Bool
    var lastTriggered: Date?
    var bedName: String

    init(id: UUID, moistureThreshold: Double, kind: String, enabled: Bool, lastTriggered: Date? = nil, bedName: String = "") {
        self.id = id
        self.moistureThreshold = moistureThreshold
        self.kind = kind
        self.enabled = enabled
        self.lastTriggered = lastTriggered
        self.bedName = bedName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        moistureThreshold = try container.decode(Double.self, forKey: .moistureThreshold)
        kind = try container.decode(String.self, forKey: .kind)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        lastTriggered = try container.decodeIfPresent(Date.self, forKey: .lastTriggered)
        bedName = try container.decodeIfPresent(String.self, forKey: .bedName) ?? ""
    }
}

enum AlertKind: String, CaseIterable {
    case dry = "Too dry"
    case wet = "Too wet"
}

enum PlantKind: String, CaseIterable, Codable {
    case general = "General"
    case tomato = "Tomato"
    case greens = "Greens"
    case succulent = "Succulent"
    case herb = "Herb"
    case flower = "Flower"

    var dryBelow: Double {
        switch self {
        case .general: return 35
        case .tomato: return 40
        case .greens: return 45
        case .succulent: return 15
        case .herb: return 35
        case .flower: return 40
        }
    }

    var wetAbove: Double {
        switch self {
        case .general: return 70
        case .tomato: return 70
        case .greens: return 75
        case .succulent: return 40
        case .herb: return 65
        case .flower: return 70
        }
    }
}

struct BedProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var plantKind: String
    var dryBelow: Double
    var wetAbove: Double
}

struct WateringEvent: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var bedName: String
    var note: String
}

struct BedSnapshot: Identifiable {
    var id: String { name }
    let name: String
    let latest: MoistureLog?
    let profile: BedProfile
    let displayed: Double
    let zone: String
    let wateringHint: String
    let isAlerting: Bool
}
