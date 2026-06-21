import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .scan
    @State private var scannerLaunchRequest: KeyboardScanRequest?
    @State private var setupStatus = SetupVerificationStatus.current

    private let setupPoller = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if setupStatus.isKeyboardEnabled || scannerLaunchRequest != nil {
                appTabs
            } else {
                SetupFlowView(status: setupStatus, onCheckAgain: refreshSetupStatus)
            }
        }
        .onOpenURL(perform: handleURL)
        .onAppear(perform: refreshSetupStatus)
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            refreshSetupStatus()
        }
        .onReceive(setupPoller) { _ in
            refreshSetupStatus()
        }
    }

    private var appTabs: some View {
        TabView(selection: $selectedTab) {
            ScannerScreen(externalLaunchRequest: scannerLaunchRequest)
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(AppTab.scan)

            KeyboardLayoutSettingsView(setupStatus: setupStatus)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }

    private func handleURL(_ url: URL) {
        guard let request = KeyboardScanRequest(url: url) else { return }

        SharedKeyboardState.activeScanRequestIdentifier = request.id
        scannerLaunchRequest = request
        selectedTab = .scan
        refreshSetupStatus()
    }

    private func refreshSetupStatus() {
        setupStatus = .current
    }
}

private enum AppTab: Hashable {
    case scan
    case settings
}

struct SetupVerificationStatus: Equatable {
    let snapshot: KeyboardSetupSnapshot

    var isKeyboardEnabled: Bool {
        snapshot.isEnabled
    }

    static var current: SetupVerificationStatus {
        SetupVerificationStatus(snapshot: SharedKeyboardState.keyboardSetupSnapshot)
    }
}

private struct SetupFlowView: View {
    let status: SetupVerificationStatus
    let onCheckAgain: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    steps
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 150)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Barcode Wedge")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        SystemSettingsOpener.openKeyboardSettings()
                    } label: {
                        Label("Open Keyboard Settings", systemImage: "gearshape")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onCheckAgain) {
                        Label("Check Again", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Text("Settings opens at Apps > BarcodeKeyboard. Tap Keyboards, enable Barcode Wedge, then enable Allow Full Access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.regularMaterial)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.blue)

            Text("Setup Barcode Wedge")
                .font(.largeTitle.weight(.bold))

            Text("Enable the keyboard once in Settings. Full Access is needed so scan results can move from the scanner app back into the keyboard.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 0) {
            SetupStatusRow(
                title: "Open Keyboards",
                detail: "Go to this app's Settings page and tap Keyboards.",
                systemImage: "keyboard",
                isComplete: status.isKeyboardEnabled
            )

            Divider().padding(.leading, 44)

            SetupStatusRow(
                title: "Enable Barcode Wedge",
                detail: "Turn on the Barcode Wedge keyboard.",
                systemImage: "checkmark.circle",
                isComplete: status.isKeyboardEnabled
            )

            Divider().padding(.leading, 44)

            SetupStatusRow(
                title: "Allow Full Access",
                detail: "Open the Barcode Wedge keyboard row and enable Allow Full Access.",
                systemImage: "arrow.left.arrow.right",
                isComplete: false
            )
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupNoticeView(
                title: "Still seeing setup?",
                message: "After enabling Barcode Wedge and Allow Full Access, tap Check Again. If iOS still does not report the keyboard, fully close and reopen Barcode Wedge so it can refresh the keyboard state.",
                systemImage: "arrow.clockwise.circle"
            )

            Text("The app checks the keyboard state every time it opens.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let matchedKeyboard = status.snapshot.matchedKeyboard {
                Label(
                    String(format: NSLocalizedString("Detected %@", comment: "Detected keyboard settings entry"), matchedKeyboard),
                    systemImage: "checkmark.circle.fill"
                )
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct SetupNoticeView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SetupStatusRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
                .font(.title3)
                .foregroundStyle(isComplete ? .green : .secondary)
                .frame(width: 30)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
