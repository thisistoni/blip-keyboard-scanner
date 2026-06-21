import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {
    private let rootStack = UIStackView()
    private var heightConstraint: NSLayoutConstraint?
    private var hostedToolbarControllers: [UIViewController] = []
    private var activeLayout = SharedKeyboardState.defaultKeyboardLayout
    private var isShifted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureRootStack()
        rebuildKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let storedLayout = SharedKeyboardState.defaultKeyboardLayout
        if storedLayout != activeLayout {
            activeLayout = storedLayout
            rebuildKeyboard()
        }

        SharedKeyboardState.recordKeyboardRuntime(hasFullAccess: hasFullAccess)
        insertPendingScanIfNeeded()
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
        scanButton.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true

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

    private func insertPendingScanIfNeeded() {
        guard hasFullAccess, SharedKeyboardState.canAccessAppGroup else { return }

        let identifier = SharedKeyboardState.pendingScanIdentifier
        let activeIdentifier = SharedKeyboardState.activeScanRequestIdentifier
        let code = SharedKeyboardState.pendingScannedCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !identifier.isEmpty,
              activeIdentifier.isEmpty || identifier == activeIdentifier,
              identifier != SharedKeyboardState.consumedScanIdentifier,
              !code.isEmpty
        else {
            return
        }

        SharedKeyboardState.consumedScanIdentifier = identifier
        SharedKeyboardState.activeScanRequestIdentifier = ""
        textDocumentProxy.insertText(code)
        applyInsertSuffix(SharedKeyboardState.insertSuffix)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.textDocumentProxy.insertText("\n")
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
