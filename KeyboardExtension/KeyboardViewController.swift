import UIKit
import SwiftUI
import KeyboardKit
import os

final class KeyboardViewController: KeyboardInputViewController {
    private let presentation = BlipKeyboardPresentation()
    private var pendingInsertionWorkItem: DispatchWorkItem?
    private var isInsertingScan = false
    private let insertionLogger = Logger(subsystem: "com.antoniobeslic.Blip", category: "ScanInsertion")

    override func loadView() {
        // Let iOS draw the keyboard backdrop and its rounded system contour.
        inputView = BlipInputView(frame: .zero, inputViewStyle: .keyboard)
        view = inputView
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup(for: KeyboardApp(
            name: "Blip",
            appGroupId: SharedKeyboardState.appGroupIdentifier,
            locales: [Locale(identifier: SharedKeyboardState.keyboardLanguage == .german ? "de" : "en")],
            keyboardSettingsKeyPrefix: "blip.keyboardkit"
        ))
        services.feedbackService = BlipFeedbackService(controller: self)
        services.calloutService = .standard(
            keyboardContext: state.keyboardContext, feedbackService: services.feedbackService)
        services.actionHandler = BlipActionHandler(controller: self)
        state.feedbackContext.hapticConfiguration = .init(
            press: .selectionChanged, release: .none, doubleTap: .none,
            longPress: .lightImpact, repeat: .selectionChanged)
        state.keyboardContext.isLiquidGlassEnabled = false
        state.keyboardContext.settings.spaceLongPressBehavior = .moveInputCursor
        NotificationCenter.default.addObserver(self, selector: #selector(extensionHostDidBecomeActive),
            name: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil)
    }

    deinit {
        pendingInsertionWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { [unowned self] controller in
            BlipPremiumKeyboard(state: controller.state, services: controller.services,
                presentation: self.presentation,
                insertScan: { [weak self] in self?.insertLastScanTapped() })
        }
    }

    override func viewWillSetupInitialKeyboardType() {
        // Blip's enabled profiles, including large numbers and scan-only, own the layout.
        state.keyboardContext.keyboardType = .alphabetic
    }

    override func viewWillSyncWithContext() {
        super.viewWillSyncWithContext()
        state.keyboardContext.keyboardType = .alphabetic
        state.keyboardContext.locale = Locale(identifier: SharedKeyboardState.keyboardLanguage == .german ? "de" : "en")
        refreshRecoveryButtonIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        presentation.layout = SharedKeyboardState.defaultKeyboardLayout
        super.viewWillAppear(animated)
        SharedKeyboardState.recordKeyboardRuntime(hasFullAccess: hasFullAccess)
        refreshRecoveryButtonIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        schedulePendingScanInsertion()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateKeyboardBackground()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pendingInsertionWorkItem?.cancel()
        pendingInsertionWorkItem = nil
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        schedulePendingScanInsertion()
    }

    fileprivate func cycleLayout() {
        if let next = SharedKeyboardState.nextKeyboardLayout(after: presentation.layout) {
            presentation.layout = next
            state.keyboardContext.keyboardCase = .lowercased
        }
    }

    private func refreshRecoveryButtonIfNeeded() {
        presentation.appearance = SharedKeyboardState.keyboardAppearance
        updateKeyboardBackground()
        presentation.canInsertScan = hasFullAccess && SharedKeyboardState.canAccessAppGroup &&
            !SharedKeyboardState.pendingScannedCode.isEmpty
    }

    private func updateKeyboardBackground() {
        guard isViewLoaded else { return }
        // Paint the entire allocated input view, including space outside the SwiftUI content.
        // Its transparent hosting view reveals this fill; iOS still owns the outer contour.
        let background: UIColor = presentation.appearance == .blipBlue
            ? UIColor(BlipKeyboardPalette(isDark: state.keyboardContext.colorScheme == .dark,
                increasedContrast: false).canvas)
            : .clear
        if view.backgroundColor != background {
            view.backgroundColor = background
        }
        for child in children where child.isViewLoaded && child.view.superview === view {
            // The hosting view is pinned to every input-view edge, beyond SwiftUI safe areas.
            if child.view.backgroundColor != background {
                child.view.backgroundColor = background
            }
        }
    }
    private func schedulePendingScanInsertion() {
        guard !isInsertingScan, hasFullAccess, SharedKeyboardState.canAccessAppGroup,
              SharedKeyboardState.pendingInsertion != nil else { return }

        pendingInsertionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingInsertionWorkItem = nil
            self?.insertPendingScanIfReady()
        }
        pendingInsertionWorkItem = workItem
        insertionLogger.debug("Automatic scan insertion scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    private func insertPendingScanIfReady() {
        guard !isInsertingScan, view.window != nil, hasFullAccess,
              let pending = SharedKeyboardState.pendingInsertion else {
            insertionLogger.debug("Automatic scan insertion deferred; keyboard or scan is not ready")
            return
        }

        isInsertingScan = true
        defer { isInsertingScan = false }

        textDocumentProxy.insertText(pending.code)
        applyInsertSuffix(SharedKeyboardState.insertSuffix)
        SharedKeyboardState.markPendingInsertionAttempted(identifier: pending.identifier)
        insertionLogger.info("Automatic scan proxy write issued")
    }

    fileprivate func insertLastScanTapped() {
        guard hasFullAccess, SharedKeyboardState.canAccessAppGroup,
              !SharedKeyboardState.pendingScannedCode.isEmpty else { return }

        pendingInsertionWorkItem?.cancel()
        pendingInsertionWorkItem = nil
        isInsertingScan = true
        defer { isInsertingScan = false }

        textDocumentProxy.insertText(SharedKeyboardState.pendingScannedCode)
        applyInsertSuffix(SharedKeyboardState.insertSuffix)
        SharedKeyboardState.markPendingInsertionAttempted(identifier: SharedKeyboardState.pendingScanIdentifier)
        insertionLogger.info("Manual last-scan proxy write issued")
    }

    @objc private func extensionHostDidBecomeActive() {
        insertionLogger.debug("Keyboard host became active")
        refreshRecoveryButtonIfNeeded()
        schedulePendingScanInsertion()
    }

    private func applyInsertSuffix(_ suffix: InsertSuffix) {
        switch suffix {
        case .none:
            break
        case .space:
            textDocumentProxy.insertText(" ")
        case .tab:
            textDocumentProxy.insertText("\t")
        case .newline:
            let activeWindow = view.window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self, let activeWindow,
                      self.view.window === activeWindow else { return }
                self.textDocumentProxy.insertText("\n")
            }
        }
    }
}

private final class BlipKeyboardPresentation: ObservableObject {
    @Published var layout = SharedKeyboardState.defaultKeyboardLayout
    @Published var canInsertScan = false
    @Published var appearance = SharedKeyboardState.keyboardAppearance
}

private final class BlipInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { SharedKeyboardState.keyboardClickSound }
}

private final class BlipFeedbackService: Feedback.StandardFeedbackService {
    private weak var controller: UIInputViewController?

    init(controller: UIInputViewController) {
        self.controller = controller
        super.init()
    }

    override func triggerAudioFeedback(_ feedback: Feedback.Audio) {
        guard feedback != .none, SharedKeyboardState.keyboardClickSound,
              controller?.hasFullAccess == true else { return }
        // The public input-click API honors iOS keyboard-click preferences and silent mode.
        UIDevice.current.playInputClick()
    }

    override func triggerHapticFeedback(_ feedback: Feedback.Haptic) {
        guard SharedKeyboardState.keyboardHaptics, controller?.hasFullAccess == true else { return }
        super.triggerHapticFeedback(feedback)
    }
}

private final class BlipActionHandler: KeyboardAction.StandardActionHandler {
    override func action(for gesture: Keyboard.Gesture, on action: KeyboardAction) -> KeyboardAction.GestureAction? {
        if action == .custom(named: "blip.nextLayout"), gesture == .release {
            return { controller in (controller as? KeyboardViewController)?.cycleLayout() }
        }
        return super.action(for: gesture, on: action)
    }
}

private struct BlipPremiumKeyboard: View {
    let state: Keyboard.State
    let services: Keyboard.Services
    @ObservedObject var presentation: BlipKeyboardPresentation
    let insertScan: () -> Void
    @EnvironmentObject private var context: KeyboardContext
    @Environment(\.openURL) private var openURL
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var palette: BlipKeyboardPalette {
        .init(isDark: context.colorScheme == .dark, increasedContrast: colorSchemeContrast == .increased)
    }

    var body: some View {
        KeyboardView(
            layout: layout,
            state: state,
            services: services,
            renderBackground: false,
            buttonContent: { params in
                if params.item.action == .custom(named: "blip.nextLayout") {
                    Text(SharedKeyboardState.nextKeyboardLayoutTitle(after: presentation.layout) ?? "ABC")
                        .font(.system(size: 15, weight: .medium))
                } else {
                    params.view
                }
            },
            buttonView: { params in
                Group {
                    if let label = accessibilityLabel(for: params.item.action) {
                        params.view.accessibilityLabel(label)
                    } else {
                        params.view
                    }
                }
                .keyboardButtonGestureConfiguration(gestureConfiguration(for: params.item.action))
            },
            collapsedView: { _ in EmptyView() },
            emojiKeyboard: { _ in EmptyView() },
            toolbar: { _ in toolbar }
        )
        .keyboardButtonStyle { buttonStyle($0) }
        .keyboardCalloutStyle(calloutStyle)
        .background {
            if presentation.appearance == .blipBlue {
                // Clip only the painted panel, leaving key callouts free to extend above it.
                palette.canvas.clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 12, topTrailingRadius: 12))
            }
        }
        .keyboardCalloutActions { params in
            let custom = Callouts.Actions(characters: [
                "a": "aäáàâãåæ", "o": "oöóòôõøœ", "u": "uüúùû",
                "s": "sßśš", "e": "eéèêë", "i": "iíìîï", "n": "nñń",
                "c": "cçćč", "y": "yýÿ", "z": "zžźż", "ü": "üu", "ö": "öo", "ä": "äa"
            ])
            return custom.actions(for: params.action) ?? params.standardActions(for: context)
        }
    }

    private func gestureConfiguration(for action: KeyboardAction) -> GestureButtonConfiguration {
        var config = GestureButtonConfiguration.standard
        if case .character(let text) = action,
           text.unicodeScalars.contains(where: CharacterSet.letters.contains) {
            config.longPressDelay = 0.35
        }
        return config
    }

    private func buttonStyle(_ params: Keyboard.ButtonStyleBuilderParams) -> Keyboard.ButtonStyle {
        var style = params.standardStyle(for: context)
        if case .character(let text) = params.action,
           text == text.lowercased(), text != text.uppercased() {
            style.fontWeight = .regular
        }
        if presentation.layout == .largeNumbers, params.action.isCharacterAction {
            style.nativeFont = .system(size: 28, weight: .regular)
        }
        guard !params.action.isSpacer else { return style }
        let activeShift: Bool
        if case .shift = params.action {
            activeShift = context.keyboardCase.isUppercasedOrCapslocked
        } else {
            activeShift = false
        }
        let ordinary: Bool
        switch params.action {
        case .character, .space: ordinary = true
        default: ordinary = false
        }
        if presentation.appearance == .blipBlue {
            let emphasized = params.action.isPrimaryAction || activeShift
            style.background = nil
            style.backgroundColor = emphasized
                ? (params.isPressed ? palette.emphasisPressed : palette.emphasis)
                : (params.isPressed ? palette.pressedSurface : (ordinary ? palette.surface : palette.modifier))
            style.foregroundColor = emphasized ? .white : palette.text
            style.shadowColor = palette.shadow
            style.pressedOverlayColor = .clear
            style.borderColor = colorSchemeContrast == .increased ? palette.text : palette.outline
            style.borderSize = colorSchemeContrast == .increased ? 1 : 0.5
        } else if context.colorScheme == .dark {
            // The package's alpha-white assets vary with the host backdrop. Use opaque grays.
            if activeShift && !params.isPressed {
                style.backgroundColor = .white
                style.foregroundColor = .black
            } else if !params.action.isPrimaryAction || params.action.isSystemAction {
                style.backgroundColor = params.isPressed ? Color(white: 0.47)
                    : (ordinary ? Color(white: 0.365) : Color(white: 0.255))
                style.foregroundColor = .white
            }
        }
        return style
    }

    private var calloutStyle: Callouts.CalloutStyle {
        var style = Callouts.CalloutStyle.standard
        style.inputItemFont = .init(.largeTitle, .regular)
        style.backgroundColor = presentation.appearance == .blipBlue
            ? palette.surface : (context.colorScheme == .dark ? Color(white: 0.365) : .white)
        style.foregroundColor = presentation.appearance == .blipBlue
            ? palette.text : (context.colorScheme == .dark ? .white : .black)
        if presentation.appearance == .blipBlue {
            style.selectedBackgroundColor = palette.emphasis
            style.selectedForegroundColor = .white
            style.borderColor = palette.outline
            style.shadowColor = palette.shadow
        }
        return style
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                let requestIdentifier = UUID().uuidString
                SharedKeyboardState.activeScanRequestIdentifier = requestIdentifier
                openURL(SharedKeyboardState.scanURL(requestIdentifier: requestIdentifier))
            } label: {
                Label("Scan", systemImage: "barcode.viewfinder")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .accessibilityLabel(context.locale.language.languageCode?.identifier == "de" ? "Scannen" : "Scan")
            if presentation.canInsertScan {
                Button(action: insertScan) {
                    Label(context.locale.language.languageCode?.identifier == "de" ? "Scan einfügen" : "Insert Last Scan", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .buttonStyle(BlipToolbarButtonStyle(appearance: presentation.appearance, palette: palette))
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var layout: KeyboardKit.KeyboardLayout {
        let profile = presentation.layout
        let rows = KeyboardLayoutEngine.rows(for: profile,
            nextLayoutTitle: SharedKeyboardState.nextKeyboardLayoutTitle(after: profile))
        let landscape = context.interfaceOrientation.isLandscape
        let height: CGFloat = profile == .largeNumbers ? (landscape ? 44 : 58) : (landscape ? 38 : 52)
        var itemRows: KeyboardKit.KeyboardLayout.ItemRows = rows.enumerated().map { index, row in
            let showsGlobe = index == rows.count - 1 && context.needsInputModeSwitchKey
            let globeWeight: CGFloat = showsGlobe ? 1.1 : 0
            let weight = row.keys.reduce(CGFloat.zero) { $0 + $1.widthWeight } + globeWeight
            var items: KeyboardKit.KeyboardLayout.ItemRow = []
            if showsGlobe {
                items.append(item(.nextKeyboard, weight: globeWeight / weight, height: height))
            }
            items += row.keys.map { key in
                item(action(for: key), weight: key.widthWeight / weight, height: height)
            }
            // Inset alphabetic second rows proportionally, preserving balanced key widths.
            if row.leadingInset > 0, !items.isEmpty {
                let inset = min(row.leadingInset / max(context.screenSize.width, 1), 0.05)
                items = items.map { value in
                    var value = value
                    if case .percentage(let fraction) = value.size.width {
                        value.size.width = .percentage(fraction * (1 - 2 * inset))
                    }
                    return value
                }
                items.insert(item(.none, weight: inset, height: height), at: 0)
                items.append(item(.none, weight: inset, height: height))
            }
            return items
        }
        if rows.isEmpty, context.needsInputModeSwitchKey {
            itemRows = [[item(.nextKeyboard, weight: 0.14, height: height), item(.none, weight: 0.86, height: height)]]
        }
        return KeyboardKit.KeyboardLayout(itemRows: itemRows, idealItemHeight: Double(height),
            idealItemInsets: EdgeInsets(top: 4, leading: 3, bottom: 4, trailing: 3))
    }

    private func item(_ action: KeyboardAction, weight: CGFloat, height: CGFloat) -> KeyboardKit.KeyboardLayout.Item {
        .init(action: action, size: .init(width: .percentage(weight), height: height),
            edgeInsets: EdgeInsets(top: 4, leading: 3, bottom: 4, trailing: 3))
    }

    private func action(for key: KeyboardKey) -> KeyboardAction {
        switch key {
        case .text(let text): return .character(context.keyboardCase.isUppercasedOrCapslocked ? text.uppercased() : text)
        case .backspace: return .backspace
        case .space: return .space
        case .shift: return .shift(context.keyboardCase)
        case .switchNextLayout: return .custom(named: "blip.nextLayout")
        case .return:
            let type = context.returnKeyType ?? .return
            return .primary(type == .return ? .newLine : type)
        }
    }

    private func accessibilityLabel(for action: KeyboardAction) -> String? {
        let isGerman = context.locale.language.languageCode?.identifier == "de"
        switch action {
        case .custom(named: "blip.nextLayout"):
            let title = SharedKeyboardState.nextKeyboardLayoutTitle(after: presentation.layout) ?? "ABC"
            return isGerman ? "Zu \(title) wechseln" : "Switch to \(title)"
        case .primary(let type):
            if type == .newLine { return isGerman ? "Zeilenumbruch" : "New line" }
            return type.standardButtonText(for: context.locale)
        case .backspace: return isGerman ? "Löschen" : "Delete"
        case .shift: return isGerman ? "Umschalttaste" : "Shift"
        case .space: return isGerman ? "Leerzeichen" : "Space"
        case .nextKeyboard: return isGerman ? "Nächste Tastatur" : "Next keyboard"
        default: return nil
        }
    }
}

private struct BlipToolbarButtonStyle: ButtonStyle {
    var appearance: KeyboardAppearance
    var palette: BlipKeyboardPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(appearance == .blipBlue ? Color.white : Color.primary)
            .background(appearance == .blipBlue
                ? (configuration.isPressed ? palette.emphasisPressed : palette.emphasis)
                : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if appearance == .blipBlue, palette.increasedContrast {
                    RoundedRectangle(cornerRadius: 10).stroke(palette.text, lineWidth: 1)
                }
            }
            .opacity(appearance == .system && configuration.isPressed ? 0.65 : 1)
    }
}

private struct BlipKeyboardPalette {
    let isDark: Bool
    let increasedContrast: Bool

    // Opaque sRGB surfaces keep the complete theme stable over host-app backdrops.
    var canvas: Color { isDark ? hex(0x101F3B) : hex(0xBCD2F2) }
    var surface: Color { isDark ? hex(0x23466E) : hex(0xEEF5FF) }
    var modifier: Color { isDark ? hex(0x193655) : hex(0xC8DDFA) }
    var pressedSurface: Color { isDark ? hex(0x376594) : hex(0x90B7ED) }
    var text: Color { isDark ? hex(0xF3F8FF) : hex(0x102A4C) }
    var emphasis: Color { isDark ? hex(0x2E65AE) : hex(0x245AB5) }
    var emphasisPressed: Color { hex(0x1B4385) }
    var outline: Color { text.opacity(increasedContrast ? 1 : 0.18) }
    var shadow: Color { hex(0x071B38).opacity(isDark ? 0.5 : 0.22) }

    private func hex(_ value: UInt32) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255, opacity: 1)
    }
}
