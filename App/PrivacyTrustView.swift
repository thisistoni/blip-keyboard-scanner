import SwiftUI

struct PrivacyTrustView: View {
    @State private var showingMailError = false

    var body: some View {
        List {
            Section {
                TrustRow(
                    title: "Scans stay on this device",
                    detail: "Blip stores scan history locally in the app group shared by the app and keyboard extension.",
                    systemImage: "iphone"
                )

                TrustRow(
                    title: "History is optional",
                    detail: "You can turn history off, choose how long it is kept, delete one item, or clear everything.",
                    systemImage: "clock.arrow.circlepath"
                )

                TrustRow(
                    title: "No cloud sync",
                    detail: "Blip does not sync scan history to a server or cloud account.",
                    systemImage: "icloud.slash"
                )
            }

            Section {
                TrustRow(
                    title: "Why Full Access is needed",
                    detail: "iOS keeps keyboards and apps separate. Full Access lets the Blip keyboard extension and scanner app share the scan result through the app group.",
                    systemImage: "arrow.left.arrow.right"
                )
            }

            Section {
                TrustRow(
                    title: "Feedback is user-initiated",
                    detail: "Feedback emails include the diagnostic context shown in the email draft. Nothing is sent unless you send the email.",
                    systemImage: "envelope"
                )

                Link(destination: SupportEmail.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: SupportEmail.supportURL) {
                    Label("Support Page", systemImage: "questionmark.circle")
                }

                Button {
                    sendFeedback()
                } label: {
                    Label("Send Feedback", systemImage: "paperplane")
                }
            } header: {
                Text("Legal & Support")
            } footer: {
                Text("Open the public privacy policy and support page for Blip.")
            }
        }
        .navigationTitle("Privacy & Trust")
        .alert("Mail is not available", isPresented: $showingMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Install or configure Mail to send feedback from Blip.")
        }
    }

    private func sendFeedback() {
        guard let url = SupportEmail.feedbackURL() else {
            showingMailError = true
            return
        }

        SupportEmail.open(url) {
            showingMailError = true
        }
    }
}

private struct TrustRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
