import Foundation

enum KeyboardLanguage: String, CaseIterable, Identifiable {
    case english
    case german

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            NSLocalizedString("English", comment: "English language option")
        case .german:
            NSLocalizedString("German", comment: "German language option")
        }
    }

    var alphabetLayout: KeyboardLayout {
        switch self {
        case .english:
            .english
        case .german:
            .german
        }
    }
}

enum KeyboardType: String, CaseIterable, Identifiable {
    case standard
    case largeNumbers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            NSLocalizedString("Standard", comment: "Standard keyboard type")
        case .largeNumbers:
            NSLocalizedString("Large Numbers", comment: "Large number keyboard type")
        }
    }

    var description: String {
        switch self {
        case .standard:
            NSLocalizedString("Starts with the normal letter keyboard.", comment: "Standard keyboard type description")
        case .largeNumbers:
            NSLocalizedString("Starts with a large number pad for scan-heavy workflows.", comment: "Large number keyboard type description")
        }
    }
}

enum KeyboardLayoutSlot: String, CaseIterable, Identifiable {
    case letters
    case symbols
    case largeNumbers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letters:
            NSLocalizedString("Letters", comment: "Letters keyboard layout slot")
        case .symbols:
            NSLocalizedString("Numbers & Symbols", comment: "Numbers and symbols keyboard layout slot")
        case .largeNumbers:
            NSLocalizedString("Big Numbers", comment: "Big numbers keyboard layout slot")
        }
    }

    var shortTitle: String {
        switch self {
        case .letters:
            "ABC"
        case .symbols:
            "123"
        case .largeNumbers:
            "NUM"
        }
    }

    var description: String {
        switch self {
        case .letters:
            NSLocalizedString("Standard letters with the selected language.", comment: "Letters keyboard layout slot description")
        case .symbols:
            NSLocalizedString("Numbers and punctuation in the standard keyboard style.", comment: "Numbers and symbols keyboard layout slot description")
        case .largeNumbers:
            NSLocalizedString("Large number pad for fast quantity and article entry.", comment: "Big numbers keyboard layout slot description")
        }
    }

    func keyboardLayout(for language: KeyboardLanguage) -> KeyboardLayout {
        switch self {
        case .letters:
            language.alphabetLayout
        case .symbols:
            .numeric
        case .largeNumbers:
            .largeNumbers
        }
    }

    static func slot(for layout: KeyboardLayout, language: KeyboardLanguage) -> KeyboardLayoutSlot? {
        if layout == language.alphabetLayout {
            return .letters
        }

        switch layout {
        case .numeric:
            return .symbols
        case .largeNumbers:
            return .largeNumbers
        case .scanOnly:
            return nil
        default:
            return layout.isAlphabetic ? .letters : nil
        }
    }

    static func rawValue(for slots: [KeyboardLayoutSlot]) -> String {
        slots.map(\.rawValue).joined(separator: ",")
    }

    static func slots(from rawValue: String?) -> [KeyboardLayoutSlot]? {
        guard let rawValue else {
            return nil
        }

        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let parsedSlots = rawValue
            .split(separator: ",")
            .compactMap { KeyboardLayoutSlot(rawValue: String($0)) }

        let uniqueSlots = KeyboardLayoutSlot.allCases.filter { parsedSlots.contains($0) }
        return uniqueSlots
    }
}

enum KeyboardLayout: String {
    case english
    case german
    case numeric
    case largeNumbers
    case scanOnly

    var title: String {
        switch self {
        case .english:
            NSLocalizedString("English", comment: "English keyboard layout")
        case .german:
            NSLocalizedString("German", comment: "German keyboard layout")
        case .numeric:
            NSLocalizedString("Numbers", comment: "Numeric keyboard layout")
        case .largeNumbers:
            NSLocalizedString("Large Numbers", comment: "Large numeric keyboard layout")
        case .scanOnly:
            NSLocalizedString("Scan Only", comment: "Scan-only keyboard layout")
        }
    }

    var description: String {
        switch self {
        case .english:
            NSLocalizedString("English alphabet keyboard.", comment: "English keyboard layout description")
        case .german:
            NSLocalizedString("German QWERTZ keyboard.", comment: "German keyboard layout description")
        case .numeric:
            NSLocalizedString("Number and punctuation keyboard.", comment: "Numeric keyboard layout description")
        case .largeNumbers:
            NSLocalizedString("Large number pad keyboard.", comment: "Large numeric keyboard layout description")
        case .scanOnly:
            NSLocalizedString("Only the scan button is shown.", comment: "Scan-only keyboard layout description")
        }
    }

    var isAlphabetic: Bool {
        switch self {
        case .english, .german:
            true
        case .numeric, .largeNumbers, .scanOnly:
            false
        }
    }
}

enum InsertSuffix: String, CaseIterable, Identifiable {
    case none
    case tab
    case newline
    case space

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            NSLocalizedString("None", comment: "No scan suffix")
        case .tab:
            NSLocalizedString("Tab", comment: "Tab scan suffix")
        case .newline:
            NSLocalizedString("Enter", comment: "Enter scan suffix")
        case .space:
            NSLocalizedString("Space", comment: "Space scan suffix")
        }
    }

    var text: String {
        switch self {
        case .none:
            ""
        case .tab:
            "\t"
        case .newline:
            "\n"
        case .space:
            " "
        }
    }
}

enum ScannerFlashlightMode: String, CaseIterable, Identifiable {
    case off
    case on

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            NSLocalizedString("Off", comment: "Flashlight off")
        case .on:
            NSLocalizedString("On", comment: "Flashlight on")
        }
    }
}

enum ScanFormatProfile: String, CaseIterable, Identifiable {
    case commonBarcodes
    case barcodesAndQR
    case allSupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commonBarcodes:
            NSLocalizedString("Common Barcodes", comment: "Common barcode scan format profile")
        case .barcodesAndQR:
            NSLocalizedString("Barcodes + QR", comment: "Barcode and QR scan format profile")
        case .allSupported:
            NSLocalizedString("All Supported Formats", comment: "All supported scan format profile")
        }
    }

    var detail: String {
        switch self {
        case .commonBarcodes:
            NSLocalizedString("Fast 1D formats for retail, warehouse, and product codes.", comment: "Common barcode scan format detail")
        case .barcodesAndQR:
            NSLocalizedString("Common barcodes plus QR codes for general company workflows.", comment: "Barcode and QR scan format detail")
        case .allSupported:
            NSLocalizedString("Every format supported by this scanner, including QR, Data Matrix, PDF417, and Aztec.", comment: "All supported scan format detail")
        }
    }
}

enum ReturnTarget: String, CaseIterable, Identifiable {
    case safari
    case chrome
    case edge
    case firefox
    case brave
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safari:
            "Safari"
        case .chrome:
            "Chrome"
        case .edge:
            "Edge"
        case .firefox:
            "Firefox"
        case .brave:
            "Brave"
        case .custom:
            NSLocalizedString("Custom", comment: "Custom return target")
        }
    }

    var detail: String {
        switch self {
        case .safari:
            NSLocalizedString("Return to Safari after a keyboard-launched scan.", comment: "Safari return target detail")
        case .chrome:
            NSLocalizedString("Return to Google Chrome after a keyboard-launched scan.", comment: "Chrome return target detail")
        case .edge:
            NSLocalizedString("Return to Microsoft Edge after a keyboard-launched scan.", comment: "Edge return target detail")
        case .firefox:
            NSLocalizedString("Return to Firefox after a keyboard-launched scan.", comment: "Firefox return target detail")
        case .brave:
            NSLocalizedString("Return to Brave after a keyboard-launched scan.", comment: "Brave return target detail")
        case .custom:
            NSLocalizedString("Use a custom app URL scheme.", comment: "Custom return target detail")
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .safari:
            "com.apple.mobilesafari"
        case .chrome:
            "com.google.chrome.ios"
        case .edge:
            "com.microsoft.msedge"
        case .firefox:
            "org.mozilla.ios.Firefox"
        case .brave:
            "com.brave.ios.browser"
        case .custom:
            nil
        }
    }

    func urlCandidates(customURLString: String) -> [URL] {
        switch self {
        case .safari:
            return compactURLs([
                "x-web-search://",
                "x-safari-https://"
            ])
        case .chrome:
            return compactURLs(["googlechrome://"])
        case .edge:
            return compactURLs(["microsoft-edge://"])
        case .firefox:
            return compactURLs(["firefox://"])
        case .brave:
            return compactURLs(["brave://"])
        case .custom:
            let trimmed = customURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }

            if trimmed.contains("://") {
                return compactURLs([trimmed])
            }

            return compactURLs([trimmed + "://"])
        }
    }

    private func compactURLs(_ strings: [String]) -> [URL] {
        strings.compactMap(URL.init(string:))
    }
}

struct KeyboardSetupSnapshot: Equatable {
    let isEnabled: Bool
    let rawKeyboards: [String]
    let matchedKeyboard: String?

    var rawKeyboardSummary: String {
        guard !rawKeyboards.isEmpty else {
            return NSLocalizedString("No AppleKeyboards entries visible to the app.", comment: "No keyboard diagnostics entries visible")
        }
        return rawKeyboards.joined(separator: "\n")
    }
}

struct KeyboardScanRequest: Equatable, Identifiable {
    let id: String
    let source: String

    var launchedFromKeyboard: Bool {
        source == "keyboard"
    }

    init(id: String = UUID().uuidString, source: String = "app") {
        self.id = id
        self.source = source
    }

    init?(url: URL) {
        guard url.scheme == "blip", url.host == "scan" else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let requestID = items.first { $0.name == "id" }?.value
        let source = items.first { $0.name == "source" }?.value ?? "app"

        self.id = requestID?.isEmpty == false ? requestID! : UUID().uuidString
        self.source = source
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "blip"
        components.host = "scan"
        components.queryItems = [
            URLQueryItem(name: "source", value: source),
            URLQueryItem(name: "id", value: id),
        ]

        return components.url ?? URL(string: "blip://scan?source=\(source)&id=\(id)")!
    }
}

enum SharedKeyboardState {
    static let appGroupIdentifier = "group.com.antoniobeslic.Blip"
    static let containingAppBundleIdentifier = "com.antoniobeslic.Blip"
    static let keyboardExtensionBundleIdentifier = "com.antoniobeslic.Blip.KeyboardExtension"
    static let keyboardDisplayName = "Blip"

    enum Keys {
        static let selectedLayout = "selectedLayout"
        static let keyboardLanguage = "keyboardLanguage"
        static let keyboardType = "keyboardType"
        static let enabledKeyboardLayoutSlots = "enabledKeyboardLayoutSlots"
        static let startupKeyboardLayoutSlot = "startupKeyboardLayoutSlot"
        static let insertSuffix = "insertSuffix"
        static let lastScannedCode = "lastScannedCode"
        static let pendingScannedCode = "pendingScannedCode"
        static let pendingScanIdentifier = "pendingScanIdentifier"
        static let consumedScanIdentifier = "consumedScanIdentifier"
        static let activeScanRequestIdentifier = "activeScanRequestIdentifier"
        static let keyboardWasActivated = "keyboardWasActivated"
        static let keyboardHasFullAccess = "keyboardHasFullAccess"
        static let keyboardLastSeenAt = "keyboardLastSeenAt"
        static let currentSetupVerificationToken = "currentSetupVerificationToken"
        static let verifiedSetupToken = "verifiedSetupToken"
        static let verifiedSetupHasFullAccess = "verifiedSetupHasFullAccess"
        static let scannerFlashlightMode = "scannerFlashlightMode"
        static let scanFormatProfile = "scanFormatProfile"
        static let playScanSound = "playScanSound"
        static let returnTarget = "returnTarget"
        static let customReturnURL = "customReturnURL"
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static var appStorageDefaults: UserDefaults {
        defaults ?? .standard
    }

    static var canAccessAppGroup: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil && defaults != nil
    }

    static var currentSetupVerificationToken: String {
        defaults?.string(forKey: Keys.currentSetupVerificationToken) ?? ""
    }

    static var verifiedSetupToken: String {
        defaults?.string(forKey: Keys.verifiedSetupToken) ?? ""
    }

    static var verifiedSetupHasFullAccess: Bool {
        defaults?.bool(forKey: Keys.verifiedSetupHasFullAccess) ?? false
    }

    static var keyboardLastSeenAt: TimeInterval {
        defaults?.double(forKey: Keys.keyboardLastSeenAt) ?? 0
    }

    static var isKeyboardEnabledInSystemSettings: Bool {
        keyboardSetupSnapshot.isEnabled
    }

    static var keyboardSetupSnapshot: KeyboardSetupSnapshot {
        UserDefaults.standard.synchronize()

        let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] ?? []
        let needles = [
            keyboardExtensionBundleIdentifier,
            containingAppBundleIdentifier,
            keyboardDisplayName,
            "Blip",
            "BlipKeyboard",
            "BlipKeyboardExtension",
            "Blip Keyboard",
        ].map(normalizedKeyboardIdentifier)

        let matchedKeyboard = keyboards.first { keyboard in
            let normalizedKeyboard = normalizedKeyboardIdentifier(keyboard)
            return needles.contains { normalizedKeyboard.contains($0) }
        }

        return KeyboardSetupSnapshot(
            isEnabled: matchedKeyboard != nil,
            rawKeyboards: keyboards,
            matchedKeyboard: matchedKeyboard
        )
    }

    static func beginSetupVerificationSession() {
        defaults?.set(UUID().uuidString, forKey: Keys.currentSetupVerificationToken)
    }

    static var selectedLayout: KeyboardLayout {
        get {
            defaultKeyboardLayout
        }
        set {
            switch newValue {
            case .english:
                keyboardLanguage = .english
                keyboardType = .standard
            case .german:
                keyboardLanguage = .german
                keyboardType = .standard
            case .numeric, .largeNumbers:
                keyboardType = .largeNumbers
            case .scanOnly:
                enabledKeyboardLayoutSlots = []
            }
        }
    }

    static var keyboardLanguage: KeyboardLanguage {
        get {
            let rawValue = defaults?.string(forKey: Keys.keyboardLanguage)
                ?? defaults?.string(forKey: Keys.selectedLayout)
                ?? KeyboardLanguage.english.rawValue

            switch rawValue {
            case "german":
                return .german
            default:
                return KeyboardLanguage(rawValue: rawValue) ?? .english
            }
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Keys.keyboardLanguage)
        }
    }

    static var keyboardType: KeyboardType {
        get {
            let rawValue = defaults?.string(forKey: Keys.keyboardType)
                ?? defaults?.string(forKey: Keys.selectedLayout)
                ?? KeyboardType.standard.rawValue

            switch rawValue {
            case "numeric", "compact", "largeNumbers":
                return .largeNumbers
            default:
                return KeyboardType(rawValue: rawValue) ?? .standard
            }
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Keys.keyboardType)
        }
    }

    static var enabledKeyboardLayoutSlots: [KeyboardLayoutSlot] {
        get {
            if let slots = KeyboardLayoutSlot.slots(from: defaults?.string(forKey: Keys.enabledKeyboardLayoutSlots)) {
                return slots
            }

            return KeyboardLayoutSlot.allCases
        }
        set {
            let uniqueSlots = KeyboardLayoutSlot.allCases.filter { newValue.contains($0) }
            defaults?.set(KeyboardLayoutSlot.rawValue(for: uniqueSlots), forKey: Keys.enabledKeyboardLayoutSlots)

            guard let startupSlot = startupKeyboardLayoutSlot else {
                defaults?.set(uniqueSlots.first?.rawValue ?? "", forKey: Keys.startupKeyboardLayoutSlot)
                return
            }

            if !uniqueSlots.contains(startupSlot) {
                defaults?.set(uniqueSlots.first?.rawValue ?? "", forKey: Keys.startupKeyboardLayoutSlot)
            }
        }
    }

    static var enabledKeyboardLayoutSlotsRawValue: String {
        KeyboardLayoutSlot.rawValue(for: enabledKeyboardLayoutSlots)
    }

    static var startupKeyboardLayoutSlot: KeyboardLayoutSlot? {
        get {
            let enabledSlots = enabledKeyboardLayoutSlots
            guard !enabledSlots.isEmpty else { return nil }

            if let rawValue = defaults?.string(forKey: Keys.startupKeyboardLayoutSlot),
               let slot = KeyboardLayoutSlot(rawValue: rawValue),
               enabledSlots.contains(slot) {
                return slot
            }

            switch keyboardType {
            case .standard:
                return enabledSlots.contains(.letters) ? .letters : enabledSlots.first
            case .largeNumbers:
                return enabledSlots.contains(.largeNumbers) ? .largeNumbers : enabledSlots.first
            }
        }
        set {
            defaults?.set(newValue?.rawValue ?? "", forKey: Keys.startupKeyboardLayoutSlot)
        }
    }

    static var startupKeyboardLayoutSlotRawValue: String {
        startupKeyboardLayoutSlot?.rawValue ?? ""
    }

    static var defaultKeyboardLayout: KeyboardLayout {
        startupKeyboardLayoutSlot?.keyboardLayout(for: keyboardLanguage) ?? .scanOnly
    }

    static func nextKeyboardLayout(after layout: KeyboardLayout) -> KeyboardLayout? {
        let enabledSlots = enabledKeyboardLayoutSlots
        guard enabledSlots.count > 1 else { return nil }

        let currentSlot = KeyboardLayoutSlot.slot(for: layout, language: keyboardLanguage) ?? enabledSlots[0]
        let currentIndex = enabledSlots.firstIndex(of: currentSlot) ?? 0
        let nextIndex = enabledSlots.index(after: currentIndex)
        let nextSlot = nextIndex == enabledSlots.endIndex ? enabledSlots[enabledSlots.startIndex] : enabledSlots[nextIndex]

        return nextSlot.keyboardLayout(for: keyboardLanguage)
    }

    static func nextKeyboardLayoutTitle(after layout: KeyboardLayout) -> String? {
        guard let nextLayout = nextKeyboardLayout(after: layout),
              let nextSlot = KeyboardLayoutSlot.slot(for: nextLayout, language: keyboardLanguage)
        else {
            return nil
        }

        return nextSlot.shortTitle
    }

    static var insertSuffix: InsertSuffix {
        get {
            let rawValue = defaults?.string(forKey: Keys.insertSuffix) ?? InsertSuffix.none.rawValue
            return InsertSuffix(rawValue: rawValue) ?? .none
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Keys.insertSuffix)
        }
    }

    static var lastScannedCode: String {
        get {
            defaults?.string(forKey: Keys.lastScannedCode) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: Keys.lastScannedCode)
        }
    }

    static var pendingScannedCode: String {
        defaults?.string(forKey: Keys.pendingScannedCode) ?? ""
    }

    static var pendingScanIdentifier: String {
        defaults?.string(forKey: Keys.pendingScanIdentifier) ?? ""
    }

    static var activeScanRequestIdentifier: String {
        get {
            defaults?.string(forKey: Keys.activeScanRequestIdentifier) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: Keys.activeScanRequestIdentifier)
        }
    }

    static var consumedScanIdentifier: String {
        get {
            defaults?.string(forKey: Keys.consumedScanIdentifier) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: Keys.consumedScanIdentifier)
        }
    }

    static var returnTarget: ReturnTarget {
        get {
            let rawValue = defaults?.string(forKey: Keys.returnTarget) ?? ReturnTarget.safari.rawValue
            return ReturnTarget(rawValue: rawValue) ?? .safari
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Keys.returnTarget)
        }
    }

    static var customReturnURL: String {
        get {
            defaults?.string(forKey: Keys.customReturnURL) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: Keys.customReturnURL)
        }
    }

    static var playScanSound: Bool {
        get {
            guard let defaults,
                  defaults.object(forKey: Keys.playScanSound) != nil
            else {
                return true
            }

            return defaults.bool(forKey: Keys.playScanSound)
        }
        set {
            defaults?.set(newValue, forKey: Keys.playScanSound)
        }
    }

    static var scanFormatProfile: ScanFormatProfile {
        get {
            let rawValue = defaults?.string(forKey: Keys.scanFormatProfile) ?? ScanFormatProfile.allSupported.rawValue
            return ScanFormatProfile(rawValue: rawValue) ?? .allSupported
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Keys.scanFormatProfile)
        }
    }

    static func queuePendingInsertion(_ code: String, requestIdentifier: String? = nil) {
        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedCode.isEmpty else { return }

        let identifier = requestIdentifier?.isEmpty == false ? requestIdentifier! : UUID().uuidString
        defaults?.set(cleanedCode, forKey: Keys.lastScannedCode)
        defaults?.set(cleanedCode, forKey: Keys.pendingScannedCode)
        defaults?.set(identifier, forKey: Keys.pendingScanIdentifier)
    }

    static func recordKeyboardRuntime(hasFullAccess: Bool) {
        let token = currentSetupVerificationToken

        defaults?.set(true, forKey: Keys.keyboardWasActivated)
        defaults?.set(hasFullAccess, forKey: Keys.keyboardHasFullAccess)
        defaults?.set(Date().timeIntervalSince1970, forKey: Keys.keyboardLastSeenAt)

        guard !token.isEmpty else { return }

        defaults?.set(token, forKey: Keys.verifiedSetupToken)
        defaults?.set(hasFullAccess, forKey: Keys.verifiedSetupHasFullAccess)
    }

    static func scanURL(requestIdentifier: String = UUID().uuidString) -> URL {
        let request = KeyboardScanRequest(id: requestIdentifier, source: "keyboard")
        return request.url
    }

    private static func normalizedKeyboardIdentifier(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
