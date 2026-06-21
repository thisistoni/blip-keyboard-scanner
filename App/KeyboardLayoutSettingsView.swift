import SwiftUI

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

    @AppStorage(SharedKeyboardState.Keys.customReturnURL, store: SharedKeyboardState.appStorageDefaults)
    private var customReturnURL = ""

    @State private var showingMailError = false

    private var keyboardLanguage: Binding<KeyboardLanguage> {
        Binding {
            KeyboardLanguage(rawValue: keyboardLanguageRawValue) ?? .english
        } set: { newValue in
            keyboardLanguageRawValue = newValue.rawValue
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
                    Text("Choose the keyboard language and which layouts employees can cycle through. Turn every layout off to show only the Scan button.")
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
                            Text(target.title).tag(target)
                        }
                    }

                    Text(returnTarget.wrappedValue.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if returnTarget.wrappedValue == .custom {
                        TextField("exampleapp://", text: $customReturnURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    Button {
                        SourceAppReturnController.openReturnTarget(
                            returnTarget.wrappedValue,
                            customURLString: customReturnURL
                        )
                    } label: {
                        Label("Test Return Target", systemImage: "arrow.up.forward.app")
                    }
                    .disabled(returnTarget.wrappedValue == .custom && customReturnURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Return Target")
                } footer: {
                    Text("After a keyboard-launched scan, Blip opens this app so the keyboard can resume and insert the scan. Use the test button to verify each target on your iPhone.")
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
