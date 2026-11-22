import SwiftUI

/// The three things a new user has to know, in this order: how a scan gets
/// into a text field, that the keyboard must be turned on once, and how Blip
/// gets back to the app they scan in. Everything else lives in Settings.
enum OnboardingPage: Int, CaseIterable {
    case howItWorks
    case keyboard
    case returnTarget
}

struct OnboardingFlowView: View {
    let status: SetupVerificationStatus
    /// Opened again from Settings: no step is required and it can be closed.
    let isReplay: Bool
    let onFinish: () -> Void

    @AppStorage(SharedKeyboardState.Keys.returnTarget, store: SharedKeyboardState.appStorageDefaults)
    private var returnTargetRawValue = ReturnTarget.safari.rawValue

    @State private var page: OnboardingPage

    init(
        status: SetupVerificationStatus,
        startPage: OnboardingPage = .howItWorks,
        isReplay: Bool = false,
        onFinish: @escaping () -> Void
    ) {
        self.status = status
        self.isReplay = isReplay
        self.onFinish = onFinish
        _page = State(initialValue: startPage)
    }

    private var returnTarget: ReturnTarget {
        ReturnTarget(rawValue: returnTargetRawValue) ?? .safari
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch page {
                    case .howItWorks: howItWorksPage
                    case .keyboard: keyboardPage
                    case .returnTarget: returnTargetPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if page != .howItWorks {
                        Button("Back") { go(to: page.rawValue - 1) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isReplay {
                        Button("Close", action: onFinish)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    // MARK: Pages

    private var howItWorksPage: some View {
        Group {
            OnboardingHeader(
                systemImage: "barcode.viewfinder",
                title: "Scan into any text field",
                message: "Blip is a keyboard with a Scan button. It types barcodes and QR codes for you, in any app."
            )

            OnboardingCard {
                OnboardingStep(
                    number: 1,
                    title: "Switch to the Blip keyboard",
                    message: "Tap a text field in any app, then switch to Blip with the globe key at the bottom left."
                )
                Divider()
                OnboardingStep(
                    number: 2,
                    title: "Tap Scan",
                    message: "The Blip app opens its camera and reads the code."
                )
                Divider()
                OnboardingStep(
                    number: 3,
                    title: "The code is typed for you",
                    message: "You return to your app and Blip puts the code into the text field."
                )
            }
        }
    }

    private var keyboardPage: some View {
        Group {
            OnboardingHeader(
                systemImage: "keyboard",
                title: "Turn on the Blip keyboard",
                message: "You do this once, in the iOS Settings."
            )

            OnboardingCard {
                OnboardingStep(
                    number: 1,
                    title: "Open Settings",
                    message: "Use the button below. Settings opens on the Blip page."
                )
                Divider()
                OnboardingStep(
                    number: 2,
                    title: "Tap Keyboards and turn on Blip",
                    message: nil
                )
                Divider()
                OnboardingStep(
                    number: 3,
                    title: "Turn on Allow Full Access",
                    message: "Without it the scanner cannot hand the code to the keyboard. Your scans stay on this device."
                )
            }

            if status.isKeyboardEnabled {
                Label("The Blip keyboard is on.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("Come back to Blip when you are done. If Blip does not notice the keyboard, close Blip completely and open it again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var returnTargetPage: some View {
        Group {
            OnboardingHeader(
                systemImage: "arrow.uturn.backward.circle",
                title: "Getting back to your app",
                message: "After a scan, Blip returns to the app you were typing in. Where do you scan most?"
            )

            OnboardingCard {
                ForEach(Array(returnTargetChoices.enumerated()), id: \.element) { index, target in
                    if index > 0 {
                        Divider()
                    }
                    OnboardingChoiceRow(
                        title: Self.choiceTitle(for: target),
                        detail: Self.choiceDetail(for: target),
                        isSelected: returnTarget == target
                    ) {
                        returnTargetRawValue = target.rawValue
                    }
                }
            }

            Text(returnTarget.usesSystemPreviousAppReturn
                 ? "iOS does not let Blip return to Safari or to other apps by itself. After a scan, tap the small back arrow at the top left of the screen, then tap Insert Last Scan on the Blip keyboard."
                 : "Blip returns by itself after a scan and puts the code into the text field.")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("You can change this at any time in Settings under Return & Insertion.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// The custom target needs a URL and is set up in Settings; it is listed
    /// here only when it is already in use.
    private var returnTargetChoices: [ReturnTarget] {
        var choices: [ReturnTarget] = [.safari, .chrome, .edge, .firefox, .brave]
        if returnTarget == .custom {
            choices.append(.custom)
        }
        return choices
    }

    private static func choiceTitle(for target: ReturnTarget) -> String {
        target == .safari
            ? NSLocalizedString("Safari or another app", comment: "Onboarding return target choice for manual return")
            : target.title
    }

    private static func choiceDetail(for target: ReturnTarget) -> String {
        switch target {
        case .safari:
            NSLocalizedString("Manual", comment: "Onboarding return target detail: the user returns by hand")
        case .custom:
            NSLocalizedString("Custom Return URL", comment: "Onboarding return target detail, custom")
        default:
            NSLocalizedString("Automatic", comment: "Onboarding return target detail: Blip returns by itself")
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(OnboardingPage.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: step == page ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(
                    format: NSLocalizedString("Step %d of %d", comment: "Onboarding progress; current step and number of steps"),
                    page.rawValue + 1,
                    OnboardingPage.allCases.count
                )
            )

            switch page {
            case .howItWorks:
                primaryButton("Continue") { go(to: page.rawValue + 1) }
            case .keyboard:
                if status.isKeyboardEnabled {
                    primaryButton("Continue") { go(to: page.rawValue + 1) }
                } else {
                    primaryButton("Open Settings") { SystemSettingsOpener.openKeyboardSettings() }
                    if isReplay {
                        Button("Continue") { go(to: page.rawValue + 1) }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            case .returnTarget:
                primaryButton("Done", action: onFinish)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func go(to rawValue: Int) {
        guard let next = OnboardingPage(rawValue: rawValue) else { return }
        page = next
    }
}

private struct OnboardingHeader: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct OnboardingStep: View {
    let number: Int
    let title: LocalizedStringKey
    let message: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(number)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)

                Text(verbatim: title)
                    .font(.body)
                    .foregroundStyle(Color.primary)

                Spacer(minLength: 8)

                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
