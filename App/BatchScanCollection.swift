import Foundation

/// One code collected during a batch scan, kept exactly as decoded.
struct BatchScanEntry: Identifiable, Equatable {
    let id: UUID
    let value: String
    let codeFormat: String?
    let scannedAt: Date

    init(id: UUID = UUID(), value: String, codeFormat: String?, scannedAt: Date = Date()) {
        self.id = id
        self.value = value
        self.codeFormat = codeFormat
        self.scannedAt = scannedAt
    }
}

/// The ordered list of codes of one batch scan. Pure value type (Foundation
/// plus the shared settings enums) so it is tested without a camera. Values are
/// never trimmed, validated or deduplicated here: the scanner's re-scan guard
/// decides when the same code may be added again.
struct BatchScanCollection: Equatable {
    enum AppendOutcome: Equatable {
        /// The code was added; `count` is the new number of codes.
        case added(count: Int)
        /// The batch already holds `BatchScanLimit.maximumCodeCount` codes.
        case full
    }

    let maximumCount: Int
    private(set) var entries: [BatchScanEntry] = []

    init(maximumCount: Int = BatchScanLimit.maximumCodeCount) {
        self.maximumCount = maximumCount
    }

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }
    var isFull: Bool { entries.count >= maximumCount }

    mutating func append(_ entry: BatchScanEntry) -> AppendOutcome {
        guard !isFull else { return .full }
        entries.append(entry)
        return .added(count: entries.count)
    }

    mutating func remove(id: BatchScanEntry.ID) {
        entries.removeAll { $0.id == id }
    }

    mutating func removeAll() {
        entries.removeAll()
    }

    /// The text inserted for the whole batch: codes in scan order with the
    /// separator between them and none after the last one. The Insert Suffix is
    /// applied later by the keyboard, once, exactly as for a single scan.
    func joinedText(separator: BatchSeparator) -> String {
        entries.map(\.value).joined(separator: separator.text)
    }
}
