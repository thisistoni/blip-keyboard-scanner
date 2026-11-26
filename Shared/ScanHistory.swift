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
            NSLocalizedString("Queued for keyboard insertion", comment: "History insertion status queued for keyboard")
        }
    }
}

/// One code of a batch that History stores as a single entry.
struct ScanHistoryBatchCode: Codable, Equatable {
    let value: String
    let codeFormat: String?
}

struct ScanHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let value: String
    let codeFormat: String?
    let scannedAt: Date
    let source: ScanHistorySource
    let returnTargetRawValue: String?
    let insertionStatus: ScanInsertionStatus
    /// The codes, in scan order, when this entry is a whole batch; `value` is
    /// then the joined text exactly as it was inserted. Nil for a single scan,
    /// and in entries saved before batches were stored as one entry.
    let batchCodes: [ScanHistoryBatchCode]?

    init(
        id: UUID = UUID(),
        value: String,
        codeFormat: String?,
        scannedAt: Date = Date(),
        source: ScanHistorySource,
        returnTargetRawValue: String?,
        insertionStatus: ScanInsertionStatus,
        batchCodes: [ScanHistoryBatchCode]? = nil
    ) {
        self.id = id
        self.value = value
        self.codeFormat = codeFormat
        self.scannedAt = scannedAt
        self.source = source
        self.returnTargetRawValue = returnTargetRawValue
        self.insertionStatus = insertionStatus
        self.batchCodes = batchCodes
    }

    var isBatch: Bool { batchCodes != nil }

    var returnTarget: ReturnTarget? {
        guard let returnTargetRawValue else { return nil }
        return ReturnTarget(rawValue: returnTargetRawValue)
    }

    var displayCodeFormat: String {
        Self.displayName(forCodeFormat: codeFormat)
    }

    static func displayName(forCodeFormat codeFormat: String?) -> String {
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

/// History is a short list of recent scans, not an archive. It is stored as
/// one value that is read and written whole and that the keyboard loads with
/// the shared settings, so its size decides how long every scan takes. Both
/// limits apply whatever the retention setting; the oldest entries go first.
enum ScanHistoryLimit {
    /// More than anyone scrolls through, and about 11 ms to read on an M1.
    static let maximumEntryCount = 2_000
    /// The count alone does not bound long payloads: a batch entry can hold 50
    /// codes and a 2D code several kilobytes.
    static let maximumStoredBytes = 512 * 1024
}

enum ScanHistoryStore {
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    /// The newest of `items` (given newest first) that fit both limits, with
    /// their encoding. The newest entry is always kept.
    static func bounded(
        _ items: [ScanHistoryItem],
        maximumCount: Int = ScanHistoryLimit.maximumEntryCount,
        maximumBytes: Int = ScanHistoryLimit.maximumStoredBytes
    ) -> (items: [ScanHistoryItem], data: Data)? {
        var kept = items.count > maximumCount ? Array(items.prefix(maximumCount)) : items
        guard var data = try? encoder.encode(kept) else { return nil }
        while data.count > maximumBytes, kept.count > 1 {
            // Cut in proportion to the overshoot, a little further so one or
            // two passes are enough even when the entries differ in size.
            let fitting = kept.count * maximumBytes / data.count * 9 / 10
            kept = Array(kept.prefix(max(1, min(kept.count - 1, fitting))))
            guard let shorter = try? encoder.encode(kept) else { return nil }
            data = shorter
        }
        return (kept, data)
    }

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

        let stored = rawItems()
        var kept = stored
        if let cutoffDate = retention.cutoffDate(now: now) {
            kept = stored.filter { $0.scannedAt >= cutoffDate }
        }
        kept.sort { $0.scannedAt > $1.scannedAt }
        // Usually nothing has expired: leave the stored history untouched then.
        // A history saved before the limits existed is cut down here once.
        if kept.count != stored.count || kept.count > ScanHistoryLimit.maximumEntryCount {
            kept = save(kept)
        }
        return kept
    }

    static func record(_ item: ScanHistoryItem) {
        record(contentsOf: [item])
    }

    /// Records several scans (in scan order) with one read and write, e.g. a batch.
    static func record(contentsOf items: [ScanHistoryItem]) {
        let retention = SharedKeyboardState.scanHistoryRetention
        guard retention != .off else {
            save([])
            return
        }
        guard !items.isEmpty else { return }

        // The history is stored as one value, and this runs on the way back to
        // the keyboard: read it once and write it once.
        var currentItems = rawItems()
        if let cutoffDate = retention.cutoffDate() {
            currentItems.removeAll { $0.scannedAt < cutoffDate }
        }
        currentItems.sort { $0.scannedAt > $1.scannedAt }
        currentItems.insert(contentsOf: items.reversed(), at: 0)
        save(currentItems)
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

    /// Saves `items` (newest first) cut to the limits and returns what was kept.
    @discardableResult
    private static func save(_ items: [ScanHistoryItem]) -> [ScanHistoryItem] {
        guard let bounded = bounded(items) else { return items }
        SharedKeyboardState.defaults?.set(bounded.data, forKey: SharedKeyboardState.Keys.scanHistoryItems)
        return bounded.items
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
