import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppDataStore.shared
    @State private var showLog = false
    @State private var showSettings = false
    @State private var showWateringForm = false
    @State private var savedFlash = false
    @State private var presetBed: String?
    @State private var waterPreset = ""
    @State private var editingProfile: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    MoistureGauge(
                        value: store.display(store.latest?.value ?? 0),
                        zoneLabel: store.latest.map { store.zoneLabel(for: $0) }
                    )
                    .overlay {
                        if savedFlash {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.primary)
                                .shadow(color: .black.opacity(0.4), radius: 6)
                        }
                    }

                    if store.moistureLogs.isEmpty && store.bedSnapshots.isEmpty {
                        MeterCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NO CORE YET")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(2)
                                    .foregroundColor(AppTheme.primary)
                                Text("Log the first moisture reading to start a soil core for this greenhouse.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        ForEach(store.bedSnapshots) { snap in
                            bedCard(snap)
                        }
                    }

                    MeterButton(title: "Log reading", icon: "plus.circle.fill") {
                        presetBed = nil
                        showLog = true
                    }
                    .accessibilityIdentifier("log_reading")

                    if !store.lastBedName.isEmpty {
                        MeterButton(title: "Log \(store.lastBedName) again", icon: "arrow.triangle.2.circlepath") {
                            presetBed = store.lastBedName
                            showLog = true
                        }
                    }

                    VStack(spacing: 10) {
                        NavigationLink {
                            LogHistoryView()
                        } label: {
                            navRow("History", "clock.arrow.circlepath", "\(store.moistureLogs.count) readings")
                        }
                        NavigationLink {
                            WateringView()
                        } label: {
                            navRow("Watering", "drop.fill", store.wateringEvents.isEmpty ? "No waterings yet" : "\(store.wateringEvents.count) logged")
                        }
                        NavigationLink {
                            AlertsView()
                        } label: {
                            navRow("Thresholds", "bell.badge", store.alerts.isEmpty ? "None set" : "\(store.alerts.count) active")
                        }
                        NavigationLink {
                            TrendsView()
                        } label: {
                            navRow("Statistics", "chart.xyaxis.line", store.trendInsight)
                        }
                    }
                }
                .padding(18)
            }
            .screenBackdrop("BgGreenhouse")
            .navigationTitle("Soil")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .sheet(isPresented: $showLog) {
                LogFormView(presetBed: presetBed) { success in
                    if success {
                        savedFlash = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { savedFlash = false }
                    }
                }
                .id(presetBed ?? "new-reading")
                .environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showWateringForm) {
                WateringFormView(presetBed: waterPreset)
                    .id(waterPreset)
                    .environmentObject(store)
            }
            .sheet(item: Binding(
                get: { editingProfile.map { ProfileAnchor(name: $0) } },
                set: { editingProfile = $0?.name }
            )) { anchor in
                BedProfileSheet(name: anchor.name)
                    .environmentObject(store)
            }
            .onAppear {
                if store.reminderEnabled || store.alerts.contains(where: \.enabled) {
                    AppNotify.requestAccess { _ in }
                }
            }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.dark)
        .environmentObject(store)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GREENHOUSE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundColor(AppTheme.primary)
            Rectangle()
                .fill(AppTheme.primary)
                .frame(width: 40, height: 2)
            Text("Read the core.")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bedCard(_ snap: BedSnapshot) -> some View {
        MeterCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    SoilWick(value: snap.displayed, width: 12, height: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snap.name)
                            .font(.system(.headline, design: .rounded))
                        Text("\(snap.profile.plantKind) · \(Int(snap.profile.dryBelow))–\(Int(snap.profile.wetAbove))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let latest = snap.latest {
                            Text(latest.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        } else {
                            Text("No reading yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(snap.displayed))%")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(AppTheme.primary)
                        Text(snap.zone)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(snap.zone == "Optimal" ? .secondary : AppTheme.accent)
                    }
                }
                Text(snap.wateringHint)
                    .font(.system(.subheadline, design: .rounded))
                if snap.isAlerting, let latest = snap.latest {
                    Text("Alert: \(store.alertsMatching(log: latest).map(\.kind).joined(separator: ", "))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primary)
                }
                HStack(spacing: 10) {
                    Button("Log") {
                        presetBed = snap.name
                        showLog = true
                    }
                    Button("Watered") {
                        waterPreset = snap.name
                        showWateringForm = true
                    }
                    Button("Profile") { editingProfile = snap.name }
                    Spacer()
                }
                .buttonStyle(SoilChipStyle())
            }
        }
    }

    private func navRow(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        MeterCard {
            HStack(spacing: 12) {
                SoilMark(icon: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Rectangle()
                    .fill(AppTheme.primary)
                    .frame(width: 14, height: 2)
            }
        }
    }
}

private struct ProfileAnchor: Identifiable {
    var id: String { name }
    let name: String
}
