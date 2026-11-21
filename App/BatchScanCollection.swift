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

    /// The value as VoiceOver speaks it in labels and announcements: long
    /// payloads are cut so they are not read in full every time.
    var spokenValue: String {
        Self.spokenPreview(of: value)
    }

    static func spokenPreview(of value: String, limit: Int = 40) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "…"
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
        /// Duplicates are skipped and the value is already in the list.
        case duplicate
    }

    let maximumCount: Int
    private(set) var entries: [BatchScanEntry] = []

    init(maximumCount: Int = BatchScanLimit.maximumCodeCount) {
        self.maximumCount = maximumCount
    }

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }
    var isFull: Bool { entries.count >= maximumCount }

    /// A skipped duplicate is reported as such even when the list is full: it
    /// would not have been added with room either.
    mutating func append(_ entry: BatchScanEntry, skippingDuplicates: Bool = false) -> AppendOutcome {
        if skippingDuplicates, contains(value: entry.value) { return .duplicate }
        guard !isFull else { return .full }
        entries.append(entry)
        return .added(count: entries.count)
    }

    func contains(value: String) -> Bool {
        entries.contains { $0.value == value }
    }

    /// Entries whose value already appears earlier in the list.
    var repeatedEntryIDs: Set<BatchScanEntry.ID> {
        var seen = Set<String>()
        var repeated = Set<BatchScanEntry.ID>()
        for entry in entries where !seen.insert(entry.value).inserted {
            repeated.insert(entry.id)
        }
        return repeated
    }

    /// Removes an entry and returns it with its position, so it can be restored.
    @discardableResult
    mutating func remove(id: BatchScanEntry.ID) -> (entry: BatchScanEntry, index: Int)? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return (entries.remove(at: index), index)
    }

    /// Puts a removed entry back at its old position (or at the end if the list
    /// has become shorter). Refused when the list is full or already has it.
    mutating func restore(_ entry: BatchScanEntry, at index: Int) -> Bool {
        guard !isFull, !entries.contains(where: { $0.id == entry.id }) else { return false }
        entries.insert(entry, at: min(max(index, 0), entries.count))
        return true
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

extension BatchSeparator {
    /// Whether the value contains this separator, which makes the joined text
    /// ambiguous. Space also matches other whitespace and line breaks, New Line
    /// also a carriage return: receiving fields treat them alike.
    func occurs(in value: String) -> Bool {
        let characters: CharacterSet
        switch self {
        case .comma:
            characters = CharacterSet(charactersIn: ",")
        case .semicolon:
            characters = CharacterSet(charactersIn: ";")
        case .space:
            characters = .whitespacesAndNewlines
        case .tab:
            characters = CharacterSet(charactersIn: "\t")
        case .newline:
            characters = .newlines
        }
        // Scalars, not Characters: "\r\n" is a single Character in Swift.
        return value.unicodeScalars.contains { characters.contains($0) }
    }
}
