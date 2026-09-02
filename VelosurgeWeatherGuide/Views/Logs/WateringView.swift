import SwiftUI

struct WateringView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var showForm = false
    @State private var presetBed = ""
    @State private var pendingDelete: WateringEvent?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.wateringEvents.isEmpty {
                    MeterCard {
                        VStack(spacing: 8) {
                            Image(systemName: "drop.triangle.fill")
                                .foregroundColor(AppTheme.primary)
                            Text("Log a watering to measure dry-down.")
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(store.wateringEvents) { event in
                        MeterCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.bedName).font(.headline)
                                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                if !event.note.isEmpty {
                                    Text(event.note).font(.caption)
                                }
                                Text(store.wateringHint(for: event.bedName))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) { pendingDelete = event }
                        }
                    }
                }
                MeterButton(title: "Log watering", icon: "drop.fill") {
                    presetBed = store.lastBedName
                    showForm = true
                }
            }
            .padding(18)
        }
        .screenBackdrop("BgGreenhouse")
        .navigationTitle("Watering")
        .sheet(isPresented: $showForm) {
            WateringFormView(presetBed: presetBed)
                .environmentObject(store)
        }
        .alert("Delete this watering?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let pendingDelete { store.deleteWatering(pendingDelete.id) }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}

struct WateringFormView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var presetBed: String = ""
    @State private var bedName = ""
    @State private var timestamp = Date()
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Watering") {
                    if !store.allBedNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.allBedNames, id: \.self) { name in
                                    Button(name) { bedName = name }
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(bedName == name ? AppTheme.primary.opacity(0.35) : AppTheme.surface, in: Capsule())
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    TextField("Bed name", text: $bedName)
                        .submitLabel(.next)
                    DatePicker("Watered at", selection: $timestamp)
                    TextField("Note", text: $note)
                        .submitLabel(.done)
                    if let error {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Log watering")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                if bedName.isEmpty {
                    bedName = presetBed.isEmpty ? store.lastBedName : presetBed
                }
            }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.dark)
    }

    private func save() {
        let name = bedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            error = "Name the bed or pot."
            return
        }
        store.upsertWatering(WateringEvent(id: UUID(), timestamp: timestamp, bedName: name, note: note))
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

struct BedProfileSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    let name: String
    @State private var plantKind = PlantKind.general.rawValue
    @State private var dryBelow: Double = 35
    @State private var wetAbove: Double = 70

    var body: some View {
        NavigationStack {
            Form {
                Section("Plant profile") {
                    Text(name).font(.headline)
                    Picker("Plant type", selection: $plantKind) {
                        ForEach(PlantKind.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .onChange(of: plantKind) { newValue in
                        if let kind = PlantKind(rawValue: newValue) {
                            dryBelow = kind.dryBelow
                            wetAbove = kind.wetAbove
                        }
                    }
                    Slider(value: $dryBelow, in: 0...90, step: 1)
                    Text("Too dry below \(Int(dryBelow))%")
                    Slider(value: $wetAbove, in: 10...100, step: 1)
                    Text("Too wet above \(Int(wetAbove))%")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Bed profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                let profile = store.profile(for: name)
                plantKind = profile.plantKind
                dryBelow = profile.dryBelow
                wetAbove = profile.wetAbove
            }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.dark)
    }

    private func save() {
        if dryBelow >= wetAbove {
            wetAbove = min(100, dryBelow + 5)
        }
        store.upsertProfile(BedProfile(id: store.profile(for: name).id, name: name, plantKind: plantKind, dryBelow: dryBelow, wetAbove: wetAbove))
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
