import SwiftUI

struct LogFormView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var existing: MoistureLog?
    var presetBed: String? = nil
    var onSaved: ((Bool) -> Void)?

    @State private var value: Double = 40
    @State private var bedName = ""
    @State private var note = ""
    @State private var timestamp = Date()
    @State private var plantKind = PlantKind.general.rawValue
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    if existing == nil && !store.allBedNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.allBedNames, id: \.self) { name in
                                    Button(name) { applyBed(name) }
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
                    Picker("Plant type", selection: $plantKind) {
                        ForEach(PlantKind.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    if let kind = PlantKind(rawValue: plantKind) {
                        Text("Target \(Int(kind.dryBelow))–\(Int(kind.wetAbove))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $value, in: 0...100, step: 1)
                    Text("Probe \(Int(value))% · shown as \(Int(store.display(value)))%")
                        .font(.body.monospacedDigit())
                    DatePicker("Logged at", selection: $timestamp)
                    TextField("Note", text: $note)
                        .submitLabel(.done)
                    if let error {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    if existing == nil {
                        Button("Save & log another") { save(stayOpen: true) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(existing == nil ? "New reading" : "Edit reading")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(stayOpen: false) } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear { populate() }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.dark)
    }

    private func populate() {
        if let existing {
            value = existing.value
            bedName = existing.bedName
            note = existing.note
            timestamp = existing.timestamp
            plantKind = store.profile(for: existing.bedName).plantKind
            return
        }
        let bed = (presetBed?.isEmpty == false ? presetBed : nil) ?? (store.lastBedName.isEmpty ? nil : store.lastBedName)
        if let bed {
            applyBed(bed)
        } else {
            value = store.lastMoistureValue
        }
        timestamp = Date()
    }

    private func applyBed(_ name: String) {
        bedName = name
        let profile = store.profile(for: name)
        plantKind = profile.plantKind
        if let latest = store.latestLog(for: name) {
            value = latest.value
        } else {
            value = store.lastMoistureValue
        }
    }

    private func save(stayOpen: Bool) {
        let name = bedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            error = "Name the bed or pot."
            return
        }
        let log = MoistureLog(id: existing?.id ?? UUID(), timestamp: timestamp, value: value, bedName: name, note: note)
        store.ensureProfile(name: name, plantKind: plantKind)
        if let message = store.upsertLog(log) {
            error = message
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSaved?(true)
        if stayOpen {
            error = nil
            note = ""
            timestamp = Date()
            return
        }
        dismiss()
    }
}

struct LogHistoryView: View {
    @EnvironmentObject private var store: AppDataStore
    @State private var editing: MoistureLog?
    @State private var pendingDelete: MoistureLog?
    @State private var bedFilter = "All"

    private var filtered: [MoistureLog] {
        if bedFilter == "All" { return store.moistureLogs }
        return store.moistureLogs.filter { $0.bedName == bedFilter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.allBedNames.count > 1 {
                    Picker("Bed", selection: $bedFilter) {
                        Text("All beds").tag("All")
                        ForEach(store.allBedNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)
                }
                if filtered.isEmpty {
                    MeterCard {
                        Text("No moisture data yet - Start tracking now!")
                    }
                } else {
                    ForEach(filtered) { log in
                        MeterCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.bedName).font(.headline)
                                    Text("\(Int(store.display(log.value)))% · \(store.zoneLabel(for: log)) · \(log.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                    if !log.note.isEmpty {
                                        Text(log.note).font(.caption)
                                    }
                                }
                                Spacer()
                                Button("Edit") { editing = log }
                            }
                        }
                        .contextMenu {
                            Button("Edit") { editing = log }
                            Button("Delete", role: .destructive) { pendingDelete = log }
                        }
                    }
                }
            }
            .padding(18)
        }
        .screenBackdrop("BgGreenhouse")
        .navigationTitle("History")
        .sheet(item: $editing) { log in
            LogFormView(existing: log)
                .environmentObject(store)
        }
        .alert("Delete this reading?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let pendingDelete { store.deleteLog(pendingDelete.id) }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}
