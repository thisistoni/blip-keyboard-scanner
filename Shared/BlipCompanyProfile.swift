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
    let scanFormatProfile: String
    let returnTarget: String
    let customReturnURL: String
    let playScanSound: Bool
    let scannerFlashlightMode: String
    let scannerZoomLevel: String
    let scannerScanArea: String

    static var current: BlipCompanyProfile {
        BlipCompanyProfile(
            profileVersion: currentVersion,
            exportedAt: Date(),
            keyboardLanguage: SharedKeyboardState.keyboardLanguage.rawValue,
            keyboardType: SharedKeyboardState.keyboardType.rawValue,
            enabledKeyboardLayouts: SharedKeyboardState.enabledKeyboardLayoutSlotsRawValue,
            startupKeyboardLayout: SharedKeyboardState.startupKeyboardLayoutSlotRawValue,
            scanSuffix: SharedKeyboardState.insertSuffix.rawValue,
            scanFormatProfile: SharedKeyboardState.scanFormatProfile.rawValue,
            returnTarget: SharedKeyboardState.returnTarget.rawValue,
            customReturnURL: SharedKeyboardState.customReturnURL,
            playScanSound: SharedKeyboardState.playScanSound,
            scannerFlashlightMode: SharedKeyboardState.scannerFlashlightMode.rawValue,
            scannerZoomLevel: SharedKeyboardState.scannerZoomLevel.rawValue,
            scannerScanArea: SharedKeyboardState.scannerScanArea.rawValue
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
    }

    func apply() throws {
        try validate()

        SharedKeyboardState.keyboardLanguage = KeyboardLanguage(rawValue: keyboardLanguage) ?? .english
        SharedKeyboardState.keyboardType = KeyboardType(rawValue: keyboardType) ?? .standard
        SharedKeyboardState.enabledKeyboardLayoutSlots = KeyboardLayoutSlot.slots(from: enabledKeyboardLayouts) ?? KeyboardLayoutSlot.allCases
        SharedKeyboardState.startupKeyboardLayoutSlot = startupKeyboardLayout.isEmpty ? nil : KeyboardLayoutSlot(rawValue: startupKeyboardLayout)
        SharedKeyboardState.insertSuffix = InsertSuffix(rawValue: scanSuffix) ?? .none
        SharedKeyboardState.scanFormatProfile = ScanFormatProfile(rawValue: scanFormatProfile) ?? .allSupported
        SharedKeyboardState.returnTarget = ReturnTarget(rawValue: returnTarget) ?? .safari
        SharedKeyboardState.customReturnURL = customReturnURL
        SharedKeyboardState.playScanSound = playScanSound
        SharedKeyboardState.scannerFlashlightMode = ScannerFlashlightMode(rawValue: scannerFlashlightMode) ?? .off
        SharedKeyboardState.scannerZoomLevel = ScannerZoomLevel(rawValue: scannerZoomLevel) ?? .x1
        SharedKeyboardState.scannerScanArea = ScannerScanArea(rawValue: scannerScanArea) ?? .fullFrame
    }

    func changes(comparedTo current: BlipCompanyProfile = .current) -> [BlipCompanyProfileChange] {
        [
            change("Keyboard Language", current.keyboardLanguage, keyboardLanguage) { KeyboardLanguage(rawValue: $0) },
            change("Keyboard Type", current.keyboardType, keyboardType) { KeyboardType(rawValue: $0) },
            change("Enabled Layouts", current.enabledKeyboardLayouts, enabledKeyboardLayouts, BlipCompanyProfile.formatLayouts),
            change("Opening Layout", current.startupKeyboardLayout, startupKeyboardLayout, BlipCompanyProfile.formatLayoutSlot),
            change("Scan Suffix", current.scanSuffix, scanSuffix) { InsertSuffix(rawValue: $0) },
            change("Scan Formats", current.scanFormatProfile, scanFormatProfile) { ScanFormatProfile(rawValue: $0) },
            change("Return Target", current.returnTarget, returnTarget) { ReturnTarget(rawValue: $0) },
            change("Custom Return URL", current.customReturnURL, customReturnURL) { $0.isEmpty ? NSLocalizedString("None", comment: "No custom URL profile value") : $0 },
            BlipCompanyProfileChange(
                title: "Blip Sound",
                currentValue: current.playScanSound ? NSLocalizedString("On", comment: "Profile sound on value") : NSLocalizedString("Off", comment: "Profile sound off value"),
                incomingValue: playScanSound ? NSLocalizedString("On", comment: "Profile sound on value") : NSLocalizedString("Off", comment: "Profile sound off value")
            ),
            change("Default Flashlight", current.scannerFlashlightMode, scannerFlashlightMode) { ScannerFlashlightMode(rawValue: $0) },
            change("Default Zoom", current.scannerZoomLevel, scannerZoomLevel) { ScannerZoomLevel(rawValue: $0) },
            change("Scan Area", current.scannerScanArea, scannerScanArea) { ScannerScanArea(rawValue: $0) },
        ]
        .filter { $0.currentValue != $0.incomingValue }
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

private protocol ProfileDisplayOption {
    var profileDisplayTitle: String { get }
}

extension KeyboardLanguage: ProfileDisplayOption {
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
