import UIKit
import SwiftUI
import KeyboardKit
import os

final class KeyboardViewController: KeyboardInputViewController {
    private static let scanInsertionSettlingDelay: TimeInterval = 0.7
    private let presentation = BlipKeyboardPresentation()
    private var pendingInsertionWorkItem: DispatchWorkItem?
    private var isInsertingScan = false
    private var isKeyboardPresented = false
    private var cachedNeedsInputModeSwitchKey = true
    private let insertionLogger = Logger(subsystem: "com.antoniobeslic.Blip", category: "ScanInsertion")

    // KeyboardKit 9.9.0 reads this from a queued context sync. On iOS 27,
    // UIKit's getter can dereference a disconnected host after disappearance.
    // Refresh synchronously during presentation; deferred readers use the snapshot.
    override var needsInputModeSwitchKey: Bool { cachedNeedsInputModeSwitchKey }

    override func loadView() {
        // Let iOS draw the keyboard backdrop and its rounded system contour.
        inputView = BlipInputView(frame: .zero, inputViewStyle: .keyboard)
        view = inputView
        view.backgroundColor = .clear
#if DEBUG
        BlipGeometryDiagnostics.controller = self
        recordDebugGeometry(event: "loadView")
#endif
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
#if DEBUG
        recordDebugGeometry(event: "didLoad")
#endif
        state.keyboardContext.settings.spaceLongPressBehavior = .moveInputCursor
        NotificationCenter.default.addObserver(self, selector: #selector(extensionHostDidBecomeActive),
            name: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil)
    }

    deinit {
        pendingInsertionWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillSetupKeyboardView() {
#if DEBUG
        recordDebugGeometry(event: "beforeSetupKeyboardView")
#endif
        setupKeyboardView { [unowned self] controller in
            BlipPremiumKeyboard(state: controller.state, services: controller.services,
                presentation: self.presentation,
                scanRequest: { [weak self] in
                    guard let self else { return KeyboardScanRequest(source: "keyboard") }
                    return SharedKeyboardState.keyboardScanRequest(
                        contentType: self.textDocumentProxy.textContentType?.rawValue)
                },
                insertScan: { [weak self] in self?.insertLastScanTapped() })
        }
#if DEBUG
        recordDebugGeometry(event: "afterSetupKeyboardView")
#endif
    }

    override func viewWillSetupInitialKeyboardType() {
        // Blip's enabled profiles, including large numbers and scan-only, own the layout.
        state.keyboardContext.keyboardType = .alphabetic
    }

    override func viewWillSyncWithContext() {
#if DEBUG
        recordDebugGeometry(event: "beforeContextSync")
#endif
        super.viewWillSyncWithContext()
        state.keyboardContext.keyboardType = .alphabetic
        state.keyboardContext.locale = Locale(identifier: SharedKeyboardState.keyboardLanguage == .german ? "de" : "en")
        refreshRecoveryButtonIfNeeded()
#if DEBUG
        recordDebugGeometry(event: "contextSyncQueued")
        DispatchQueue.main.async { [weak self] in
            self?.recordDebugGeometry(event: "contextSyncCompleted")
        }
#endif
    }

    override func viewWillAppear(_ animated: Bool) {
        isKeyboardPresented = true
        cachedNeedsInputModeSwitchKey = super.needsInputModeSwitchKey
#if DEBUG
        BlipGeometryDiagnostics.beginActivation(controller: self)
        recordDebugGeometry(event: "willAppear")
#endif
        presentation.layout = SharedKeyboardState.defaultKeyboardLayout
        super.viewWillAppear(animated)
        SharedKeyboardState.recordKeyboardRuntime(hasFullAccess: hasFullAccess)
        refreshRecoveryButtonIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        schedulePendingScanInsertion()
#if DEBUG
        recordDebugGeometry(event: "didAppear")
        let activation = BlipGeometryDiagnostics.activation
        for delay in [0.1, 0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard BlipGeometryDiagnostics.activation == activation else { return }
                self?.recordDebugGeometry(event: "appeared+\(delay)")
            }
        }
#endif
    }

#if DEBUG
    override func viewWillLayoutSubviews() {
        recordDebugGeometry(event: "beforeLayout")
        super.viewWillLayoutSubviews()
    }
    override func updateViewConstraints() {
        recordDebugGeometry(event: "beforeConstraints")
        super.updateViewConstraints()
        recordDebugGeometry(event: "afterConstraints")
    }
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        recordDebugGeometry(event: "safeAreaChanged")
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recordDebugGeometry(event: "afterLayout")
        DispatchQueue.main.async { [weak self] in
            self?.recordDebugGeometry(event: "settledLayout")
        }
    }
    fileprivate func recordDebugGeometry(event: String) {
        guard isViewLoaded else { return }
        BlipGeometryDiagnostics.beginCapture(controller: self, event: event)
        defer { BlipGeometryDiagnostics.endCapture() }
        BlipGeometryDiagnostics.log(view, role: "extensionRoot", event: event)
        if let inputView { BlipGeometryDiagnostics.log(inputView, role: "inputView", event: event) }
        for child in children where child.isViewLoaded {
            BlipGeometryDiagnostics.log(child.view, role: "hostingView", event: event)
        }
        var pending = [view!]
        while let item = pending.popLast() {
            if let probe = item as? BlipGeometryProbeView {
                BlipGeometryDiagnostics.log(item, role: probe.role, event: event)
            }
            pending.append(contentsOf: item.subviews)
        }
    }
#endif

    override func viewWillDisappear(_ animated: Bool) {
        isKeyboardPresented = false
        pendingInsertionWorkItem?.cancel()
        pendingInsertionWorkItem = nil
#if DEBUG
        recordDebugGeometry(event: "willDisappear")
#endif
        super.viewWillDisappear(animated)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
#if DEBUG
        recordDebugGeometry(event: "textDidChange")
#endif
        schedulePendingScanInsertion()
    }

    override func textDidChangeAsync(_ textInput: UITextInput?) {
        guard isKeyboardPresented, viewIfLoaded?.window != nil else { return }
        super.textDidChangeAsync(textInput)
    }

    fileprivate func cycleLayout() {
        if let next = SharedKeyboardState.nextKeyboardLayout(after: presentation.layout) {
            presentation.layout = next
            state.keyboardContext.keyboardCase = .lowercased
        }
    }

    private func refreshRecoveryButtonIfNeeded() {
        presentation.appearance = SharedKeyboardState.keyboardAppearance
        // The test changes the scan destination, not the normal toolbar or last-scan action.
        presentation.canInsertScan = hasFullAccess && SharedKeyboardState.canAccessAppGroup && (
            !SharedKeyboardState.pendingScannedCode.isEmpty || testPendingInsertion != nil)
    }
    private var isTestField: Bool {
        textDocumentProxy.textContentType?.rawValue.hasPrefix(KeyboardTestSession.contentTypePrefix) == true
    }

    private var testPendingInsertion: PendingScanInsertion? {
        SharedKeyboardState.keyboardTestSession?.insertion(
            contentType: textDocumentProxy.textContentType?.rawValue)
    }

    private var automaticPendingInsertion: PendingScanInsertion? {
        isTestField ? testPendingInsertion : SharedKeyboardState.pendingInsertion
    }

    private func schedulePendingScanInsertion() {
        guard isKeyboardPresented, viewIfLoaded?.window != nil else { return }
#if DEBUG
        if isTestField {
            KeyboardTestDiagnostics.record("schedule", source: "extension", details: [
                "hasPending": automaticPendingInsertion != nil, "hasWindow": view.window != nil,
                "fullAccess": hasFullAccess])
        }
#endif
        guard !isInsertingScan, hasFullAccess, SharedKeyboardState.canAccessAppGroup,
              automaticPendingInsertion != nil else { return }

        pendingInsertionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingInsertionWorkItem = nil
            self?.insertPendingScanIfReady()
        }
        pendingInsertionWorkItem = workItem
        insertionLogger.debug("Automatic scan insertion scheduled")
#if DEBUG
        KeyboardTestDiagnostics.record("scheduled", source: "scanInsertion", details: [
            "requestID": automaticPendingInsertion?.identifier ?? "", "delay": Self.scanInsertionSettlingDelay])
#endif
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanInsertionSettlingDelay, execute: workItem)
    }

    private func insertPendingScanIfReady() {
        guard isKeyboardPresented, viewIfLoaded?.window != nil else { return }
        let proxy = textDocumentProxy
        let contentType = proxy.textContentType?.rawValue
        let isTest = contentType?.hasPrefix(KeyboardTestSession.contentTypePrefix) == true
        let selectedPending = isTest
            ? SharedKeyboardState.keyboardTestSession?.insertion(contentType: contentType)
            : SharedKeyboardState.pendingInsertion
#if DEBUG
        if isTest {
            KeyboardTestDiagnostics.record("attempt", source: "extension", details: [
                "hasPending": selectedPending != nil, "hasWindow": view.window != nil,
                "fullAccess": hasFullAccess, "cachedMatchesNative": proxy === originalTextDocumentProxy,
                "nativeTagMatches": originalTextDocumentProxy.textContentType?.rawValue == contentType])
        }
#endif
        guard !isInsertingScan, view.window != nil, hasFullAccess,
              let pending = selectedPending,
              (!isTest || textDocumentProxy.textContentType?.rawValue == contentType) else {
            insertionLogger.debug("Automatic scan insertion deferred; keyboard or scan is not ready")
            return
        }

        isInsertingScan = true
        defer { isInsertingScan = false }

        proxy.insertText(pending.code)
#if DEBUG
        KeyboardTestDiagnostics.record("proxyWriteIssued", source: "scanInsertion", details: [
            "requestID": pending.identifier])
        if isTest { KeyboardTestDiagnostics.record("proxyWriteIssued", source: "extension") }
#endif
        applyInsertSuffix(SharedKeyboardState.insertSuffix, testContentType: isTest ? contentType : nil)
        if isTest {
            SharedKeyboardState.consumeKeyboardTest(requestID: pending.identifier, contentType: contentType)
#if DEBUG
            KeyboardTestDiagnostics.record("consumed", source: "extension")
#endif
        } else {
            SharedKeyboardState.markPendingInsertionAttempted(identifier: pending.identifier)
        }
        insertionLogger.info("Automatic scan proxy write issued")
    }

    fileprivate func insertLastScanTapped() {
        guard hasFullAccess, SharedKeyboardState.canAccessAppGroup else { return }
        if isTestField, testPendingInsertion != nil {
            insertPendingScanIfReady()
            return
        }
        guard !SharedKeyboardState.pendingScannedCode.isEmpty else { return }

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
        guard isKeyboardPresented, viewIfLoaded?.window != nil else { return }
        insertionLogger.debug("Keyboard host became active")
#if DEBUG
        recordDebugGeometry(event: "hostResume")
#endif
        refreshRecoveryButtonIfNeeded()
        schedulePendingScanInsertion()
    }

    private func applyInsertSuffix(_ suffix: InsertSuffix, testContentType: String? = nil) {
        if let testContentType {
            guard textDocumentProxy.textContentType?.rawValue == testContentType else { return }
        }
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
                      self.isKeyboardPresented,
                      self.view.window === activeWindow else { return }
                if let testContentType {
                    guard self.textDocumentProxy.textContentType?.rawValue == testContentType else { return }
                }
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
    let scanRequest: () -> KeyboardScanRequest
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
                .modifier(BlipImmediateKeyFeedback(
                    action: params.item.action, calloutContext: state.calloutContext, style: buttonStyle))
                .keyboardButtonGestureConfiguration(gestureConfiguration(for: params.item.action))
            },
            collapsedView: { _ in EmptyView() },
            emojiKeyboard: { _ in EmptyView() },
            toolbar: { _ in toolbar }
        )
        .keyboardButtonStyle { buttonStyle($0) }
        .keyboardCalloutStyle(calloutStyle)
#if DEBUG
        .background(BlipGeometryProbe().allowsHitTesting(false).accessibilityHidden(true))
#endif
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
            style.backgroundColor = params.isPressed ? palette.heldSurface
                : (emphasized ? palette.emphasis : (ordinary ? palette.surface : palette.modifier))
            style.foregroundColor = params.isPressed ? palette.heldText : (emphasized ? .white : palette.text)
            style.shadowColor = palette.shadow
            style.pressedOverlayColor = .clear
            style.borderColor = colorSchemeContrast == .increased
                ? (params.isPressed ? palette.heldText : palette.text) : palette.outline
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
        if presentation.appearance == .system, params.isPressed {
            // Use a contrasting surface for touch feedback in both system appearances.
            style.background = nil
            style.backgroundColor = context.colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.25)
            style.foregroundColor = context.colorScheme == .dark ? .black : .white
            style.pressedOverlayColor = .clear
        }
        return style
    }

    private var calloutStyle: Callouts.CalloutStyle {
        var style = Callouts.CalloutStyle.standard
        style.inputItemFont = .init(.largeTitle, .regular)
        // Input previews and accent menus extend the ordinary letter-key surface.
        let letterStyle = buttonStyle(.init(action: .character("a"), isPressed: false))
        style.backgroundColor = letterStyle.backgroundColor ?? style.backgroundColor
        style.foregroundColor = letterStyle.foregroundColor ?? style.foregroundColor
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
                openURL(scanRequest().url)
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
#if DEBUG
        .background(BlipGeometryProbe(role: "toolbar").allowsHitTesting(false).accessibilityHidden(true))
#endif
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

/// Show the held key and input preview from touch-down, before SwiftUI's delayed drag.
/// KeyboardKit continues to own typing, accent selection, repeat, and cursor actions.
private struct BlipImmediateKeyFeedback: ViewModifier {
    let action: KeyboardAction
    let calloutContext: CalloutContext
    let style: Keyboard.ButtonStyleBuilder
    @State private var isTouchDown = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content
                .keyboardButtonStyle { params in
                    style(.init(action: params.action, isPressed: isTouchDown))
                }
                .gesture(BlipKeyTouchObserver(isTouchDown: $isTouchDown))
                .background {
                    GeometryReader { geometry in
                        Color.clear.onChange(of: isTouchDown) { pressed in
                            if pressed {
                                calloutContext.updateInputAction(action, in: geometry)
                            } else {
                                dismissInputPreview()
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
                .onDisappear {
                    isTouchDown = false
                    dismissInputPreview()
                }
        } else {
            content
        }
    }

    private func dismissInputPreview() {
        // A different key may already own the shared preview during fast typing.
        guard calloutContext.inputAction == action else { return }
        calloutContext.resetInputActionWithDelay()
    }
}

@available(iOS 18.0, *)
private struct BlipKeyTouchObserver: UIGestureRecognizerRepresentable {
    @Binding var isTouchDown: Bool

    func makeUIGestureRecognizer(context: Context) -> BlipKeyTouchRecognizer {
        let recognizer = BlipKeyTouchRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.changed = { isTouchDown = $0 }
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: BlipKeyTouchRecognizer, context: Context) {
        recognizer.changed = { isTouchDown = $0 }
    }
}

/// A passive observer: never recognizes or prevents a gesture, and never inserts text.
private final class BlipKeyTouchRecognizer: UIGestureRecognizer {
    var changed: ((Bool) -> Void)?
    private var trackedTouch: UITouch?

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, let touch = touches.first else { return }
        trackedTouch = touch
        changed?(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish()
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
        changed?(false)
    }

    private func finish() {
        trackedTouch = nil
        changed?(false)
        state = .failed
    }
}

private struct BlipToolbarButtonStyle: ButtonStyle {
    var appearance: KeyboardAppearance
    var palette: BlipKeyboardPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed
                ? (appearance == .blipBlue ? palette.heldText : (palette.isDark ? Color.black : Color.white))
                : (appearance == .blipBlue ? Color.white : Color.primary))
            .background(configuration.isPressed
                ? (appearance == .blipBlue ? palette.heldSurface : Color(white: palette.isDark ? 0.92 : 0.25))
                : (appearance == .blipBlue ? palette.emphasis : Color(uiColor: .tertiarySystemFill)),
                in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if appearance == .blipBlue, palette.increasedContrast {
                    RoundedRectangle(cornerRadius: 10).stroke(palette.text, lineWidth: 1)
                }
            }
    }
}

private struct BlipKeyboardPalette {
    let isDark: Bool
    let increasedContrast: Bool

    // Opaque sRGB surfaces keep the complete theme stable over host-app backdrops.
    var canvas: Color { isDark ? hex(0x101F3B) : hex(0xBCD2F2) }
    var surface: Color { isDark ? hex(0x23466E) : hex(0xEEF5FF) }
    var modifier: Color { isDark ? hex(0x193655) : hex(0xC8DDFA) }
    var heldSurface: Color { isDark ? hex(0xBBD6FB) : hex(0x376594) }
    var heldText: Color { isDark ? hex(0x102A4C) : .white }
    var text: Color { isDark ? hex(0xF3F8FF) : hex(0x102A4C) }
    var emphasis: Color { isDark ? hex(0x2E65AE) : hex(0x245AB5) }
    var outline: Color { text.opacity(increasedContrast ? 1 : 0.18) }
    var shadow: Color { hex(0x071B38).opacity(isDark ? 0.5 : 0.22) }

    private func hex(_ value: UInt32) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255, opacity: 1)
    }
}

#if DEBUG
/// Numeric-only diagnostics. Never inspect proxy text, clipboard, scan values or view descriptions.
@MainActor
private enum BlipGeometryDiagnostics {
    private static let logger = Logger(subsystem: "com.antoniobeslic.Blip", category: "KeyboardGeometry")
    private static var lastReports: [String: String] = [:]
    private static var snapshots: [String: [String: Any]] = [:]
    private static var snapshotWriteScheduled = false
    static weak var controller: KeyboardViewController?
    static private(set) var activation = 0
    private static let processID = UUID().uuidString
    private static var sequence = 0
    private static var capture: [String: Any]?
    private static var captureViews: [[String: Any]] = []
    private static var timeline: [[String: Any]] = []
    private static var lastLayoutSignature: Data?

    static func beginActivation(controller: KeyboardViewController) {
        self.controller = controller
        activation += 1
        lastLayoutSignature = nil
    }

    static func beginCapture(controller: KeyboardViewController, event: String) {
        let context = controller.state.keyboardContext
        // Geometry callbacks also run after the host disconnects. Never inspect
        // live text-input traits here; numeric view geometry and cached state suffice.
        captureViews = []
        capture = ["event": event, "activation": activation, "sequence": sequence,
            "capturedAt": Date().timeIntervalSince1970,
            "context": ["initialSetupComplete": controller.hasPerformedInitialSetup,
                "orientation": String(describing: context.interfaceOrientation),
                "screenSize": [Double(context.screenSize.width), Double(context.screenSize.height)],
                "needsGlobe": context.needsInputModeSwitchKey,
                "cachedNeedsGlobe": controller.needsInputModeSwitchKey,
                "floating": context.isKeyboardFloating,
                "keyboardType": String(describing: context.keyboardType),
                "uiStyle": controller.traitCollection.userInterfaceStyle.rawValue,
                "colorScheme": String(describing: context.colorScheme),
                "appearance": SharedKeyboardState.keyboardAppearance.rawValue,
                "layout": SharedKeyboardState.defaultKeyboardLayout.rawValue,
                "additionalSafeArea": insets(controller.additionalSafeAreaInsets),
                "preferredContentSize": [Double(controller.preferredContentSize.width), Double(controller.preferredContentSize.height)]]]
    }

    static func endCapture() {
        guard var report = capture else { return }
        capture = nil
        report["views"] = captureViews
        let signatureViews = captureViews.map { view -> [String: Any] in
            var fields = view
            fields.removeValue(forKey: "event")
            return fields
        }
        let signatureObject: [String: Any] = ["context": report["context"]!, "views": signatureViews]
        let signature = try? JSONSerialization.data(withJSONObject: signatureObject, options: [.sortedKeys])
        let event = report["event"] as? String ?? ""
        let isLayoutEvent = ["beforeLayout", "afterLayout", "settledLayout", "beforeConstraints", "afterConstraints"].contains(event)
            || event.hasPrefix("probe.")
        if isLayoutEvent, signature == lastLayoutSignature { return }
        lastLayoutSignature = signature
        sequence += 1
        timeline.append(report)
        if timeline.count > 80 { timeline.removeFirst(timeline.count - 80) }
        scheduleSnapshotWrite()
    }

    private static func scheduleSnapshotWrite() {
        guard !snapshotWriteScheduled else { return }
        snapshotWriteScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            snapshotWriteScheduled = false
            let defaults = UserDefaults(suiteName: SharedKeyboardState.appGroupIdentifier)
            if let data = try? JSONSerialization.data(withJSONObject: snapshots, options: [.sortedKeys]) {
                defaults?.set(data, forKey: "debugKeyboardGeometry")
            }
            let envelope: [String: Any] = ["schemaVersion": 2, "processID": processID,
                "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                "records": timeline]
            guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]) else { return }
            defaults?.set(data, forKey: "debugKeyboardActivations")
        }
    }

    private static func saveSnapshot(_ report: [String: Any], key: String) {
        var snapshot = report
        snapshot["capturedAt"] = Date().timeIntervalSince1970
        snapshots[key] = snapshot
        scheduleSnapshotWrite()
    }

    private static func rect(_ value: CGRect) -> [Any] {
        [value.origin.x, value.origin.y, value.width, value.height].map {
            $0.isFinite ? Double(($0 * 1000).rounded() / 1000) as Any : NSNull()
        }
    }

    private static func insets(_ value: UIEdgeInsets) -> [Double] {
        [value.top, value.left, value.bottom, value.right].map(Double.init)
    }

    static func log(_ view: UIView, role: String, event: String) {
        let window = view.window
        func geometry(_ item: UIView) -> [String: Any] {
            let margins = item.directionalLayoutMargins
            var result: [String: Any] = ["class": String(describing: type(of: item)), "frame": rect(item.frame),
                "bounds": rect(item.bounds), "hasWindow": item.window != nil,
                "intrinsicSize": [Double(item.intrinsicContentSize.width), Double(item.intrinsicContentSize.height)],
                "autoresizingMask": item.autoresizingMask.rawValue,
                "translatesAutoresizingMask": item.translatesAutoresizingMaskIntoConstraints,
                "verticalConstraints": item.constraints.filter { constraint in
                    [.top, .bottom, .height, .centerY].contains(constraint.firstAttribute)
                }.prefix(12).map { constraint in
                    ["firstClass": constraint.firstItem.map { String(describing: type(of: $0)) } ?? "",
                        "firstAttribute": constraint.firstAttribute.rawValue,
                        "secondClass": constraint.secondItem.map { String(describing: type(of: $0)) } ?? "",
                        "secondAttribute": constraint.secondAttribute.rawValue,
                        "constant": Double(constraint.constant), "multiplier": Double(constraint.multiplier),
                        "relation": constraint.relation.rawValue, "priority": Double(constraint.priority.rawValue),
                        "active": constraint.isActive] as [String: Any]
                },
                "safeArea": insets(item.safeAreaInsets), "layoutMargins": insets(item.layoutMargins),
                "directionalMargins": [Double(margins.top), Double(margins.leading), Double(margins.bottom), Double(margins.trailing)]]
            if let window {
                let inWindow = item.convert(item.bounds, to: window)
                result["inWindow"] = rect(inWindow)
                result["inScreen"] = rect(window.convert(inWindow, to: window.screen.coordinateSpace))
            }
            return result
        }
        func emit(_ fields: [String: Any], suffix: String) {
            var report = fields
            report["role"] = role + suffix
            report["event"] = event
            report["appearance"] = SharedKeyboardState.keyboardAppearance.rawValue
            guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
                  let message = String(data: data, encoding: .utf8) else { return }
            let key = role + suffix + event
            if capture != nil, suffix.isEmpty || (role == "extensionRoot" && suffix.hasPrefix(".parent")) {
                captureViews.append(report)
            }
            saveSnapshot(report, key: key)
            guard lastReports[key] != message else { return }
            lastReports[key] = message
            logger.info("BLIP_GEOMETRY \(message, privacy: .public)")
        }
        // The physical relay truncates long messages; keep each geometry record separate.
        emit(["view": geometry(view)], suffix: "")
        if let window {
            emit(["windowFrame": rect(window.frame), "windowBounds": rect(window.bounds),
                "screenBounds": rect(window.screen.coordinateSpace.bounds),
                "screenScale": Double(window.screen.scale)], suffix: ".window")
        }
        var parent = view.superview
        var index = 0
        while let item = parent, index < 8 {
            emit(["view": geometry(item)], suffix: ".parent\(index)")
            parent = item.superview
            index += 1
        }
    }
}

private struct BlipGeometryProbe: UIViewRepresentable {
    var role = "swiftuiPanel"
    func makeUIView(context: Context) -> BlipGeometryProbeView {
        let view = BlipGeometryProbeView()
        view.role = role
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }
    func updateUIView(_ uiView: BlipGeometryProbeView, context: Context) {}
}

private final class BlipGeometryProbeView: UIView {
    var role = "swiftuiPanel"
    override func layoutSubviews() {
        super.layoutSubviews()
        reportAfterLayout()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportAfterLayout()
    }
    private func reportAfterLayout() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.window != nil else { return }
            BlipGeometryDiagnostics.controller?.recordDebugGeometry(event: "probe.\(self.role).afterLayout")
        }
    }
}
#endif
