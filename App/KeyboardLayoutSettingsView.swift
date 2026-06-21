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

    @AppStorage(SharedKeyboardState.Keys.playScanSound, store: SharedKeyboardState.appStorageDefaults)
    private var playScanSound = SharedKeyboardState.playScanSound

    @AppStorage(SharedKeyboardState.Keys.returnTarget, store: SharedKeyboardState.appStorageDefaults)
    private var returnTargetRawValue = ReturnTarget.safari.rawValue

    @AppStorage(SharedKeyboardState.Keys.customReturnURL, store: SharedKeyboardState.appStorageDefaults)
    private var customReturnURL = ""

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

    var body: some View {
        NavigationStack {
            List {
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
                    Text("Keyboard Profile")
                } footer: {
                    Text("Turn on the layouts this keyboard should offer. If more than one layout is enabled, the keyboard switch key cycles through only those layouts. Turn every layout off to show only the Scan button.")
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
                } header: {
                    Text("Scanner")
                } footer: {
                    Text("QR code contents are inserted as plain text. Blip does not open links automatically.")
                }

                Section {
                    SetupDiagnosticRow(
                        title: "Keyboard enabled",
                        value: setupStatus.isKeyboardEnabled
                            ? NSLocalizedString("Yes", comment: "Affirmative diagnostics value")
                            : NSLocalizedString("No", comment: "Negative diagnostics value")
                    )

                    SetupDiagnosticRow(
                        title: "Matched entry",
                        value: setupStatus.snapshot.matchedKeyboard ?? NSLocalizedString("None", comment: "No diagnostics value")
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Raw AppleKeyboards")
                            .font(.subheadline.weight(.semibold))
                        Text(setupStatus.snapshot.rawKeyboardSummary)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Setup Diagnostics")
                } footer: {
                    Text("This is temporary debugging data so we can verify what iOS reports on your iPhone.")
                }
            }
            .navigationTitle("Settings")
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
