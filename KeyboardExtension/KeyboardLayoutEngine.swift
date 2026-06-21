import Foundation

enum KeyboardKey: Hashable {
    case text(String)
    case backspace
    case space
    case `return`
    case shift
    case switchNextLayout(String)

    func title(isShifted: Bool, activeLayout: KeyboardLayout) -> String {
        switch self {
        case let .text(value):
            isShifted ? value.uppercased() : value
        case .backspace:
            "⌫"
        case .space:
            NSLocalizedString("space", comment: "Space key title")
        case .return:
            NSLocalizedString("return", comment: "Return key title")
        case .shift:
            "⇧"
        case let .switchNextLayout(title):
            title
        }
    }

    var widthWeight: CGFloat {
        switch self {
        case let .text(value):
            value == "." ? 0.65 : 1
        case .space:
            4.2
        case .backspace, .return, .shift, .switchNextLayout:
            1.45
        }
    }

    var isPrimaryText: Bool {
        switch self {
        case .text, .space:
            true
        default:
            false
        }
    }
}

struct KeyboardRow {
    let keys: [KeyboardKey]
    let leadingInset: CGFloat
    let trailingInset: CGFloat

    init(_ keys: [KeyboardKey], leadingInset: CGFloat = 0, trailingInset: CGFloat = 0) {
        self.keys = keys
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
    }
}

struct KeyboardLayoutEngine {
    static func rows(for layout: KeyboardLayout, nextLayoutTitle: String?) -> [KeyboardRow] {
        switch layout {
        case .english:
            [
                KeyboardRow("qwertyuiop".map { .text(String($0)) }),
                KeyboardRow("asdfghjkl".map { .text(String($0)) }, leadingInset: 18, trailingInset: 18),
                KeyboardRow([.shift] + "zxcvbnm".map { .text(String($0)) } + [.backspace]),
                KeyboardRow(utilityRowKeys(nextLayoutTitle: nextLayoutTitle)),
            ]
        case .german:
            [
                KeyboardRow("qwertzuiopü".map { .text(String($0)) }),
                KeyboardRow("asdfghjklöä".map { .text(String($0)) }, leadingInset: 2, trailingInset: 2),
                KeyboardRow([.shift] + "yxcvbnm".map { .text(String($0)) } + [.backspace]),
                KeyboardRow(utilityRowKeys(nextLayoutTitle: nextLayoutTitle)),
            ]
        case .numeric:
            [
                KeyboardRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { .text($0) }),
                KeyboardRow(["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""].map { .text($0) }),
                KeyboardRow([".", ",", "?", "!", "'", "#", "+", "*"].map { .text($0) }, leadingInset: 22, trailingInset: 22),
                KeyboardRow(numericUtilityRowKeys(nextLayoutTitle: nextLayoutTitle)),
            ]
        case .largeNumbers:
            [
                KeyboardRow(["1", "2", "3"].map { .text($0) }),
                KeyboardRow(["4", "5", "6"].map { .text($0) }),
                KeyboardRow(["7", "8", "9"].map { .text($0) }),
                KeyboardRow([.text("."), .text("0"), .backspace]),
                KeyboardRow(largeNumberUtilityRowKeys(nextLayoutTitle: nextLayoutTitle)),
            ]
        case .scanOnly:
            []
        }
    }

    static func height(for layout: KeyboardLayout) -> CGFloat {
        switch layout {
        case .english, .german:
            292
        case .numeric:
            264
        case .largeNumbers:
            322
        case .scanOnly:
            56
        }
    }

    static func rowHeight(for layout: KeyboardLayout) -> CGFloat {
        switch layout {
        case .largeNumbers:
            52
        case .english, .german, .numeric, .scanOnly:
            44
        }
    }

    private static func utilityRowKeys(nextLayoutTitle: String?) -> [KeyboardKey] {
        var keys: [KeyboardKey] = []
        if let nextLayoutTitle {
            keys.append(.switchNextLayout(nextLayoutTitle))
        }
        keys.append(contentsOf: [.space, .text("."), .return])
        return keys
    }

    private static func numericUtilityRowKeys(nextLayoutTitle: String?) -> [KeyboardKey] {
        var keys: [KeyboardKey] = []
        if let nextLayoutTitle {
            keys.append(.switchNextLayout(nextLayoutTitle))
        }
        keys.append(contentsOf: [.space, .text("."), .backspace, .return])
        return keys
    }

    private static func largeNumberUtilityRowKeys(nextLayoutTitle: String?) -> [KeyboardKey] {
        var keys: [KeyboardKey] = []
        if let nextLayoutTitle {
            keys.append(.switchNextLayout(nextLayoutTitle))
        }
        keys.append(contentsOf: [.space, .return])
        return keys
    }
}
