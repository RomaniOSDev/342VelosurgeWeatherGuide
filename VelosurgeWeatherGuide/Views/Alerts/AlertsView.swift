import SwiftUI

struct AlertsView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var showForm = false
    @State private var editing: MoistureAlert?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.alerts.isEmpty {
                    MeterCard {
                        VStack(spacing: 8) {
                            Image(systemName: "bell.badge")
                                .foregroundColor(AppTheme.primary)
                            Text("Set your first moisture alert!")
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(store.alerts) { alert in
                        MeterCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(alert.kind).font(.headline)
                                    Spacer()
                                    Text(alert.enabled ? "On" : "Off")
                                        .font(.caption)
                                        .foregroundColor(alert.enabled ? AppTheme.primary : .secondary)
                                }
                                Text(alert.bedName.isEmpty ? "All beds" : alert.bedName)
                                    .font(.subheadline)
                                Text("Threshold \(Int(alert.moistureThreshold))%")
                                    .font(.subheadline.monospacedDigit())
                                if let last = alert.lastTriggered {
                                    Text("Last notice \(last.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Button("Edit") { editing = alert }
                                    Button("Delete", role: .destructive) { store.deleteAlert(alert.id) }
                                }
                            }
                        }
                    }
                }
                MeterButton(title: "Add threshold", icon: "plus") { showForm = true }
            }
            .padding(18)
        }
        .screenBackdrop("BgGreenhouse")
        .navigationTitle("Alerts")
        .sheet(isPresented: $showForm) {
            AlertFormView()
                .environmentObject(store)
        }
        .sheet(item: $editing) { alert in
            AlertFormView(existing: alert)
                .environmentObject(store)
        }
    }
}

struct AlertFormView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var existing: MoistureAlert?
    @State private var threshold: Double = 35
    @State private var kind = AlertKind.dry.rawValue
    @State private var enabled = true
    @State private var bedName = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Threshold") {
                    Picker("Kind", selection: $kind) {
                        ForEach(AlertKind.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("Bed", selection: $bedName) {
                        Text("All beds").tag("")
                        ForEach(store.allBedNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Slider(value: $threshold, in: 0...100, step: 1)
                    Text("\(Int(threshold))%")
                    Toggle("Enabled", isOn: $enabled)
                    if let error { Text(error).font(.caption).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(existing == nil ? "New alert" : "Edit alert")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                if let existing {
                    threshold = existing.moistureThreshold
                    kind = existing.kind
                    enabled = existing.enabled
                    bedName = existing.bedName
                } else if let first = store.allBedNames.first {
                    applyBand(for: first)
                }
            }
            .onChange(of: bedName) { name in
                applyBand(for: name)
            }
            .onChange(of: kind) { _ in
                applyBand(for: bedName)
            }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.dark)
    }

    private func applyBand(for name: String) {
        guard existing == nil, !name.isEmpty else { return }
        let profile = store.profile(for: name)
        threshold = kind == AlertKind.dry.rawValue ? profile.dryBelow : profile.wetAbove
    }

    private func save() {
        if threshold < 0 || threshold > 100 {
            error = "Keep the threshold between 0 and 100."
            return
        }
        store.upsertAlert(MoistureAlert(id: existing?.id ?? UUID(), moistureThreshold: threshold, kind: kind, enabled: enabled, lastTriggered: existing?.lastTriggered, bedName: bedName))
        AppNotify.requestAccess { _ in }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
