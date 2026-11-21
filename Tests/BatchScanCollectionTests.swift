import Foundation

// Build and run with:
// xcrun swiftc Shared/KeyboardSettings.swift Shared/ScanHistory.swift App/BatchScanCollection.swift Tests/BatchScanCollectionTests.swift -o <tmp>/blip-batch-tests

@main
enum BatchScanCollectionTests {
    static func main() {
        joinsWithEverySeparatorWithoutTrailingSeparator()
        keepsValuesExactlyAsScanned()
        singleCodeBatchIsThePlainCode()
        stopsAtTheCap()
        removingAnEntryKeepsOrderAndFreesASlot()
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
}
