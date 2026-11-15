import Foundation

struct BlipCompanyProfile: Codable, Equatable {
    static let currentVersion = 1

    let profileVersion: Int
    let exportedAt: Date
    let keyboardLanguage: String
    let keyboardType: String
    let enabledKeyboardLayouts: String
    let startupKeyboardLayout: String
    let scanSuffix: String
    let autoInsertScans: Bool?
    let scanFormatProfile: String
    let returnTarget: String
    let customReturnURL: String
    let playScanSound: Bool
    let scannerFlashlightMode: String
    let scannerZoomLevel: String
    let scannerScanArea: String
    // Optional so profiles exported before the KeyboardKit update remain compatible.
    var keyboardAppearance: String?
    var keyboardClickSound: Bool?
    var keyboardHaptics: Bool?

    static var current: BlipCompanyProfile {
        BlipCompanyProfile(
            profileVersion: currentVersion,
            exportedAt: Date(),
            keyboardLanguage: SharedKeyboardState.keyboardLanguage.rawValue,
            keyboardType: SharedKeyboardState.keyboardType.rawValue,
            enabledKeyboardLayouts: SharedKeyboardState.enabledKeyboardLayoutSlotsRawValue,
            startupKeyboardLayout: SharedKeyboardState.startupKeyboardLayoutSlotRawValue,
            scanSuffix: SharedKeyboardState.insertSuffix.rawValue,
            autoInsertScans: SharedKeyboardState.autoInsertScans,
            scanFormatProfile: SharedKeyboardState.scanFormatProfile.rawValue,
            returnTarget: SharedKeyboardState.returnTarget.rawValue,
            customReturnURL: SharedKeyboardState.returnTarget == .custom ? SharedKeyboardState.customReturnURL : "",
            playScanSound: SharedKeyboardState.playScanSound,
            scannerFlashlightMode: SharedKeyboardState.scannerFlashlightMode.rawValue,
            scannerZoomLevel: SharedKeyboardState.scannerZoomLevel.rawValue,
            scannerScanArea: SharedKeyboardState.scannerScanArea.rawValue,
            keyboardAppearance: SharedKeyboardState.keyboardAppearance.rawValue,
            keyboardClickSound: SharedKeyboardState.keyboardClickSound,
            keyboardHaptics: SharedKeyboardState.keyboardHaptics
        )
    }

    func validate() throws {
        guard profileVersion == Self.currentVersion else {
            throw BlipCompanyProfileError.unsupportedVersion(profileVersion)
        }

        guard KeyboardLanguage(rawValue: keyboardLanguage) != nil else {
            throw BlipCompanyProfileError.invalidValue("keyboardLanguage")
        }

        guard KeyboardType(rawValue: keyboardType) != nil else {
            throw BlipCompanyProfileError.invalidValue("keyboardType")
        }

        guard let layoutSlots = KeyboardLayoutSlot.slots(from: enabledKeyboardLayouts) else {
            throw BlipCompanyProfileError.invalidValue("enabledKeyboardLayouts")
        }

        if !startupKeyboardLayout.isEmpty {
            guard let startupSlot = KeyboardLayoutSlot(rawValue: startupKeyboardLayout),
                  layoutSlots.contains(startupSlot)
            else {
                throw BlipCompanyProfileError.invalidValue("startupKeyboardLayout")
            }
        }

        guard InsertSuffix(rawValue: scanSuffix) != nil else {
            throw BlipCompanyProfileError.invalidValue("scanSuffix")
        }

        guard ScanFormatProfile(rawValue: scanFormatProfile) != nil else {
            throw BlipCompanyProfileError.invalidValue("scanFormatProfile")
        }

        guard ReturnTarget(rawValue: returnTarget) != nil else {
            throw BlipCompanyProfileError.invalidValue("returnTarget")
        }

        guard ScannerFlashlightMode(rawValue: scannerFlashlightMode) != nil else {
            throw BlipCompanyProfileError.invalidValue("scannerFlashlightMode")
        }

        guard ScannerZoomLevel(rawValue: scannerZoomLevel) != nil else {
            throw BlipCompanyProfileError.invalidValue("scannerZoomLevel")
        }

        guard ScannerScanArea(rawValue: scannerScanArea) != nil else {
            throw BlipCompanyProfileError.invalidValue("scannerScanArea")
        }
        if let keyboardAppearance, KeyboardAppearance(rawValue: keyboardAppearance) == nil {
            throw BlipCompanyProfileError.invalidValue("keyboardAppearance")
        }
    }

    func apply() throws {
        try validate()

        SharedKeyboardState.keyboardLanguage = KeyboardLanguage(rawValue: keyboardLanguage) ?? .english
        SharedKeyboardState.keyboardType = KeyboardType(rawValue: keyboardType) ?? .standard
        SharedKeyboardState.enabledKeyboardLayoutSlots = KeyboardLayoutSlot.slots(from: enabledKeyboardLayouts) ?? KeyboardLayoutSlot.allCases
        SharedKeyboardState.startupKeyboardLayoutSlot = startupKeyboardLayout.isEmpty ? nil : KeyboardLayoutSlot(rawValue: startupKeyboardLayout)
        SharedKeyboardState.insertSuffix = InsertSuffix(rawValue: scanSuffix) ?? .none
        if let autoInsertScans {
            SharedKeyboardState.autoInsertScans = autoInsertScans
        }
        SharedKeyboardState.scanFormatProfile = ScanFormatProfile(rawValue: scanFormatProfile) ?? .allSupported
        SharedKeyboardState.returnTarget = ReturnTarget(rawValue: returnTarget) ?? .safari
        // An inactive custom destination is not part of the imported workflow.
        if returnTarget == ReturnTarget.custom.rawValue {
            SharedKeyboardState.customReturnURL = customReturnURL
        }
        SharedKeyboardState.playScanSound = playScanSound
        SharedKeyboardState.scannerFlashlightMode = ScannerFlashlightMode(rawValue: scannerFlashlightMode) ?? .off
        SharedKeyboardState.scannerZoomLevel = ScannerZoomLevel(rawValue: scannerZoomLevel) ?? .x1
        SharedKeyboardState.scannerScanArea = ScannerScanArea(rawValue: scannerScanArea) ?? .fullFrame
        if let keyboardAppearance {
            SharedKeyboardState.keyboardAppearance = KeyboardAppearance(rawValue: keyboardAppearance) ?? .system
        }
        if let keyboardClickSound { SharedKeyboardState.keyboardClickSound = keyboardClickSound }
        if let keyboardHaptics { SharedKeyboardState.keyboardHaptics = keyboardHaptics }
    }

    func changes(comparedTo current: BlipCompanyProfile = .current) -> [BlipCompanyProfileChange] {
        var result = [
            change("Keyboard Language", current.keyboardLanguage, keyboardLanguage) { KeyboardLanguage(rawValue: $0) },
            change("Keyboard Type", current.keyboardType, keyboardType) { KeyboardType(rawValue: $0) },
            change("Enabled Layouts", current.enabledKeyboardLayouts, enabledKeyboardLayouts, BlipCompanyProfile.formatLayouts),
            change("Opening Layout", current.startupKeyboardLayout, startupKeyboardLayout, BlipCompanyProfile.formatLayoutSlot),
            change("Scan Suffix", current.scanSuffix, scanSuffix) { InsertSuffix(rawValue: $0) },
            BlipCompanyProfileChange(
                title: NSLocalizedString("Insert Scans Automatically", comment: "Profile auto-insert setting"),
                currentValue: (current.autoInsertScans ?? true) ? NSLocalizedString("On", comment: "Profile auto-insert on") : NSLocalizedString("Off", comment: "Profile auto-insert off"),
                incomingValue: (autoInsertScans ?? current.autoInsertScans ?? true) ? NSLocalizedString("On", comment: "Profile auto-insert on") : NSLocalizedString("Off", comment: "Profile auto-insert off")
            ),
            change("Scan Formats", current.scanFormatProfile, scanFormatProfile) { ScanFormatProfile(rawValue: $0) },
            change("Return Target", current.returnTarget, returnTarget) { ReturnTarget(rawValue: $0) },
            BlipCompanyProfileChange(
                title: "Blip Sound",
                currentValue: current.playScanSound ? NSLocalizedString("On", comment: "Profile sound on value") : NSLocalizedString("Off", comment: "Profile sound off value"),
                incomingValue: playScanSound ? NSLocalizedString("On", comment: "Profile sound on value") : NSLocalizedString("Off", comment: "Profile sound off value")
            ),
            change("Default Flashlight", current.scannerFlashlightMode, scannerFlashlightMode) { ScannerFlashlightMode(rawValue: $0) },
            change("Default Zoom", current.scannerZoomLevel, scannerZoomLevel) { ScannerZoomLevel(rawValue: $0) },
            change("Scan Area", current.scannerScanArea, scannerScanArea) { ScannerScanArea(rawValue: $0) },
        ]
        if returnTarget == ReturnTarget.custom.rawValue {
            result.append(change("Custom Return URL", current.customReturnURL, customReturnURL) {
                $0.isEmpty ? NSLocalizedString("None", comment: "No custom URL profile value") : $0
            })
        }
        if let keyboardAppearance {
            result.append(change("Keyboard Appearance", current.keyboardAppearance ?? KeyboardAppearance.system.rawValue,
                                 keyboardAppearance) { KeyboardAppearance(rawValue: $0) })
        }
        for (title, currentValue, incomingValue) in [
            ("Key Clicks", current.keyboardClickSound, keyboardClickSound),
            ("Key Haptics", current.keyboardHaptics, keyboardHaptics)
        ] {
            if let incomingValue {
                result.append(BlipCompanyProfileChange(title: title,
                    currentValue: Self.formatToggle(currentValue ?? true),
                    incomingValue: Self.formatToggle(incomingValue)))
            }
        }
        return result.filter { $0.currentValue != $0.incomingValue }
    }

    /// Values from the same immutable snapshot that is encoded in the QR code.
    var includedSettings: [BlipCompanyProfileSetting] {
        var settings = [
            BlipCompanyProfileSetting("Return Target", ReturnTarget(rawValue: returnTarget)?.title ?? returnTarget)
        ]
        if returnTarget == ReturnTarget.custom.rawValue {
            settings.append(.init("Custom Return URL", customReturnURL))
        }
        settings += [
            .init("Keyboard Language", KeyboardLanguage(rawValue: keyboardLanguage)?.title ?? keyboardLanguage),
            .init("Keyboard Type", KeyboardType(rawValue: keyboardType)?.title ?? keyboardType),
            .init("Enabled Layouts", Self.formatLayouts(enabledKeyboardLayouts)),
            .init("Opening Layout", Self.formatLayoutSlot(startupKeyboardLayout)),
            .init("Scan Suffix", InsertSuffix(rawValue: scanSuffix)?.title ?? scanSuffix)
        ]
        if let autoInsertScans { settings.append(.init("Insert Scans Automatically", Self.formatToggle(autoInsertScans))) }
        settings += [
            .init("Scan Formats", ScanFormatProfile(rawValue: scanFormatProfile)?.title ?? scanFormatProfile),
            .init("Blip Sound", Self.formatToggle(playScanSound)),
            .init("Default Flashlight", ScannerFlashlightMode(rawValue: scannerFlashlightMode)?.title ?? scannerFlashlightMode),
            .init("Default Zoom", ScannerZoomLevel(rawValue: scannerZoomLevel)?.title ?? scannerZoomLevel),
            .init("Scan Area", ScannerScanArea(rawValue: scannerScanArea)?.title ?? scannerScanArea)
        ]
        if let keyboardAppearance {
            settings.append(.init("Keyboard Appearance", KeyboardAppearance(rawValue: keyboardAppearance)?.title ?? keyboardAppearance))
        }
        if let keyboardClickSound { settings.append(.init("Key Clicks", Self.formatToggle(keyboardClickSound))) }
        if let keyboardHaptics { settings.append(.init("Key Haptics", Self.formatToggle(keyboardHaptics))) }
        return settings
    }

    private static func formatToggle(_ enabled: Bool) -> String {
        NSLocalizedString(enabled ? "On" : "Off", comment: "Profile toggle value")
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> BlipCompanyProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(BlipCompanyProfile.self, from: data)
        try profile.validate()
        return profile
    }

    private func change<Option>(
        _ title: String,
        _ currentRawValue: String,
        _ incomingRawValue: String,
        _ option: (String) -> Option?
    ) -> BlipCompanyProfileChange where Option: ProfileDisplayOption {
        BlipCompanyProfileChange(
            title: title,
            currentValue: option(currentRawValue)?.profileDisplayTitle ?? currentRawValue,
            incomingValue: option(incomingRawValue)?.profileDisplayTitle ?? incomingRawValue
        )
    }

    private func change(
        _ title: String,
        _ currentRawValue: String,
        _ incomingRawValue: String,
        _ format: (String) -> String
    ) -> BlipCompanyProfileChange {
        BlipCompanyProfileChange(
            title: title,
            currentValue: format(currentRawValue),
            incomingValue: format(incomingRawValue)
        )
    }

    private static func formatLayouts(_ rawValue: String) -> String {
        let slots = KeyboardLayoutSlot.slots(from: rawValue) ?? []
        guard !slots.isEmpty else {
            return NSLocalizedString("Scan Only", comment: "Scan only profile layout value")
        }

        return slots.map(\.title).joined(separator: ", ")
    }

    private static func formatLayoutSlot(_ rawValue: String) -> String {
        guard let slot = KeyboardLayoutSlot(rawValue: rawValue) else {
            return NSLocalizedString("Scan Only", comment: "Scan only profile startup layout value")
        }

        return slot.title
    }
}

struct BlipCompanyProfileSetting: Identifiable, Equatable {
    let title: String
    let value: String
    var id: String { title }

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }
}

struct BlipCompanyProfileChange: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let currentValue: String
    let incomingValue: String
}

enum BlipCompanyProfileError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return String(format: NSLocalizedString("Profile version %d is not supported.", comment: "Unsupported profile version error"), version)
        case .invalidValue(let field):
            return String(format: NSLocalizedString("The profile contains an invalid value for %@.", comment: "Invalid profile value error"), field)
        }
    }
}

/// A local transport for the same validated schema used by file import/export.
enum BlipCompanyProfileQR {
    static let marker = "BLIP_PROFILE:"
    static let prefix = marker + "1:"
    static let maximumBytes = 1_200

    static func acceptsScannedQR(_ value: String, formatProfile: ScanFormatProfile) -> Bool {
        formatProfile != .commonBarcodes || value.hasPrefix(marker)
    }

    static func encode(_ profile: BlipCompanyProfile) throws -> Data {
        try profile.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = Data(prefix.utf8) + (try encoder.encode(profile))
        guard payload.count <= maximumBytes else { throw BlipCompanyProfileQRError.tooLarge }
        return payload
    }

    static func decodeIfRecognized(_ value: String) throws -> BlipCompanyProfile? {
        guard value.hasPrefix(marker) else { return nil }
        guard value.utf8.count <= maximumBytes else { throw BlipCompanyProfileQRError.tooLarge }
        guard value.hasPrefix(prefix) else { throw BlipCompanyProfileQRError.unsupportedVersion }
        return try BlipCompanyProfile.decode(from: Data(value.dropFirst(prefix.count).utf8))
    }
}

enum BlipCompanyProfileQRError: LocalizedError {
    case tooLarge
    case unsupportedVersion
    case cannotRender

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            NSLocalizedString("This profile is too large for a readable QR code. Use file export and import instead.", comment: "Profile QR size error")
        case .unsupportedVersion:
            NSLocalizedString("This company profile QR version is not supported.", comment: "Profile QR version error")
        case .cannotRender:
            NSLocalizedString("The company profile QR code could not be created. Use file export instead.", comment: "Profile QR rendering error")
        }
    }
}

private protocol ProfileDisplayOption {
    var profileDisplayTitle: String { get }
}

extension KeyboardLanguage: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension KeyboardAppearance: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension KeyboardType: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension InsertSuffix: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension ScanFormatProfile: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension ReturnTarget: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension ScannerFlashlightMode: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension ScannerZoomLevel: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}

extension ScannerScanArea: ProfileDisplayOption {
    var profileDisplayTitle: String { title }
}
