import Foundation

@main
enum PendingScanInsertionTests {
    static func main() {
        let code = "012345678905"

        // A newly returned keyboard may see the queued scan before any text changes.
        let ready = PendingScanInsertion(
            identifier: "request-2",
            activeIdentifier: "request-2",
            consumedIdentifier: "request-1",
            code: code
        )
        precondition(ready?.code == code)

        // A second lifecycle event must not reinsert an already attempted scan.
        precondition(PendingScanInsertion(
            identifier: "request-2",
            activeIdentifier: "",
            consumedIdentifier: "request-2",
            code: code
        ) == nil)

        // An older scan must not enter a field after a newer scan request starts.
        precondition(PendingScanInsertion(
            identifier: "request-1",
            activeIdentifier: "request-2",
            consumedIdentifier: "",
            code: code
        ) == nil)

        precondition(PendingScanInsertion(
            identifier: "",
            activeIdentifier: "",
            consumedIdentifier: "",
            code: code
        ) == nil)

        precondition(PendingScanInsertion(
            identifier: "request-3",
            activeIdentifier: "request-3",
            consumedIdentifier: "",
            code: " \n "
        ) == nil)

        // Safari keeps the scan for an explicit Insert Last Scan tap.
        precondition(PendingScanInsertion(
            identifier: "safari-request",
            activeIdentifier: "safari-request",
            consumedIdentifier: "",
            code: code,
            automaticInsertionEnabled: false
        ) == nil)

        precondition(ReturnTarget.chrome.shouldAutomaticallyInsertScan(userEnabled: true))
        precondition(!ReturnTarget.chrome.shouldAutomaticallyInsertScan(userEnabled: false))
        precondition(!ReturnTarget.safari.shouldAutomaticallyInsertScan(userEnabled: true))
        precondition(ReturnTarget.custom.shouldAutomaticallyInsertScan(userEnabled: true))

        // Turning the setting off before a queued automatic write fires must defer it.
        precondition(PendingScanInsertion(
            identifier: "queued-before-toggle",
            activeIdentifier: "queued-before-toggle",
            consumedIdentifier: "",
            code: code,
            automaticInsertionEnabled: false
        ) == nil)

        // Existing company profiles without the new setting remain importable.
        let profileData = try! BlipCompanyProfile.current.exportData()
        var oldProfile = try! JSONSerialization.jsonObject(with: profileData) as! [String: Any]
        oldProfile.removeValue(forKey: "autoInsertScans")
        let oldProfileData = try! JSONSerialization.data(withJSONObject: oldProfile)
        let decodedOldProfile = try! BlipCompanyProfile.decode(from: oldProfileData)
        precondition(decodedOldProfile.autoInsertScans == nil)

        // Earlier profiles do not reset the newer keyboard appearance/feedback choices.
        var legacyProfileJSON = oldProfile
        for key in ["keyboardAppearance", "keyboardClickSound", "keyboardHaptics"] {
            legacyProfileJSON.removeValue(forKey: key)
        }
        let legacyProfile = try! BlipCompanyProfile.decode(from: JSONSerialization.data(withJSONObject: legacyProfileJSON))
        precondition(legacyProfile.keyboardAppearance == nil)
        precondition(legacyProfile.keyboardClickSound == nil && legacyProfile.keyboardHaptics == nil)
        precondition(!legacyProfile.changes().contains { ["Keyboard Appearance", "Key Clicks", "Key Haptics"].contains($0.title) })

        var inactiveURLProfileJSON = legacyProfileJSON
        inactiveURLProfileJSON["returnTarget"] = ReturnTarget.safari.rawValue
        inactiveURLProfileJSON["customReturnURL"] = "telegram://"
        let inactiveURLProfile = try! BlipCompanyProfile.decode(from: JSONSerialization.data(withJSONObject: inactiveURLProfileJSON))
        precondition(!inactiveURLProfile.includedSettings.contains { $0.title == "Custom Return URL" })
        precondition(!inactiveURLProfile.changes().contains { $0.title == "Custom Return URL" })
        precondition(inactiveURLProfile.includedSettings.first?.value == ReturnTarget.safari.title)
        if SharedKeyboardState.returnTarget != .custom {
            precondition(BlipCompanyProfile.current.customReturnURL.isEmpty)
        }

        var customProfileJSON = inactiveURLProfileJSON
        customProfileJSON["returnTarget"] = ReturnTarget.custom.rawValue
        customProfileJSON["keyboardAppearance"] = KeyboardAppearance.blipBlue.rawValue
        customProfileJSON["keyboardClickSound"] = false
        customProfileJSON["keyboardHaptics"] = false
        let customProfile = try! BlipCompanyProfile.decode(from: JSONSerialization.data(withJSONObject: customProfileJSON))
        precondition(customProfile.includedSettings.contains { $0.title == "Custom Return URL" && $0.value == "telegram://" })
        let customQR = String(decoding: try! BlipCompanyProfileQR.encode(customProfile), as: UTF8.self)
        let customRoundTrip = try! BlipCompanyProfileQR.decodeIfRecognized(customQR)!
        precondition(customRoundTrip.keyboardAppearance == KeyboardAppearance.blipBlue.rawValue)
        precondition(customRoundTrip.keyboardClickSound == false && customRoundTrip.keyboardHaptics == false)
        customProfileJSON["keyboardAppearance"] = "not-a-theme"
        do {
            _ = try BlipCompanyProfile.decode(from: JSONSerialization.data(withJSONObject: customProfileJSON))
            preconditionFailure("Invalid keyboard appearance accepted")
        } catch BlipCompanyProfileError.invalidValue {} catch { preconditionFailure("Wrong appearance error") }

        var disabledProfile = oldProfile
        disabledProfile["autoInsertScans"] = false
        let disabledData = try! JSONSerialization.data(withJSONObject: disabledProfile)
        let decodedDisabledProfile = try! BlipCompanyProfile.decode(from: disabledData)
        precondition(!decodedOldProfile.changes(comparedTo: decodedDisabledProfile).contains {
            $0.title == "Insert Scans Automatically"
        })

        // QR transport uses the existing validated schema, leaving ordinary barcode data untouched.
        let qrProfile = BlipCompanyProfile.current
        let qrData = try! BlipCompanyProfileQR.encode(qrProfile)
        let qrValue = String(decoding: qrData, as: UTF8.self)
        let decodedQR = try! BlipCompanyProfileQR.decodeIfRecognized(qrValue)!
        precondition(try! decodedQR.exportData() == qrProfile.exportData())
        precondition(try! BlipCompanyProfileQR.decodeIfRecognized("1234567890123") == nil)
        precondition(try! BlipCompanyProfileQR.decodeIfRecognized("https://example.com") == nil)
        precondition(!BlipCompanyProfileQR.acceptsScannedQR("https://example.com", formatProfile: .commonBarcodes))
        precondition(BlipCompanyProfileQR.acceptsScannedQR(qrValue, formatProfile: .commonBarcodes))
        precondition(BlipCompanyProfileQR.acceptsScannedQR("https://example.com", formatProfile: .barcodesAndQR))
        precondition(BlipCompanyProfileQR.acceptsScannedQR("https://example.com", formatProfile: .allSupported))
        let legacyQR = BlipCompanyProfileQR.prefix + String(decoding: oldProfileData, as: UTF8.self)
        precondition(try! BlipCompanyProfileQR.decodeIfRecognized(legacyQR)?.autoInsertScans == nil)
        do {
            _ = try BlipCompanyProfileQR.decodeIfRecognized(BlipCompanyProfileQR.marker + "2:{}")
            preconditionFailure("Unsupported QR transport version accepted")
        } catch BlipCompanyProfileQRError.unsupportedVersion {} catch { preconditionFailure("Wrong QR version error") }
        var invalidQR = oldProfile
        invalidQR["keyboardLanguage"] = "invalid"
        do {
            let invalidData = try JSONSerialization.data(withJSONObject: invalidQR)
            _ = try BlipCompanyProfileQR.decodeIfRecognized(BlipCompanyProfileQR.prefix + String(decoding: invalidData, as: UTF8.self))
            preconditionFailure("Invalid QR settings accepted")
        } catch BlipCompanyProfileError.invalidValue {} catch { preconditionFailure("Wrong QR validation error") }
        do {
            _ = try BlipCompanyProfileQR.decodeIfRecognized(BlipCompanyProfileQR.prefix + String(repeating: "x", count: BlipCompanyProfileQR.maximumBytes))
            preconditionFailure("Oversized QR accepted")
        } catch BlipCompanyProfileQRError.tooLarge {} catch { preconditionFailure("Wrong QR size error") }
        var largeProfileJSON = oldProfile
        largeProfileJSON["customReturnURL"] = "company://" + String(repeating: "x", count: BlipCompanyProfileQR.maximumBytes)
        let largeProfile = try! BlipCompanyProfile.decode(from: JSONSerialization.data(withJSONObject: largeProfileJSON))
        do {
            _ = try BlipCompanyProfileQR.encode(largeProfile)
            preconditionFailure("Oversized profile exported as QR")
        } catch BlipCompanyProfileQRError.tooLarge {} catch { preconditionFailure("Wrong QR export size error") }

        batchSettingsInCompanyProfiles(baseJSON: oldProfile)

        // An explicit field token is required; a stale app-group session cannot tag another host.
        var keyboardTest = KeyboardTestSession(id: "test-field")
        precondition(!keyboardTest.launch(requestID: "r1", contentType: nil))
        precondition(!keyboardTest.launch(requestID: "r1", contentType: KeyboardTestSession(id: "other-field").contentType))
        precondition(keyboardTest.isOwned(ownerID: "test-field", leaseUntil: 101, now: 100))
        precondition(!keyboardTest.isOwned(ownerID: "test-field", leaseUntil: 100, now: 100))
        precondition(!keyboardTest.isOwned(ownerID: "", leaseUntil: 101, now: 100))
        precondition(keyboardTest.launch(requestID: "r1", contentType: keyboardTest.contentType))
        let testRequest = KeyboardScanRequest(id: "r1", source: "keyboard", testSessionID: "test-field")
        precondition(KeyboardScanRequest(url: testRequest.url) == testRequest)
        precondition(KeyboardScanRequest(url: KeyboardScanRequest(id: "external", source: "keyboard").url)?.testSessionID == nil)
        precondition(!keyboardTest.accept(KeyboardScanRequest(id: "wrong", source: "keyboard", testSessionID: "test-field")))
        precondition(!keyboardTest.accept(KeyboardScanRequest(id: "r1", source: "app", testSessionID: "test-field")))
        precondition(keyboardTest.accept(testRequest))
        // Repeated native focus preflights during camera handoff must not erase the request.
        let scanningSession = keyboardTest
        precondition(!keyboardTest.resume())
        precondition(!keyboardTest.resume())
        precondition(keyboardTest == scanningSession)
        precondition(!keyboardTest.accept(testRequest))
        precondition(!keyboardTest.finish(requestID: "stale", code: code))
        precondition(keyboardTest.finish(requestID: "r1", code: code))
        precondition(keyboardTest.insertion(contentType: keyboardTest.contentType) == nil)
        precondition(keyboardTest.resume())
        // Only the cooperating field can receive the test result.
        precondition(keyboardTest.insertion(contentType: nil) == nil)
        precondition(keyboardTest.insertion(contentType: keyboardTest.contentType)?.code == code)
        keyboardTest.consume()
        precondition(keyboardTest.insertion(contentType: keyboardTest.contentType) == nil)
        precondition(keyboardTest.launch(requestID: "r2", contentType: keyboardTest.contentType))
        precondition(!keyboardTest.accept(testRequest)) // Old deep-link cannot hijack the next scan.
        precondition(keyboardTest.accept(KeyboardScanRequest(id: "r2", source: "keyboard", testSessionID: "test-field")))
        precondition(keyboardTest.finish(requestID: "r2", code: nil))
        precondition(keyboardTest.resume())
        precondition(keyboardTest.phase == .editing && keyboardTest.code == nil && keyboardTest.requestIdentifier == nil)

        print("Pending scan and scoped keyboard test checks passed")
    }

    /// Scan Mode and Batch Separator in company profiles (ANT-151).
    static func batchSettingsInCompanyProfiles(baseJSON: [String: Any]) {
        func decode(_ json: [String: Any]) throws -> BlipCompanyProfile {
            try BlipCompanyProfile.decode(from: JSONSerialization.data(withJSONObject: json))
        }

        // A profile as exported by 1.0.4 (no batch keys) still imports and leaves
        // the device's scan mode and separator unchanged.
        var released = baseJSON
        released.removeValue(forKey: "scannerScanMode")
        released.removeValue(forKey: "batchSeparator")
        released.removeValue(forKey: "batchSkipDuplicates")
        let releasedProfile = try! decode(released)
        precondition(releasedProfile.scannerScanMode == nil && releasedProfile.batchSeparator == nil)
        precondition(releasedProfile.batchSkipDuplicates == nil)
        precondition(!releasedProfile.changes().contains { $0.title == "Skip Duplicate Codes" })
        precondition(!releasedProfile.includedSettings.contains { $0.title == "Skip Duplicate Codes" })
        precondition(!releasedProfile.changes().contains { ["Scan Mode", "Batch Separator"].contains($0.title) })
        precondition(!releasedProfile.includedSettings.contains { ["Scan Mode", "Batch Separator"].contains($0.title) })
        let releasedQR = BlipCompanyProfileQR.prefix + String(decoding: try! JSONSerialization.data(withJSONObject: released), as: UTF8.self)
        precondition(try! BlipCompanyProfileQR.decodeIfRecognized(releasedQR)?.scannerScanMode == nil)

        // This build exports both values.
        let current = BlipCompanyProfile.current
        precondition(current.scannerScanMode == SharedKeyboardState.scannerScanMode.rawValue)
        precondition(current.batchSeparator == SharedKeyboardState.batchSeparator.rawValue)
        precondition(current.batchSkipDuplicates == SharedKeyboardState.batchSkipDuplicates)
        precondition(BlipCompanyProfile.currentVersion == 1 && BlipCompanyProfileQR.prefix == "BLIP_PROFILE:1:")

        // Round trip through file and QR, shown in the summary and the preview.
        var batchJSON = released
        batchJSON["scannerScanMode"] = ScannerScanMode.batch.rawValue
        batchJSON["batchSeparator"] = BatchSeparator.newline.rawValue
        batchJSON["batchSkipDuplicates"] = true
        let batchProfile = try! decode(batchJSON)
        let fileRoundTrip = try! BlipCompanyProfile.decode(from: batchProfile.exportData())
        precondition(fileRoundTrip == batchProfile)
        let qrRoundTrip = try! BlipCompanyProfileQR.decodeIfRecognized(
            String(decoding: try! BlipCompanyProfileQR.encode(batchProfile), as: UTF8.self))!
        precondition(qrRoundTrip.scannerScanMode == "batch" && qrRoundTrip.batchSeparator == "newline")
        precondition(qrRoundTrip.batchSkipDuplicates == true)
        precondition(batchProfile.includedSettings.contains { $0.title == "Skip Duplicate Codes" })
        // Compared with a device that never stored it, "off" is shown as current.
        precondition(batchProfile.changes(comparedTo: releasedProfile).contains { $0.title == "Skip Duplicate Codes" })
        precondition(batchProfile.includedSettings.contains { $0.title == "Scan Mode" && $0.value == ScannerScanMode.batch.title })
        precondition(batchProfile.includedSettings.contains { $0.title == "Batch Separator" && $0.value == BatchSeparator.newline.title })
        var singleCommaJSON = batchJSON
        singleCommaJSON["scannerScanMode"] = ScannerScanMode.single.rawValue
        singleCommaJSON["batchSeparator"] = BatchSeparator.comma.rawValue
        singleCommaJSON["batchSkipDuplicates"] = false
        let singleComma = try! decode(singleCommaJSON)
        let previewChanges = batchProfile.changes(comparedTo: singleComma)
        precondition(previewChanges.contains {
            $0.title == "Scan Mode" && $0.currentValue == ScannerScanMode.single.title && $0.incomingValue == ScannerScanMode.batch.title
        })
        precondition(previewChanges.contains { $0.title == "Skip Duplicate Codes" })
        precondition(previewChanges.contains {
            $0.title == "Batch Separator" && $0.currentValue == BatchSeparator.comma.title && $0.incomingValue == BatchSeparator.newline.title
        })
        // Compared with a device that never stored them, the defaults are shown as current.
        precondition(batchProfile.changes(comparedTo: releasedProfile).contains {
            $0.title == "Scan Mode" && $0.currentValue == ScannerScanMode.single.title
        })

        // Invalid values are rejected before anything is applied.
        for (key, value) in [("scannerScanMode", "triple"), ("batchSeparator", "pipe"), ("batchSeparator", "")] {
            var invalid = batchJSON
            invalid[key] = value
            do {
                _ = try decode(invalid)
                preconditionFailure("Invalid \(key) accepted")
            } catch BlipCompanyProfileError.invalidValue(let field) {
                precondition(field == key)
            } catch {
                preconditionFailure("Wrong \(key) error")
            }
        }

        // QR size budget: a full profile with the longest values fits, and the
        // two new keys count towards the 1,200-byte limit.
        var longest = batchJSON
        longest["batchSeparator"] = BatchSeparator.semicolon.rawValue
        longest["keyboardAppearance"] = KeyboardAppearance.blipBlue.rawValue
        longest["keyboardClickSound"] = true
        longest["keyboardHaptics"] = true
        longest["autoInsertScans"] = true
        precondition((try? BlipCompanyProfileQR.encode(decode(longest))) != nil, "full profile must fit in a QR code")

        var customWithout = released
        customWithout["returnTarget"] = ReturnTarget.custom.rawValue
        customWithout["customReturnURL"] = "company://"
        let baseSize = try! BlipCompanyProfileQR.encode(decode(customWithout)).count
        customWithout["customReturnURL"] = "company://" + String(repeating: "x", count: BlipCompanyProfileQR.maximumBytes - baseSize - 5)
        precondition((try? BlipCompanyProfileQR.encode(decode(customWithout))) != nil)
        var customWith = customWithout
        customWith["scannerScanMode"] = ScannerScanMode.single.rawValue
        customWith["batchSeparator"] = BatchSeparator.comma.rawValue
        do {
            _ = try BlipCompanyProfileQR.encode(decode(customWith))
            preconditionFailure("Batch keys must count towards the QR size limit")
        } catch BlipCompanyProfileQRError.tooLarge {} catch { preconditionFailure("Wrong QR size error") }

        // Why no version bump: the decoder is the synthesized Decodable, which
        // ignores keys it does not know, exactly as in 1.0.4. A type with only
        // 1.0.4's keys still decodes a profile exported by this build.
        struct ReleasedProfileKeys: Decodable {
            let profileVersion: Int
            let scannerScanArea: String
            let keyboardHaptics: Bool?
        }
        let olderReader = JSONDecoder()
        olderReader.dateDecodingStrategy = .iso8601
        precondition((try? olderReader.decode(ReleasedProfileKeys.self, from: batchProfile.exportData()))?.profileVersion == 1)

        introductionOnlyForNewInstalls()
    }

    static func introductionOnlyForNewInstalls() {
        // A new install without the keyboard gets the introduction from the start.
        let new = OnboardingStage.atLaunch(stored: nil, keyboardIsSetUp: false)
        precondition(new.stage == .inProgress && !new.resumes)

        // An install that already has the keyboard (updated from an earlier
        // version) never sees it.
        let existing = OnboardingStage.atLaunch(stored: nil, keyboardIsSetUp: true)
        precondition(existing.stage == .completed && !existing.resumes)

        // iOS ended the app while the keyboard was turned on in Settings: the
        // next launch continues, although the keyboard is set up by now.
        let interrupted = OnboardingStage.atLaunch(stored: .inProgress, keyboardIsSetUp: true)
        precondition(interrupted.stage == .inProgress && interrupted.resumes)

        // Finished once, never again, even if the keyboard is turned off later.
        let done = OnboardingStage.atLaunch(stored: .completed, keyboardIsSetUp: false)
        precondition(done.stage == .completed && !done.resumes)
    }
}
