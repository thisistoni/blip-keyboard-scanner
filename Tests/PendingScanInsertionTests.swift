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
}
