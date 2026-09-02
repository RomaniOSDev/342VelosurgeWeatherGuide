import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var selected: MoistureLog?
    @State private var bedFilter = "All"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Range", selection: $store.graphRange) {
                    Text("Week").tag("week")
                    Text("Month").tag("month")
                    Text("Quarter").tag("quarter")
                }
                .pickerStyle(.segmented)
                .onChange(of: store.graphRange) { _ in
                    store.save()
                    if bedFilter != "All", !bedNames.contains(bedFilter) {
                        bedFilter = "All"
                    }
                }

                if bedNames.count > 1 {
                    Picker("Bed", selection: $bedFilter) {
                        Text("All beds").tag("All")
                        ForEach(bedNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)
                }

                if data.isEmpty {
                    MeterCard {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(AppTheme.primary)
                            Text("No Data Available")
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                } else {
                    statsGrid
                    comparisonCard
                    dryDownCard
                    moistureChart
                    if bedStats.count > 1 {
                        bedChart
                    }
                    zoneChart
                    MeterCard {
                        Text(insight)
                            .font(.headline)
                    }
                    ForEach(data.reversed()) { item in
                        Button {
                            selected = item
                        } label: {
                            MeterCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.bedName).foregroundColor(.primary)
                                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(store.display(item.value)))%")
                                        .font(.body.monospacedDigit())
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .screenBackdrop("BgGreenhouse")
        .navigationTitle("Statistics")
        .sheet(item: $selected) { item in
            LogFormView(existing: item)
                .environmentObject(store)
        }
    }

    private var rangedLogs: [MoistureLog] {
        store.logs(in: store.graphRange)
    }

    private var bedNames: [String] {
        Array(Set(rangedLogs.map(\.bedName))).sorted()
    }

    private var data: [MoistureLog] {
        if bedFilter == "All" { return rangedLogs }
        return rangedLogs.filter { $0.bedName == bedFilter }
    }

    private var values: [Double] { data.map { store.display($0.value) } }

    private var average: Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var driest: Double { values.min() ?? 0 }
    private var wettest: Double { values.max() ?? 0 }

    private var previous: [MoistureLog] {
        let logs = store.logs(in: store.graphRange, periodOffset: 1)
        if bedFilter == "All" { return logs }
        return logs.filter { $0.bedName == bedFilter }
    }

    private var previousAverage: Double {
        guard !previous.isEmpty else { return 0 }
        return previous.map { store.display($0.value) }.reduce(0, +) / Double(previous.count)
    }

    private var showsSeparateBeds: Bool {
        bedFilter == "All" && Set(data.map(\.bedName)).count > 1
    }

    private var insight: String {
        guard data.count >= 2 else { return "Log a few readings to see dry or wet patterns." }
        if average < 35 { return "Beds are trending dry. Water sooner." }
        if average > 70 { return "Beds are staying wet. Hold off on extra watering." }
        return "Moisture is holding in a balanced band."
    }

    private var bedStats: [BedStat] {
        Dictionary(grouping: data, by: \.bedName)
            .map { name, logs in
                BedStat(
                    name: name,
                    average: logs.map { store.display($0.value) }.reduce(0, +) / Double(logs.count),
                    count: logs.count
                )
            }
            .sorted { $0.average < $1.average }
    }

    private var zoneStats: [ZoneStat] {
        [
            ZoneStat(name: "Dry", count: data.filter { store.zoneLabel(for: $0) == "Dry" }.count),
            ZoneStat(name: "Optimal", count: data.filter { store.zoneLabel(for: $0) == "Optimal" }.count),
            ZoneStat(name: "Saturated", count: data.filter { store.zoneLabel(for: $0) == "Saturated" }.count)
        ]
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Readings", value: "\(data.count)")
            StatTile(title: "Average", value: "\(Int(average.rounded()))%")
            StatTile(title: "Driest", value: "\(Int(driest))%")
            StatTile(title: "Wettest", value: "\(Int(wettest))%")
        }
    }

    private var comparisonCard: some View {
        Group {
            if !previous.isEmpty {
                MeterCard {
                    let delta = average - previousAverage
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Versus previous period")
                            .font(.headline)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This").font(.caption).foregroundColor(.secondary)
                                Text("\(Int(average.rounded()))%")
                                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Previous").font(.caption).foregroundColor(.secondary)
                                Text("\(Int(previousAverage.rounded()))%")
                                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Change").font(.caption).foregroundColor(.secondary)
                                Text("\(delta >= 0 ? "+" : "")\(Int(delta.rounded()))%")
                                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                                    .foregroundColor(delta >= 0 ? AppTheme.primary : AppTheme.accent)
                            }
                        }
                        Text(delta < -4 ? "Drier than last period. Water sooner." : (delta > 4 ? "Wetter than last period. Hold extra watering." : "Moisture is close to the previous period."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var dryDownCard: some View {
        Group {
            if bedFilter != "All" {
                MeterCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dry-down")
                            .font(.headline)
                        Text(store.wateringHint(for: bedFilter))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var moistureChart: some View {
        MeterCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Moisture over time")
                    .font(.headline)
                Chart {
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(AppTheme.accent.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    if showsSeparateBeds {
                        ForEach(data) { item in
                            LineMark(
                                x: .value("When", item.timestamp),
                                y: .value("Moisture", store.display(item.value))
                            )
                            .foregroundStyle(by: .value("Bed", item.bedName))
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("When", item.timestamp),
                                y: .value("Moisture", store.display(item.value))
                            )
                            .foregroundStyle(by: .value("Bed", item.bedName))
                        }
                    } else {
                        ForEach(data) { item in
                            AreaMark(
                                x: .value("When", item.timestamp),
                                y: .value("Moisture", store.display(item.value))
                            )
                            .foregroundStyle(AppTheme.primary.opacity(0.22))
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("When", item.timestamp),
                                y: .value("Moisture", store.display(item.value))
                            )
                            .foregroundStyle(AppTheme.primary)
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("When", item.timestamp),
                                y: .value("Moisture", store.display(item.value))
                            )
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 35, 70, 100])
                }
                .frame(height: 220)
            }
        }
    }

    private var bedChart: some View {
        MeterCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Average by bed")
                    .font(.headline)
                Chart(bedStats) { stat in
                    BarMark(
                        x: .value("Average", stat.average),
                        y: .value("Bed", stat.name)
                    )
                    .foregroundStyle(AppTheme.primary)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text("\(Int(stat.average.rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .chartXScale(domain: 0...100)
                .frame(height: max(160, CGFloat(bedStats.count) * 44))
            }
        }
    }

    private var zoneChart: some View {
        MeterCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Moisture zones")
                    .font(.headline)
                Chart(zoneStats) { stat in
                    BarMark(
                        x: .value("Zone", stat.name),
                        y: .value("Readings", stat.count)
                    )
                    .foregroundStyle(by: .value("Zone", stat.name))
                    .cornerRadius(5)
                }
                .chartForegroundStyleScale([
                    "Dry": AppTheme.accent,
                    "Optimal": AppTheme.primary,
                    "Saturated": Color.cyan
                ])
                .chartLegend(.hidden)
                .frame(height: 180)
            }
        }
    }
}

private struct BedStat: Identifiable {
    var id: String { name }
    let name: String
    let average: Double
    let count: Int
}

private struct ZoneStat: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        MeterCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundColor(AppTheme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
