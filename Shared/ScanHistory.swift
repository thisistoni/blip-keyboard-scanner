import Foundation

enum ScanHistorySource: String, Codable, CaseIterable, Identifiable {
    case app
    case keyboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app:
            NSLocalizedString("App Scan", comment: "History source for app-launched scan")
        case .keyboard:
            NSLocalizedString("Keyboard Scan", comment: "History source for keyboard-launched scan")
        }
    }
}

enum ScanInsertionStatus: String, Codable, CaseIterable, Identifiable {
    case notQueued
    case queuedForKeyboardInsertion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notQueued:
            NSLocalizedString("Not queued", comment: "History insertion status not queued")
        case .queuedForKeyboardInsertion:
            NSLocalizedString("Inserted by keyboard", comment: "History insertion status inserted by keyboard")
        }
    }
}

struct ScanHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let value: String
    let codeFormat: String?
    let scannedAt: Date
    let source: ScanHistorySource
    let returnTargetRawValue: String?
    let insertionStatus: ScanInsertionStatus

    init(
        id: UUID = UUID(),
        value: String,
        codeFormat: String?,
        scannedAt: Date = Date(),
        source: ScanHistorySource,
        returnTargetRawValue: String?,
        insertionStatus: ScanInsertionStatus
    ) {
        self.id = id
        self.value = value
        self.codeFormat = codeFormat
        self.scannedAt = scannedAt
        self.source = source
        self.returnTargetRawValue = returnTargetRawValue
        self.insertionStatus = insertionStatus
    }

    var returnTarget: ReturnTarget? {
        guard let returnTargetRawValue else { return nil }
        return ReturnTarget(rawValue: returnTargetRawValue)
    }

    var displayCodeFormat: String {
        guard let codeFormat, !codeFormat.isEmpty else {
            return NSLocalizedString("Unknown format", comment: "Unknown scan history code format")
        }

        let normalized = codeFormat
            .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            .replacingOccurrences(of: "Symbology", with: "")

        switch normalized.lowercased() {
        case "aztec":
            return "Aztec"
        case "code39":
            return "Code 39"
        case "code128":
            return "Code 128"
        case "datamatrix":
            return "Data Matrix"
        case "ean8":
            return "EAN-8"
        case "ean13":
            return "EAN-13"
        case "i2of5":
            return "ITF"
        case "itf14":
            return "ITF-14"
        case "pdf417":
            return "PDF417"
        case "qr":
            return "QR"
        case "upce":
            return "UPC-E"
        default:
            return normalized
        }
    }
}

enum ScanHistoryRetention: String, CaseIterable, Identifiable {
    case off
    case oneDay
    case sevenDays
    case thirtyDays
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            NSLocalizedString("Off", comment: "History retention off")
        case .oneDay:
            NSLocalizedString("24 Hours", comment: "History retention one day")
        case .sevenDays:
            NSLocalizedString("7 Days", comment: "History retention seven days")
        case .thirtyDays:
            NSLocalizedString("30 Days", comment: "History retention thirty days")
        case .forever:
            NSLocalizedString("Forever", comment: "History retention forever")
        }
    }

    var detail: String {
        switch self {
        case .off:
            NSLocalizedString("Do not store scan history.", comment: "History retention off detail")
        case .oneDay:
            NSLocalizedString("Keep scans from the last 24 hours.", comment: "History retention one day detail")
        case .sevenDays:
            NSLocalizedString("Keep scans from the last 7 days.", comment: "History retention seven days detail")
        case .thirtyDays:
            NSLocalizedString("Keep scans from the last 30 days.", comment: "History retention thirty days detail")
        case .forever:
            NSLocalizedString("Keep scans until you delete them.", comment: "History retention forever detail")
        }
    }

    func cutoffDate(now: Date = Date()) -> Date? {
        switch self {
        case .off:
            return now
        case .oneDay:
            return Calendar.current.date(byAdding: .day, value: -1, to: now)
        case .sevenDays:
            return Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays:
            return Calendar.current.date(byAdding: .day, value: -30, to: now)
        case .forever:
            return nil
        }
    }
}

enum ScanHistoryStore {
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func items() -> [ScanHistoryItem] {
        rawItems().sorted { $0.scannedAt > $1.scannedAt }
    }

    @discardableResult
    static func applyRetention(now: Date = Date()) -> [ScanHistoryItem] {
        let retention = SharedKeyboardState.scanHistoryRetention

        guard retention != .off else {
            save([])
            return []
        }

        guard let cutoffDate = retention.cutoffDate(now: now) else {
            return items()
        }

        let filtered = rawItems().filter { $0.scannedAt >= cutoffDate }
        save(filtered)
        return filtered.sorted { $0.scannedAt > $1.scannedAt }
    }

    static func record(_ item: ScanHistoryItem) {
        guard SharedKeyboardState.scanHistoryRetention != .off else {
            save([])
            return
        }

        var currentItems = applyRetention()
        currentItems.insert(item, at: 0)
        save(currentItems)
        _ = applyRetention()
    }

    static func delete(_ item: ScanHistoryItem) {
        let filtered = rawItems().filter { $0.id != item.id }
        save(filtered)
        refreshLastScanAfterHistoryChange(filtered)
    }

    static func clear() {
        save([])
        SharedKeyboardState.lastScannedCode = ""
    }

    private static func rawItems() -> [ScanHistoryItem] {
        guard let data = SharedKeyboardState.defaults?.data(forKey: SharedKeyboardState.Keys.scanHistoryItems) else {
            return []
        }

        return (try? decoder.decode([ScanHistoryItem].self, from: data)) ?? []
    }

    private static func save(_ items: [ScanHistoryItem]) {
        guard let data = try? encoder.encode(items) else { return }
        SharedKeyboardState.defaults?.set(data, forKey: SharedKeyboardState.Keys.scanHistoryItems)
    }

    private static func refreshLastScanAfterHistoryChange(_ remainingItems: [ScanHistoryItem]) {
        guard !SharedKeyboardState.lastScannedCode.isEmpty else { return }

        let sortedItems = remainingItems.sorted { $0.scannedAt > $1.scannedAt }
        if let latestItem = sortedItems.first {
            SharedKeyboardState.lastScannedCode = latestItem.value
        } else {
            SharedKeyboardState.lastScannedCode = ""
        }
    }
}
