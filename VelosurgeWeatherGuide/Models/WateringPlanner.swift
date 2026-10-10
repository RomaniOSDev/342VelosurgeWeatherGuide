import Foundation

enum PlanTaskKind {
    case water
    case check
    case firstReading
}

struct PlanTask: Identifiable {
    var id: String { bed }
    let bed: String
    let kind: PlanTaskKind
    let dueDate: Date
    let projectedNow: Double?
    let dryBelow: Double
    let wetAbove: Double
    let ratePerDay: Double?
    let isEstimatedRate: Bool

    var isOverdue: Bool {
        dueDate < Calendar.current.startOfDay(for: Date())
    }
}

struct ForecastPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}

extension PlantKind {
    var typicalDryRate: Double {
        switch self {
        case .general: return 6
        case .tomato: return 7
        case .greens: return 8
        case .succulent: return 2.5
        case .herb: return 5
        case .flower: return 6
        }
    }
}

private struct PlanBasis {
    let anchorDate: Date
    let anchorValue: Double
    let ratePerDay: Double?
    let isEstimatedRate: Bool

    func value(at date: Date) -> Double {
        guard let ratePerDay else { return anchorValue }
        let days = max(0, date.timeIntervalSince(anchorDate) / 86_400)
        return min(100, max(0, anchorValue - ratePerDay * days))
    }
}

extension AppDataStore {
    var wateringPlan: [PlanTask] {
        let now = Date()
        return allBedNames
            .map { planTask(for: $0, now: now) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func planTask(for bed: String, now: Date = Date()) -> PlanTask {
        let band = profile(for: bed)
        guard let basis = planBasis(for: bed) else {
            return PlanTask(
                bed: bed,
                kind: .firstReading,
                dueDate: Calendar.current.startOfDay(for: now),
                projectedNow: nil,
                dryBelow: band.dryBelow,
                wetAbove: band.wetAbove,
                ratePerDay: nil,
                isEstimatedRate: true
            )
        }

        guard let rate = basis.ratePerDay else {
            let checkDate = max(basis.anchorDate.addingTimeInterval(3 * 86_400), Calendar.current.startOfDay(for: now))
            return PlanTask(
                bed: bed,
                kind: .check,
                dueDate: checkDate,
                projectedNow: basis.anchorValue,
                dryBelow: band.dryBelow,
                wetAbove: band.wetAbove,
                ratePerDay: nil,
                isEstimatedRate: false
            )
        }

        let daysToDry = max(0, (basis.anchorValue - band.dryBelow) / rate)
        return PlanTask(
            bed: bed,
            kind: .water,
            dueDate: basis.anchorDate.addingTimeInterval(daysToDry * 86_400),
            projectedNow: basis.value(at: now),
            dryBelow: band.dryBelow,
            wetAbove: band.wetAbove,
            ratePerDay: rate,
            isEstimatedRate: basis.isEstimatedRate
        )
    }

    func planTasks(onDayOffset offset: Int, from plan: [PlanTask]) -> [PlanTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        if offset == 0 {
            return plan.filter { $0.dueDate < dayEnd }
        }
        return plan.filter { $0.dueDate >= dayStart && $0.dueDate < dayEnd }
    }

    func laterTasks(from plan: [PlanTask], afterDays days: Int = 7) -> [PlanTask] {
        let calendar = Calendar.current
        guard let limit = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date())) else { return [] }
        return plan.filter { $0.dueDate >= limit }
    }

    func moistureForecast(for bed: String, days: Int = 7) -> [ForecastPoint] {
        guard let basis = planBasis(for: bed) else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0...days * 2).compactMap { step in
            guard let date = calendar.date(byAdding: .hour, value: step * 12, to: start) else { return nil }
            return ForecastPoint(date: date, value: basis.value(at: date))
        }
    }

    var planSummary: String {
        let plan = wateringPlan
        guard !plan.isEmpty else { return "Add a bed to build a plan" }
        let today = planTasks(onDayOffset: 0, from: plan).filter { $0.kind == .water }
        if today.count == 1 { return "Water \(today[0].bed) today" }
        if today.count > 1 { return "\(today.count) beds to water today" }
        if let next = plan.first(where: { $0.kind == .water }) {
            return "Next: \(next.bed) · \(next.dueDate.formatted(.dateTime.weekday(.wide)))"
        }
        return "All beds are holding moisture"
    }

    func markWateredFromPlan(_ bed: String) {
        upsertWatering(WateringEvent(id: UUID(), timestamp: Date(), bedName: bed, note: ""))
    }

    private func planBasis(for bed: String) -> PlanBasis? {
        guard let latest = latestLog(for: bed) else { return nil }
        let band = profile(for: bed)
        let fallback = (PlantKind(rawValue: band.plantKind) ?? .general).typicalDryRate

        let measured = dryDown(for: bed)?.ratePerDay
        let rate: Double?
        let estimated: Bool
        if let measured {
            rate = measured > 0.4 ? measured : nil
            estimated = false
        } else {
            rate = fallback
            estimated = true
        }

        if let watering = lastWatering(for: bed), watering.timestamp > latest.timestamp {
            let refilled = max(band.dryBelow + 5, band.wetAbove - 5)
            return PlanBasis(
                anchorDate: watering.timestamp,
                anchorValue: max(display(latest.value), refilled),
                ratePerDay: rate ?? fallback,
                isEstimatedRate: rate == nil || estimated
            )
        }

        return PlanBasis(
            anchorDate: latest.timestamp,
            anchorValue: display(latest.value),
            ratePerDay: rate,
            isEstimatedRate: estimated
        )
    }
}
