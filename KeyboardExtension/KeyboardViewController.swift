import UIKit
import SwiftUI
import os

final class KeyboardViewController: UIInputViewController {
    private let rootStack = UIStackView()
    private var heightConstraint: NSLayoutConstraint?
    private var hostedToolbarControllers: [UIViewController] = []
    private var activeLayout = SharedKeyboardState.defaultKeyboardLayout
    private var isShifted = false
    private var pendingInsertionWorkItem: DispatchWorkItem?
    private var isInsertingScan = false
    private let insertionLogger = Logger(subsystem: "com.antoniobeslic.Blip", category: "ScanInsertion")

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(extensionHostDidBecomeActive),
            name: NSNotification.Name.NSExtensionHostDidBecomeActive,
            object: nil
        )
        configureRootStack()
        rebuildKeyboard()
    }

    deinit {
        pendingInsertionWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let storedLayout = SharedKeyboardState.defaultKeyboardLayout
        if storedLayout != activeLayout {
            activeLayout = storedLayout
            rebuildKeyboard()
        }

        SharedKeyboardState.recordKeyboardRuntime(hasFullAccess: hasFullAccess)
        refreshRecoveryButtonIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        insertionLogger.debug("Keyboard view appeared")
        schedulePendingScanInsertion()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pendingInsertionWorkItem?.cancel()
        pendingInsertionWorkItem = nil
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        insertionLogger.debug("Keyboard text context changed")
        schedulePendingScanInsertion()
    }

    private func configureRootStack() {
        view.backgroundColor = .systemGray4

        rootStack.axis = .vertical
        rootStack.spacing = 8
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
    }

    private func rebuildKeyboard() {
        clearHostedToolbarControllers()

        rootStack.arrangedSubviews.forEach { view in
            rootStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        rootStack.addArrangedSubview(makeToolbar())

        let nextLayoutTitle = SharedKeyboardState.nextKeyboardLayoutTitle(after: activeLayout)
        for row in KeyboardLayoutEngine.rows(for: activeLayout, nextLayoutTitle: nextLayoutTitle) {
            rootStack.addArrangedSubview(makeRow(row))
        }

        heightConstraint?.isActive = false
        heightConstraint = view.heightAnchor.constraint(equalToConstant: KeyboardLayoutEngine.height(for: activeLayout))
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true
    }

    private func makeToolbar() -> UIView {
        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.alignment = .fill
        toolbar.spacing = 6
        toolbar.heightAnchor.constraint(equalToConstant: 38).isActive = true

        let scanButton = makeScannerButton()
        toolbar.addArrangedSubview(scanButton)

        if hasFullAccess, SharedKeyboardState.canAccessAppGroup,
           !SharedKeyboardState.pendingScannedCode.isEmpty {
            let insertButton = UIButton(type: .system)
            insertButton.setTitle(NSLocalizedString("Insert Last Scan", comment: "Manually insert the last scanned code"), for: .normal)
            insertButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            insertButton.backgroundColor = .secondarySystemBackground
            insertButton.layer.cornerRadius = 6
            insertButton.addTarget(self, action: #selector(insertLastScanTapped), for: .touchUpInside)
            toolbar.addArrangedSubview(insertButton)
            insertButton.widthAnchor.constraint(equalTo: scanButton.widthAnchor).isActive = true
        } else {
            scanButton.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true
        }

        return toolbar
    }

    private func clearHostedToolbarControllers() {
        for controller in hostedToolbarControllers {
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        }

        hostedToolbarControllers.removeAll()
    }

    private func makeScannerButton() -> UIView {
        let controller = UIHostingController(rootView: KeyboardScannerButton())

        addChild(controller)
        controller.view.backgroundColor = .clear
        controller.view.heightAnchor.constraint(equalToConstant: 38).isActive = true
        controller.didMove(toParent: self)
        hostedToolbarControllers.append(controller)

        return controller.view
    }

    private func makeRow(_ keyboardRow: KeyboardRow) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 5
        row.distribution = .fill
        row.heightAnchor.constraint(equalToConstant: KeyboardLayoutEngine.rowHeight(for: activeLayout)).isActive = true
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: keyboardRow.leadingInset,
            bottom: 0,
            trailing: keyboardRow.trailingInset
        )

        let buttons = keyboardRow.keys.map(makeKeyButton(for:))

        for button in buttons {
            row.addArrangedSubview(button)
        }

        if let firstButton = buttons.first, let firstKey = keyboardRow.keys.first {
            for (button, key) in zip(buttons.dropFirst(), keyboardRow.keys.dropFirst()) {
                button.widthAnchor.constraint(equalTo: firstButton.widthAnchor, multiplier: key.widthWeight / firstKey.widthWeight).isActive = true
            }
        }

        return row
    }

    private func makeKeyButton(for key: KeyboardKey) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(key.title(isShifted: isShifted, activeLayout: activeLayout), for: .normal)
        button.titleLabel?.font = keyFont(for: key)
        button.tintColor = .label
        button.backgroundColor = keyBackgroundColor(for: key)
        button.layer.cornerRadius = 5
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0 : 0.18
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.accessibilityLabel = accessibilityLabel(for: key)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        button.key = key
        return button
    }

    private func keyFont(for key: KeyboardKey) -> UIFont {
        switch key {
        case .text:
            if activeLayout == .largeNumbers {
                return .systemFont(ofSize: 28, weight: .regular)
            }

            return .systemFont(ofSize: 22, weight: .regular)
        case .space:
            return .systemFont(ofSize: 16, weight: .regular)
        default:
            return .systemFont(ofSize: 16, weight: .regular)
        }
    }

    private func keyBackgroundColor(for key: KeyboardKey) -> UIColor {
        key.isPrimaryText ? .systemBackground : .systemGray3
    }

    private func accessibilityLabel(for key: KeyboardKey) -> String {
        switch key {
        case let .text(value):
            value
        case .backspace:
            NSLocalizedString("Delete", comment: "Delete key accessibility label")
        case .space:
            NSLocalizedString("Space", comment: "Space key accessibility label")
        case .return:
            NSLocalizedString("Return", comment: "Return key accessibility label")
        case .shift:
            NSLocalizedString("Shift", comment: "Shift key accessibility label")
        case .switchNextLayout:
            NSLocalizedString("Switch layout", comment: "Switch layout key accessibility label")
        }
    }

    @objc private func keyTapped(_ sender: UIButton) {
        guard let key = sender.key else { return }

        switch key {
        case let .text(value):
            textDocumentProxy.insertText(isShifted ? value.uppercased() : value)
        case .backspace:
            textDocumentProxy.deleteBackward()
        case .space:
            textDocumentProxy.insertText(" ")
        case .return:
            textDocumentProxy.insertText("\n")
        case .shift:
            isShifted.toggle()
            rebuildKeyboard()
        case .switchNextLayout:
            isShifted = false
            if let nextLayout = SharedKeyboardState.nextKeyboardLayout(after: activeLayout) {
                activeLayout = nextLayout
                rebuildKeyboard()
            }
        }
    }

    private func refreshRecoveryButtonIfNeeded() {
        let shouldShow = hasFullAccess && SharedKeyboardState.canAccessAppGroup &&
            !SharedKeyboardState.pendingScannedCode.isEmpty
        let isShowing = rootStack.arrangedSubviews.first
            .flatMap { ($0 as? UIStackView)?.arrangedSubviews.count == 2 } ?? false
        if shouldShow != isShowing { rebuildKeyboard() }
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

    @objc private func insertLastScanTapped() {
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

private var keyboardKeyAssociation = 0

private extension UIButton {
    var key: KeyboardKey? {
        get {
            objc_getAssociatedObject(self, &keyboardKeyAssociation) as? KeyboardKey
        }
        set {
            objc_setAssociatedObject(self, &keyboardKeyAssociation, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private struct KeyboardScannerButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            let requestIdentifier = UUID().uuidString
            SharedKeyboardState.activeScanRequestIdentifier = requestIdentifier
            openURL(SharedKeyboardState.scanURL(requestIdentifier: requestIdentifier))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "barcode.viewfinder")
                Text("Scan")
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color(uiColor: .label))
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
