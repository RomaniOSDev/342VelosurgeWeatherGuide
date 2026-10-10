import SwiftUI
import Charts

struct WateringPlanView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var selectedOffset = 0
    @State private var forecastBed = ""
    @State private var logBed: PlanBedAnchor?
    @State private var wateredBed: String?

    var body: some View {
        let plan = store.wateringPlan
        ScrollView {
            VStack(spacing: 14) {
                summaryCard(plan)

                if plan.isEmpty {
                    MeterCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NO BEDS YET")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(2)
                                .foregroundColor(AppTheme.primary)
                            Text("Log a reading for a bed and the plan will forecast when it needs water.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    weekStrip(plan)
                    dayTasks(plan)
                    laterSection(plan)
                    forecastCard(plan)
                }
            }
            .padding(18)
        }
        .screenBackdrop("BgGreenhouse")
        .navigationTitle("Watering plan")
        .sheet(item: $logBed) { anchor in
            LogFormView(presetBed: anchor.name)
                .environmentObject(store)
        }
        .onAppear {
            if forecastBed.isEmpty || !store.allBedNames.contains(forecastBed) {
                forecastBed = plan.first(where: { $0.kind != .firstReading })?.bed ?? ""
            }
        }
    }

    private func summaryCard(_ plan: [PlanTask]) -> some View {
        let today = store.planTasks(onDayOffset: 0, from: plan)
        let waterToday = today.filter { $0.kind == .water }.count
        let overdue = plan.filter { $0.kind == .water && $0.isOverdue }.count
        return MeterCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT 7 DAYS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundColor(AppTheme.primary)
                    Text(store.planSummary)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if overdue > 0 {
                        Text("\(overdue) overdue")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.accent)
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(AppTheme.surface, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: plan.isEmpty ? 0 : CGFloat(waterToday) / CGFloat(plan.count))
                        .stroke(AppTheme.meter, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(waterToday)")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(AppTheme.primary)
                        Text("today")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 70, height: 70)
            }
        }
    }

    private func weekStrip(_ plan: [PlanTask]) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
                let count = store.planTasks(onDayOffset: offset, from: plan).filter { $0.kind == .water }.count
                let isSelected = offset == selectedOffset
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedOffset = offset }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 6) {
                        Text(offset == 0 ? "Today" : date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(.headline, design: .rounded))
                        HStack(spacing: 2) {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 7))
                            }
                            if count == 0 {
                                Circle()
                                    .fill(Color.secondary.opacity(0.4))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 9)
                    }
                    .foregroundColor(isSelected ? AppTheme.background : (count > 0 ? AppTheme.primary : .secondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(AppTheme.meter) : AnyShapeStyle(AppTheme.surface.opacity(0.6)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.primary.opacity(count > 0 && !isSelected ? 0.5 : 0), lineWidth: 1)
                    )
                }
                .buttonStyle(GaugePressStyle())
            }
        }
    }

    @ViewBuilder
    private func dayTasks(_ plan: [PlanTask]) -> some View {
        let tasks = store.planTasks(onDayOffset: selectedOffset, from: plan)
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(selectedOffset == 0 ? "TODAY" : dayTitle(selectedOffset))
            if tasks.isEmpty {
                MeterCard {
                    HStack(spacing: 12) {
                        SoilMark(icon: "leaf.fill")
                        Text(selectedOffset == 0 ? "Nothing to water today. Beds are in range." : "No waterings forecast for this day.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                ForEach(tasks) { task in
                    taskCard(task)
                }
            }
        }
    }

    @ViewBuilder
    private func laterSection(_ plan: [PlanTask]) -> some View {
        let later = store.laterTasks(from: plan)
        if !later.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("LATER")
                MeterCard {
                    VStack(spacing: 10) {
                        ForEach(later) { task in
                            HStack {
                                Text(task.bed)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Spacer()
                                Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func taskCard(_ task: PlanTask) -> some View {
        MeterCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    SoilWick(value: task.projectedNow ?? 0, width: 12, height: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.bed)
                            .font(.system(.headline, design: .rounded))
                        Text(detailLine(task))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let rate = task.ratePerDay {
                            Text("Drying \(String(format: "%.1f", rate))%/day\(task.isEstimatedRate ? " · estimated" : "")")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: icon(for: task))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(task.isOverdue ? AppTheme.accent : AppTheme.primary)
                        Text(dueLabel(task))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(task.isOverdue ? AppTheme.accent : AppTheme.primary)
                    }
                }
                HStack(spacing: 10) {
                    if task.kind == .water {
                        Button(wateredBed == task.bed ? "Done" : "Watered") {
                            store.markWateredFromPlan(task.bed)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation { wateredBed = task.bed }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if wateredBed == task.bed { wateredBed = nil }
                            }
                        }
                    }
                    Button(task.kind == .firstReading ? "First reading" : "Log reading") {
                        logBed = PlanBedAnchor(name: task.bed)
                    }
                    Spacer()
                }
                .buttonStyle(SoilChipStyle())
            }
        }
    }

    private func forecastCard(_ plan: [PlanTask]) -> some View {
        let beds = plan.filter { $0.kind != .firstReading }.map(\.bed)
        let points = store.moistureForecast(for: forecastBed)
        let band = store.profile(for: forecastBed)
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("MOISTURE FORECAST")
            MeterCard {
                VStack(alignment: .leading, spacing: 12) {
                    if beds.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(beds, id: \.self) { bed in
                                    Button(bed) {
                                        withAnimation(.easeInOut(duration: 0.25)) { forecastBed = bed }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(forecastBed == bed ? AppTheme.primary.opacity(0.35) : AppTheme.surface, in: Capsule())
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    } else if let only = beds.first {
                        Text(only)
                            .font(.system(.headline, design: .rounded))
                    }

                    if points.isEmpty {
                        Text("Log a reading to see the forecast.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        Chart {
                            RuleMark(y: .value("Dry", band.dryBelow))
                                .foregroundStyle(AppTheme.accent.opacity(0.8))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("dry \(Int(band.dryBelow))%")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.accent)
                                }
                            RuleMark(y: .value("Wet", band.wetAbove))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                            ForEach(points) { point in
                                AreaMark(
                                    x: .value("Day", point.date),
                                    y: .value("Moisture", point.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.primary.opacity(0.35), AppTheme.primary.opacity(0.02)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.monotone)
                                LineMark(
                                    x: .value("Day", point.date),
                                    y: .value("Moisture", point.value)
                                )
                                .foregroundStyle(AppTheme.primary)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .interpolationMethod(.monotone)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 50, 100]) { _ in
                                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 180)

                        Text(forecastCaption(for: forecastBed))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(3)
            .foregroundColor(AppTheme.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayTitle(_ offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased()
    }

    private func detailLine(_ task: PlanTask) -> String {
        switch task.kind {
        case .firstReading:
            return "No readings yet · forecast starts after the first one"
        case .check:
            return "~\(Int(task.projectedNow ?? 0))% · holding moisture, check soon"
        case .water:
            return "~\(Int((task.projectedNow ?? 0).rounded()))% now · dry line \(Int(task.dryBelow))%"
        }
    }

    private func dueLabel(_ task: PlanTask) -> String {
        let calendar = Calendar.current
        if task.isOverdue {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: task.dueDate), to: calendar.startOfDay(for: Date())).day ?? 0
            return "\(max(1, days))d late"
        }
        if calendar.isDateInToday(task.dueDate) { return task.kind == .water ? "Water" : "Today" }
        if calendar.isDateInTomorrow(task.dueDate) { return "Tomorrow" }
        return task.dueDate.formatted(.dateTime.weekday(.abbreviated))
    }

    private func icon(for task: PlanTask) -> String {
        switch task.kind {
        case .water: return task.isOverdue ? "exclamationmark.triangle.fill" : "drop.fill"
        case .check: return "eye.fill"
        case .firstReading: return "plus.circle.fill"
        }
    }

    private func forecastCaption(for bed: String) -> String {
        let task = store.planTask(for: bed)
        switch task.kind {
        case .firstReading:
            return "Log a reading to start the forecast."
        case .check:
            return "\(bed) is holding moisture. Take a reading in a few days."
        case .water:
            if task.isOverdue || Calendar.current.isDateInToday(task.dueDate) {
                return "\(bed) is at the dry line. Water today."
            }
            return "\(bed) reaches \(Int(task.dryBelow))% around \(task.dueDate.formatted(.dateTime.weekday(.wide).hour()))."
        }
    }
}

private struct PlanBedAnchor: Identifiable {
    var id: String { name }
    let name: String
}
