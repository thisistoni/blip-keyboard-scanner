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

        var disabledProfile = oldProfile
        disabledProfile["autoInsertScans"] = false
        let disabledData = try! JSONSerialization.data(withJSONObject: disabledProfile)
        let decodedDisabledProfile = try! BlipCompanyProfile.decode(from: disabledData)
        precondition(!decodedOldProfile.changes(comparedTo: decodedDisabledProfile).contains {
            $0.title == "Insert Scans Automatically"
        })

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
