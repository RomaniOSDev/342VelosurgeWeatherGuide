import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var reminderTime = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    MeterCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Probe calibration")
                                .font(.headline)
                            Text("Shift probe readings by \(Int(store.calibrationOffset))%. A probe 40% shows as \(Int(store.display(40)))%.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $store.calibrationOffset, in: -20...20, step: 1)
                                .onChange(of: store.calibrationOffset) { _ in store.save() }
                        }
                    }

                    MeterCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Daily measurement reminder", isOn: $store.reminderEnabled)
                                .onChange(of: store.reminderEnabled) { enabled in
                                    if enabled {
                                        AppNotify.requestAccess { granted in
                                            store.reminderEnabled = granted ? true : false
                                            store.applyReminderSettings()
                                        }
                                    } else {
                                        store.applyReminderSettings()
                                    }
                                }
                            DatePicker("Remind at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .onChange(of: reminderTime) { date in
                                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    store.reminderHour = parts.hour ?? 9
                                    store.reminderMinute = parts.minute ?? 0
                                    store.applyReminderSettings()
                                }
                            Stepper("Check \(store.checkHoursAfterWatering)h after watering", value: $store.checkHoursAfterWatering, in: 0...72, step: 6)
                                .onChange(of: store.checkHoursAfterWatering) { _ in store.save() }
                            Text(store.checkHoursAfterWatering == 0 ? "Post-watering check is off." : "A notification will fire after you log a watering.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    row("Rate Us", "star.fill") { rateApp() }
                    row("Privacy", "hand.raised.fill") {
                        if let url = URL(string: AppLinks.privacy.rawValue) {
                            UIApplication.shared.open(url)
                        }
                    }
                    row("Terms", "doc.text.fill") {
                        if let url = URL(string: AppLinks.terms.rawValue) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Reset All Data", role: .destructive) { confirmReset = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding()
                        .background(
                            AppTheme.plateShape
                                .stroke(Color.red.opacity(0.55), lineWidth: 1)
                        )
                }
                .padding(18)
            }
            .screenBackdrop("BgGreenhouse")
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .alert("Erase moisture logs?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { store.resetAllData() }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear {
                reminderTime = Calendar.current.date(from: DateComponents(hour: store.reminderHour, minute: store.reminderMinute)) ?? Date()
            }
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(.dark)
    }

    private func row(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SoilMark(icon: icon)
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Rectangle()
                    .fill(AppTheme.primary)
                    .frame(width: 14, height: 2)
            }
            .padding(14)
            .background {
                ZStack(alignment: .leading) {
                    AppTheme.plateShape.fill(AppTheme.panel)
                    Capsule().fill(AppTheme.primary).frame(width: 4).padding(.vertical, 12).padding(.leading, 6)
                }
            }
        }
        .buttonStyle(GaugePressStyle())
        .frame(minHeight: 44)
    }

    private func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}
