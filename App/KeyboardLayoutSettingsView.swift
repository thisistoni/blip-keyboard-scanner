import SwiftUI
import UIKit

struct KeyboardLayoutSettingsView: View {
    let setupStatus: SetupVerificationStatus

    @AppStorage(SharedKeyboardState.Keys.keyboardLanguage, store: SharedKeyboardState.appStorageDefaults)
    private var keyboardLanguageRawValue = SharedKeyboardState.keyboardLanguage.rawValue

    @AppStorage(SharedKeyboardState.Keys.enabledKeyboardLayoutSlots, store: SharedKeyboardState.appStorageDefaults)
    private var enabledLayoutSlotsRawValue = SharedKeyboardState.enabledKeyboardLayoutSlotsRawValue

    @AppStorage(SharedKeyboardState.Keys.startupKeyboardLayoutSlot, store: SharedKeyboardState.appStorageDefaults)
    private var startupLayoutSlotRawValue = SharedKeyboardState.startupKeyboardLayoutSlotRawValue

    @AppStorage(SharedKeyboardState.Keys.insertSuffix, store: SharedKeyboardState.appStorageDefaults)
    private var insertSuffixRawValue = InsertSuffix.none.rawValue

    @AppStorage(SharedKeyboardState.Keys.scannerFlashlightMode, store: SharedKeyboardState.appStorageDefaults)
    private var scannerFlashlightModeRawValue = ScannerFlashlightMode.off.rawValue

    @AppStorage(SharedKeyboardState.Keys.scanFormatProfile, store: SharedKeyboardState.appStorageDefaults)
    private var scanFormatProfileRawValue = SharedKeyboardState.scanFormatProfile.rawValue

    @AppStorage(SharedKeyboardState.Keys.scannerZoomLevel, store: SharedKeyboardState.appStorageDefaults)
    private var scannerZoomLevelRawValue = SharedKeyboardState.scannerZoomLevel.rawValue

    @AppStorage(SharedKeyboardState.Keys.scannerScanArea, store: SharedKeyboardState.appStorageDefaults)
    private var scannerScanAreaRawValue = SharedKeyboardState.scannerScanArea.rawValue

    @AppStorage(SharedKeyboardState.Keys.playScanSound, store: SharedKeyboardState.appStorageDefaults)
    private var playScanSound = SharedKeyboardState.playScanSound

    @AppStorage(SharedKeyboardState.Keys.scanHistoryRetention, store: SharedKeyboardState.appStorageDefaults)
    private var historyRetentionRawValue = SharedKeyboardState.scanHistoryRetention.rawValue

    @AppStorage(SharedKeyboardState.Keys.returnTarget, store: SharedKeyboardState.appStorageDefaults)
    private var returnTargetRawValue = ReturnTarget.safari.rawValue

    @AppStorage(SharedKeyboardState.Keys.autoInsertScans, store: SharedKeyboardState.appStorageDefaults)
    private var autoInsertScans = true

    @AppStorage(SharedKeyboardState.Keys.customReturnURL, store: SharedKeyboardState.appStorageDefaults)
    private var customReturnURL = ""

    @AppStorage(SharedKeyboardState.Keys.keyboardClickSound, store: SharedKeyboardState.appStorageDefaults)
    private var keyboardClickSound = true

    @AppStorage(SharedKeyboardState.Keys.keyboardHaptics, store: SharedKeyboardState.appStorageDefaults)
    private var keyboardHaptics = true

    @AppStorage(SharedKeyboardState.Keys.keyboardAppearance, store: SharedKeyboardState.appStorageDefaults)
    private var keyboardAppearanceRawValue = KeyboardAppearance.system.rawValue

    @State private var showingMailError = false
    @State private var showingStoreError = false
    @State private var showingSystemReturnHelp = false

    private let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6782697501?action=write-review")!

    private var keyboardLanguage: Binding<KeyboardLanguage> {
        Binding {
            KeyboardLanguage(rawValue: keyboardLanguageRawValue) ?? .english
        } set: { newValue in
            keyboardLanguageRawValue = newValue.rawValue
        }
    }

    private var keyboardAppearance: Binding<KeyboardAppearance> {
        Binding {
            .resolved(rawValue: keyboardAppearanceRawValue)
        } set: { value in
            keyboardAppearanceRawValue = value.rawValue
        }
    }

    private var enabledLayoutSlots: [KeyboardLayoutSlot] {
        get {
            KeyboardLayoutSlot.slots(from: enabledLayoutSlotsRawValue) ?? KeyboardLayoutSlot.allCases
        }
        nonmutating set {
            let uniqueSlots = KeyboardLayoutSlot.allCases.filter { newValue.contains($0) }
            enabledLayoutSlotsRawValue = KeyboardLayoutSlot.rawValue(for: uniqueSlots)

            guard !uniqueSlots.isEmpty else {
                startupLayoutSlotRawValue = ""
                return
            }

            if !uniqueSlots.contains(startupLayoutSlot) {
                startupLayoutSlotRawValue = uniqueSlots[0].rawValue
            }
        }
    }

    private var startupLayoutSlot: KeyboardLayoutSlot {
        let enabledSlots = enabledLayoutSlots
        guard !enabledSlots.isEmpty else { return .letters }

        if let slot = KeyboardLayoutSlot(rawValue: startupLayoutSlotRawValue),
           enabledSlots.contains(slot) {
            return slot
        }

        return enabledSlots[0]
    }

    private var startupLayoutSlotBinding: Binding<KeyboardLayoutSlot> {
        Binding {
            startupLayoutSlot
        } set: { newValue in
            startupLayoutSlotRawValue = newValue.rawValue
        }
    }

    private var insertSuffix: Binding<InsertSuffix> {
        Binding {
            InsertSuffix(rawValue: insertSuffixRawValue) ?? .none
        } set: { newValue in
            insertSuffixRawValue = newValue.rawValue
        }
    }

    private var flashlightEnabledByDefault: Binding<Bool> {
        Binding {
            ScannerFlashlightMode(rawValue: scannerFlashlightModeRawValue) == .on
        } set: { newValue in
            scannerFlashlightModeRawValue = (newValue ? ScannerFlashlightMode.on : .off).rawValue
        }
    }

    private var returnTarget: Binding<ReturnTarget> {
        Binding {
            ReturnTarget(rawValue: returnTargetRawValue) ?? .safari
        } set: { newValue in
            returnTargetRawValue = newValue.rawValue
        }
    }

    private var automaticReturnDescription: LocalizedStringKey {
        switch returnTarget.wrappedValue {
        case .chrome, .brave:
            "Automatically returns to your open browser tab after scanning."
        case .edge, .firefox:
            "Automatically returns to the selected browser after scanning."
        case .custom:
            "Automatically opens your Custom Return URL after scanning."
        case .safari:
            ""
        }
    }

    private var scanFormatProfile: Binding<ScanFormatProfile> {
        Binding {
            ScanFormatProfile(rawValue: scanFormatProfileRawValue) ?? .allSupported
        } set: { newValue in
            scanFormatProfileRawValue = newValue.rawValue
        }
    }

    private var scannerZoomLevel: Binding<ScannerZoomLevel> {
        Binding {
            ScannerZoomLevel(rawValue: scannerZoomLevelRawValue) ?? .x1
        } set: { newValue in
            scannerZoomLevelRawValue = newValue.rawValue
        }
    }

    private var scannerScanArea: Binding<ScannerScanArea> {
        Binding {
            ScannerScanArea(rawValue: scannerScanAreaRawValue) ?? .fullFrame
        } set: { newValue in
            scannerScanAreaRawValue = newValue.rawValue
        }
    }

    private var historyRetention: Binding<ScanHistoryRetention> {
        Binding {
            ScanHistoryRetention(rawValue: historyRetentionRawValue) ?? .thirtyDays
        } set: { newValue in
            historyRetentionRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Language", selection: keyboardLanguage) {
                        ForEach(KeyboardLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }

                    ForEach(KeyboardLayoutSlot.allCases) { slot in
                        LayoutToggleRow(
                            slot: slot,
                            isEnabled: layoutEnabledBinding(for: slot)
                        )
                    }

                    if enabledLayoutSlots.isEmpty {
                        Label("Scan-only keyboard", systemImage: "barcode.viewfinder")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Opens With", selection: startupLayoutSlotBinding) {
                            ForEach(enabledLayoutSlots) { slot in
                                Text(slot.title).tag(slot)
                            }
                        }
                    }
                } header: {
                    Text("Keyboard")
                } footer: {
                    Text("Choose the keyboard language and which layouts you can cycle through. Turn every layout off to show only the Scan button.")
                }

                Section {
                    Picker("Appearance", selection: keyboardAppearance) {
                        ForEach(KeyboardAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                } header: {
                    Text("Keyboard Appearance")
                }

                Section {
                    Toggle("Key Clicks", isOn: $keyboardClickSound)
                    Toggle("Key Haptics", isOn: $keyboardHaptics)
                } header: {
                    Text("Keyboard Feedback")
                }

                Section {
                    Picker("After inserting a scan", selection: insertSuffix) {
                        ForEach(InsertSuffix.allCases) { suffix in
                            Text(suffix.title).tag(suffix)
                        }
                    }
                } header: {
                    Text("Scan Suffix")
                }

                Section {
                    Toggle("Flashlight by default", isOn: flashlightEnabledByDefault)
                    Toggle("Blip sound on scan", isOn: $playScanSound)

                    Picker("Scan Formats", selection: scanFormatProfile) {
                        ForEach(ScanFormatProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }

                    Text(scanFormatProfile.wrappedValue.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Default Zoom", selection: scannerZoomLevel) {
                        ForEach(ScannerZoomLevel.allCases) { zoomLevel in
                            Text(zoomLevel.title).tag(zoomLevel)
                        }
                    }

                    Text(scannerZoomLevel.wrappedValue.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Scan Area", selection: scannerScanArea) {
                        ForEach(ScannerScanArea.allCases) { area in
                            Text(area.title).tag(area)
                        }
                    }

                    Text(scannerScanArea.wrappedValue.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Scanner")
                } footer: {
                    Text("QR code contents are inserted as plain text. Blip does not open links automatically.")
                }

                Section {
                    Picker("Return to", selection: returnTarget) {
                        ForEach(ReturnTarget.allCases) { target in
                            Text(target == .safari
                                 ? NSLocalizedString("Safari (manual)", comment: "Safari requires manual return")
                                 : target.title)
                                .tag(target)
                        }
                    }

                    if returnTarget.wrappedValue != .safari {
                        Text(automaticReturnDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Toggle("Insert Scans Automatically", isOn: $autoInsertScans)
                    }

                    if returnTarget.wrappedValue == .custom {
                        TextField("exampleapp://", text: $customReturnURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    if returnTarget.wrappedValue == .custom {
                        Button {
                            SourceAppReturnController.openCustomReturnURL(customReturnURL)
                        } label: {
                            Label("Test Custom Return URL", systemImage: "arrow.up.forward.app")
                        }
                        .disabled(customReturnURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else if returnTarget.wrappedValue == .safari {
                        Button {
                            showingSystemReturnHelp = true
                        } label: {
                            Label("How to Return to Safari", systemImage: "arrow.backward.circle")
                        }
                    }
                } header: {
                    Text("Return Target")
                }

                Section {
                    Picker("Keep History", selection: historyRetention) {
                        ForEach(ScanHistoryRetention.allCases) { retention in
                            Text(retention.title).tag(retention)
                        }
                    }

                    Text(historyRetention.wrappedValue.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("History")
                } footer: {
                    Text("Scan history is local to this device and can be cleared from the History tab.")
                }

                Section {
                    NavigationLink {
                        CompanyProfilesView()
                    } label: {
                        Label("Company Profiles", systemImage: "doc.badge.gearshape")
                    }
                } header: {
                    Text("Company Profiles")
                } footer: {
                    Text("Export or import Blip settings for a consistent company setup. Profiles do not include scan history.")
                }

                Section {
                    NavigationLink {
                        PrivacyTrustView()
                    } label: {
                        Label("Privacy & Trust", systemImage: "lock.shield")
                    }

                    Button {
                        sendFeedback()
                    } label: {
                        Label("Send Feedback", systemImage: "paperplane")
                    }
                } header: {
                    Text("Help & Feedback")
                } footer: {
                    Text("Feedback opens an email draft with app and device context. Nothing is sent unless you send it.")
                }

                Section {
                    NavigationLink {
                        SetupDiagnosticsView(setupStatus: setupStatus)
                    } label: {
                        Label("Keyboard Setup Status", systemImage: setupStatus.isKeyboardEnabled ? "checkmark.circle" : "exclamationmark.circle")
                    }
                } header: {
                    Text("Keyboard Status")
                } footer: {
                    Text("Use this when iOS Settings does not seem to match what Blip detects.")
                }

                Section {
                    Button {
                        rateBlip()
                    } label: {
                        Label("Rate Blip", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: historyRetentionRawValue) { _ in
                _ = ScanHistoryStore.applyRetention()
            }
            .alert("Mail is not available", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Install or configure Mail to send feedback from Blip.")
            }
            .alert("App Store is not available", isPresented: $showingStoreError) {
                Button("Copy App Store link") {
                    UIPasteboard.general.url = appStoreReviewURL
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open the copied link to rate Blip in the App Store.")
            }
            .alert("Return to Safari", isPresented: $showingSystemReturnHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Blip can't automatically return to your original Safari tab. Use iOS's previous-app control or swipe right on the Home indicator. In the original Safari field, tap Insert Last Scan on the Blip keyboard. For automatic return, choose another supported Return Target.")
            }
        }
    }

    private func layoutEnabledBinding(for slot: KeyboardLayoutSlot) -> Binding<Bool> {
        Binding {
            enabledLayoutSlots.contains(slot)
        } set: { isEnabled in
            var slots = enabledLayoutSlots

            if isEnabled {
                slots.append(slot)
            } else {
                slots.removeAll { $0 == slot }
            }

            enabledLayoutSlots = KeyboardLayoutSlot.allCases.filter { slots.contains($0) }
        }
    }

    private func sendFeedback() {
        guard let url = SupportEmail.feedbackURL() else {
            showingMailError = true
            return
        }

        SupportEmail.open(url) {
            showingMailError = true
        }
    }

    private func rateBlip() {
        UIApplication.shared.open(appStoreReviewURL) { didOpen in
            guard !didOpen else { return }
            DispatchQueue.main.async {
                showingStoreError = true
            }
        }
    }
}

private struct LayoutToggleRow: View {
    let slot: KeyboardLayoutSlot
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.title)
                Text(slot.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SetupDiagnosticRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

private struct SetupDiagnosticsView: View {
    let setupStatus: SetupVerificationStatus

    var body: some View {
        List {
            Section {
                SetupDiagnosticRow(
                    title: "Keyboard enabled",
                    value: setupStatus.isKeyboardEnabled
                        ? NSLocalizedString("Yes", comment: "Affirmative diagnostics value")
                        : NSLocalizedString("No", comment: "Negative diagnostics value")
                )

                SetupDiagnosticRow(
                    title: "Matched keyboard",
                    value: setupStatus.snapshot.matchedKeyboard ?? NSLocalizedString("None", comment: "No diagnostics value")
                )
            }

            Section {
                Text(setupStatus.snapshot.rawKeyboardSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            } header: {
                Text("iOS Keyboard Entries")
            } footer: {
                Text("These are the keyboard entries iOS currently reports to Blip.")
            }
        }
        .navigationTitle("Keyboard Status")
    }
}
