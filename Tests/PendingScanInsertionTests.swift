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

        print("Pending scan token checks passed")
    }
}
