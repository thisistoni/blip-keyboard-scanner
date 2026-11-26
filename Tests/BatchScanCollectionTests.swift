import Foundation

// Build and run with:
// xcrun swiftc Shared/KeyboardSettings.swift Shared/ScanHistory.swift App/BatchScanCollection.swift Tests/BatchScanCollectionTests.swift -o <tmp>/blip-batch-tests

@main
enum BatchScanCollectionTests {
    static func main() {
        skipsDuplicatesOnlyWhenAsked()
        joinsWithEverySeparatorWithoutTrailingSeparator()
        keepsValuesExactlyAsScanned()
        singleCodeBatchIsThePlainCode()
        stopsAtTheCap()
        removingAnEntryKeepsOrderAndFreesASlot()
        undoPutsAnEntryBackAtItsPosition()
        marksRepeatedValues()
        detectsCodesContainingTheSeparator()
        capsTheSpokenValue()
        reportsTheSharedFormatOnly()
        historyEntryKeepsTheBatchCodes()
        historyKeepsOnlyTheNewestEntriesThatFit()
        print("BatchScanCollectionTests passed")
    }

    static func collection(_ values: [String]) -> BatchScanCollection {
        var collection = BatchScanCollection()
        for value in values {
            precondition(collection.append(BatchScanEntry(value: value, codeFormat: "VNBarcodeSymbologyEAN13")) != .full)
        }
        return collection
    }

    static func joinsWithEverySeparatorWithoutTrailingSeparator() {
        let batch = collection(["4012345678901", "LOT-7", "4012345678901"])
        let expected: [BatchSeparator: String] = [
            .comma: "4012345678901,LOT-7,4012345678901",
            .semicolon: "4012345678901;LOT-7;4012345678901",
            .space: "4012345678901 LOT-7 4012345678901",
            .tab: "4012345678901\tLOT-7\t4012345678901",
            .newline: "4012345678901\nLOT-7\n4012345678901",
        ]
        precondition(Set(expected.keys) == Set(BatchSeparator.allCases), "every separator must be covered")
        for separator in BatchSeparator.allCases {
            let joined = batch.joinedText(separator: separator)
            precondition(joined == expected[separator], "\(separator): \(joined.debugDescription)")
            precondition(!joined.hasSuffix(separator.text))
        }
        // Raw values are persisted in the shared defaults and must stay stable.
        precondition(BatchSeparator.allCases.map(\.rawValue) == ["comma", "semicolon", "space", "tab", "newline"])
        precondition(ScannerScanMode.allCases.map(\.rawValue) == ["single", "batch"])
    }

    static func keepsValuesExactlyAsScanned() {
        // No trimming, transformation, validation or deduplication.
        let values = [" 0042 ", "a,b", "0042", " 0042 "]
        let batch = collection(values)
        precondition(batch.entries.map(\.value) == values)
        precondition(batch.joinedText(separator: .semicolon) == " 0042 ;a,b;0042; 0042 ")
    }

    static func singleCodeBatchIsThePlainCode() {
        let batch = collection(["4012345678901"])
        for separator in BatchSeparator.allCases {
            precondition(batch.joinedText(separator: separator) == "4012345678901")
        }
        precondition(BatchScanCollection().joinedText(separator: .comma).isEmpty)
    }

    static func stopsAtTheCap() {
        precondition(BatchScanLimit.maximumCodeCount == 50)
        var batch = BatchScanCollection()
        for index in 1...BatchScanLimit.maximumCodeCount {
            let outcome = batch.append(BatchScanEntry(value: "\(index)", codeFormat: nil))
            precondition(outcome == .added(count: index))
        }
        precondition(batch.isFull)
        precondition(batch.append(BatchScanEntry(value: "51", codeFormat: nil)) == .full)
        precondition(batch.count == BatchScanLimit.maximumCodeCount)
        precondition(batch.entries.last?.value == "50")
    }

    static func removingAnEntryKeepsOrderAndFreesASlot() {
        var batch = BatchScanCollection(maximumCount: 3)
        let first = BatchScanEntry(value: "A", codeFormat: nil)
        let second = BatchScanEntry(value: "B", codeFormat: nil)
        let third = BatchScanEntry(value: "C", codeFormat: nil)
        _ = batch.append(first)
        _ = batch.append(second)
        _ = batch.append(third)
        precondition(batch.append(BatchScanEntry(value: "D", codeFormat: nil)) == .full)
        batch.remove(id: second.id)
        precondition(batch.entries.map(\.value) == ["A", "C"])
        precondition(batch.append(BatchScanEntry(value: "D", codeFormat: nil)) == .added(count: 3))
        precondition(batch.joinedText(separator: .comma) == "A,C,D")
        batch.removeAll()
        precondition(batch.isEmpty)
    }

    static func undoPutsAnEntryBackAtItsPosition() {
        var batch = BatchScanCollection(maximumCount: 3)
        let entries = ["A", "B", "C"].map { BatchScanEntry(value: $0, codeFormat: nil) }
        for entry in entries { _ = batch.append(entry) }
        let removed = batch.remove(id: entries[1].id)
        precondition(removed?.entry == entries[1] && removed?.index == 1)
        precondition(batch.remove(id: entries[1].id) == nil, "already removed")
        precondition(!batch.contains(value: "B"))
        precondition(batch.restore(entries[1], at: 1))
        precondition(batch.entries.map(\.value) == ["A", "B", "C"])
        precondition(!batch.restore(entries[1], at: 1), "no second copy of the same entry")

        // A shorter list gets the entry at the end; a full list refuses it.
        _ = batch.remove(id: entries[0].id)
        let last = batch.remove(id: entries[2].id)!
        precondition(batch.restore(last.entry, at: last.index))
        precondition(batch.entries.map(\.value) == ["B", "C"])
        _ = batch.append(BatchScanEntry(value: "D", codeFormat: nil))
        precondition(!batch.restore(entries[0], at: 0))
        precondition(batch.entries.map(\.value) == ["B", "C", "D"])
    }

    static func marksRepeatedValues() {
        let batch = collection(["A", "B", "A", "C", "A", "B"])
        let ids = batch.entries.map(\.id)
        precondition(batch.repeatedEntryIDs == [ids[2], ids[4], ids[5]])
        precondition(batch.contains(value: "C") && !batch.contains(value: "c"))
        precondition(collection(["A", " A", "a"]).repeatedEntryIDs.isEmpty, "values compare exactly")
    }

    static func detectsCodesContainingTheSeparator() {
        let cases: [(String, Set<BatchSeparator>)] = [
            ("4012345678901", []),
            ("a,b", [.comma]),
            ("a;b", [.semicolon]),
            ("a b", [.space]),
            ("a\tb", [.space, .tab]),
            ("a\nb", [.space, .newline]),
            ("a\rb", [.space, .newline]),
            ("a\r\nb", [.space, .newline]),
            ("a\u{00A0}b", [.space]),
            (",;", [.comma, .semicolon]),
        ]
        for (value, expected) in cases {
            for separator in BatchSeparator.allCases {
                precondition(separator.occurs(in: value) == expected.contains(separator),
                             "\(separator) in \(value.debugDescription)")
            }
        }
    }

    static func capsTheSpokenValue() {
        let short = String(repeating: "7", count: 40)
        precondition(BatchScanEntry(value: short, codeFormat: nil).spokenValue == short)
        let long = String(repeating: "x", count: 200)
        let spoken = BatchScanEntry(value: long, codeFormat: nil).spokenValue
        precondition(spoken == String(repeating: "x", count: 40) + "…")
    }

    static func skipsDuplicatesOnlyWhenAsked() {
        var collection = BatchScanCollection(maximumCount: 3)
        precondition(collection.append(BatchScanEntry(value: "A", codeFormat: nil), skippingDuplicates: true) == .added(count: 1))
        // The same value again: skipped when asked, added otherwise.
        precondition(collection.append(BatchScanEntry(value: "A", codeFormat: "other"), skippingDuplicates: true) == .duplicate)
        precondition(collection.count == 1)
        precondition(collection.append(BatchScanEntry(value: "A", codeFormat: nil)) == .added(count: 2))
        precondition(collection.append(BatchScanEntry(value: "B", codeFormat: nil), skippingDuplicates: true) == .added(count: 3))
        // Full: a duplicate is still reported as a duplicate, a new value as full.
        precondition(collection.append(BatchScanEntry(value: "B", codeFormat: nil), skippingDuplicates: true) == .duplicate)
        precondition(collection.append(BatchScanEntry(value: "C", codeFormat: nil), skippingDuplicates: true) == .full)
        // A deleted value can be scanned again.
        let first = collection.entries[0].id
        _ = collection.remove(id: first)
        _ = collection.remove(id: collection.entries[0].id)
        precondition(collection.append(BatchScanEntry(value: "A", codeFormat: nil), skippingDuplicates: true) == .added(count: 2))
    }

    static func reportsTheSharedFormatOnly() {
        precondition(BatchScanCollection().commonCodeFormat == nil)
        precondition(collection(["1", "2", "3"]).commonCodeFormat == "VNBarcodeSymbologyEAN13")
        var mixed = collection(["1"])
        _ = mixed.append(BatchScanEntry(value: "2", codeFormat: "VNBarcodeSymbologyQR"))
        precondition(mixed.commonCodeFormat == nil)
        var unknown = collection(["1"])
        _ = unknown.append(BatchScanEntry(value: "2", codeFormat: nil))
        precondition(unknown.commonCodeFormat == nil)
    }

    static func historyKeepsOnlyTheNewestEntriesThatFit() {
        func item(_ value: String) -> ScanHistoryItem {
            ScanHistoryItem(value: value, codeFormat: "VNBarcodeSymbologyEAN13", source: .keyboard,
                            returnTargetRawValue: "chrome", insertionStatus: .queuedForKeyboardInsertion)
        }
        // Newest first, as History is stored.
        let items = (0..<50).map { item("401234567\(1000 + $0)") }

        // Within both limits nothing is dropped.
        let all = ScanHistoryStore.bounded(items, maximumCount: 50, maximumBytes: 1_000_000)!
        precondition(all.items == items)
        precondition((try! JSONDecoder().decode([ScanHistoryItem].self, from: all.data)) == items)

        // Over the count: the newest stay.
        let counted = ScanHistoryStore.bounded(items, maximumCount: 10, maximumBytes: 1_000_000)!
        precondition(counted.items == Array(items.prefix(10)))

        // Over the size: fewer entries, still the newest, and the result fits.
        let sized = ScanHistoryStore.bounded(items, maximumCount: 50, maximumBytes: all.data.count / 2)!
        precondition(sized.data.count <= all.data.count / 2)
        precondition(!sized.items.isEmpty && sized.items.count < 50)
        precondition(sized.items == Array(items.prefix(sized.items.count)))
        precondition((try! JSONDecoder().decode([ScanHistoryItem].self, from: sized.data)) == sized.items)

        // Not needlessly few: at least a third of what would fit exactly.
        precondition(sized.items.count >= 50 / 2 / 3)

        // One entry larger than the limit is kept rather than leaving History empty.
        let huge = [item(String(repeating: "9", count: 5_000)), item("1")]
        let single = ScanHistoryStore.bounded(huge, maximumCount: 50, maximumBytes: 1_000)!
        precondition(single.items == [huge[0]])

        // The real limits hold for a history far beyond them.
        let many = (0..<5_000).map { item("40123456\(10_000 + $0)") }
        let real = ScanHistoryStore.bounded(many)!
        precondition(real.items.count <= ScanHistoryLimit.maximumEntryCount)
        precondition(real.data.count <= ScanHistoryLimit.maximumStoredBytes)
        precondition(real.items == Array(many.prefix(real.items.count)))
    }

    static func historyEntryKeepsTheBatchCodes() {
        let batch = collection(["1", "2", "3"])
        let item = ScanHistoryItem(
            value: batch.joinedText(separator: .comma),
            codeFormat: batch.commonCodeFormat,
            source: .keyboard,
            returnTargetRawValue: nil,
            insertionStatus: .queuedForKeyboardInsertion,
            batchCodes: batch.entries.map { ScanHistoryBatchCode(value: $0.value, codeFormat: $0.codeFormat) }
        )
        precondition(item.isBatch && item.value == "1,2,3")
        precondition(item.batchCodes?.map(\.value) == ["1", "2", "3"])
        let data = try! JSONEncoder().encode([item])
        precondition(try! JSONDecoder().decode([ScanHistoryItem].self, from: data) == [item])

        // An entry saved by 1.0.4 has no batch count and is a single scan.
        let old = """
        [{"id":"6F0C7E0E-3C6B-4C1B-9E55-0B6B1D1E7A11","value":"4006381333931","codeFormat":"VNBarcodeSymbologyEAN13",
          "scannedAt":785000000,"source":"keyboard","returnTargetRawValue":"safari","insertionStatus":"queuedForKeyboardInsertion"}]
        """
        let decoded = try! JSONDecoder().decode([ScanHistoryItem].self, from: Data(old.utf8))
        precondition(decoded.count == 1 && !decoded[0].isBatch && decoded[0].value == "4006381333931")
    }
}
