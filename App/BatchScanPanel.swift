import SwiftUI
import UIKit

/// A short line above the batch list: added confirmation, limit, hints.
struct BatchScanPanelStatus: Equatable {
    let message: String
    let systemImage: String
    let tint: Color
}

/// Bottom panel over the camera while batch scanning: numbered list (newest
/// kept in view), per-entry delete, count, and the button that finishes the
/// batch. It stays below the centred scan guide so the target remains visible.
struct BatchScanPanel: View {
    let entries: [BatchScanEntry]
    let status: BatchScanPanelStatus?
    let finishTitle: String
    let finishHint: String
    let zoomFactor: Double?
    let onRemove: (BatchScanEntry.ID) -> Void
    let onFinish: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Never let the panel shrink to nothing on short (landscape) screens.
    private static let minimumHeight: CGFloat = 104
    private static let maximumWidth: CGFloat = 560
    private static let outerPadding: CGFloat = 12
    private static let guideSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                panel
                    .frame(maxWidth: Self.maximumWidth)
                    .frame(maxHeight: Self.maximumHeight(in: geometry), alignment: .bottom)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, Self.outerPadding)
        }
        // Very large text would otherwise push the panel over the scan target.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    /// The space between the bottom of the centred scan guide (drawn over the
    /// full screen) and the bottom of the safe area.
    private static func maximumHeight(in geometry: GeometryProxy) -> CGFloat {
        let insets = geometry.safeAreaInsets
        let fullHeight = geometry.size.height + insets.top + insets.bottom
        let guideBottom = fullHeight * (0.5 + ScannerScanAreaGuide.heightRatio / 2)
        let panelBottom = insets.top + geometry.size.height - outerPadding
        return max(panelBottom - guideBottom - guideSpacing, minimumHeight)
    }

    @ViewBuilder
    private var panel: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        header
                        statusLine
                        list
                    }
                    finishButton
                        .frame(maxWidth: 220)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    statusLine
                    list
                    finishButton
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: status)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.number")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text("Batch")
                .font(.subheadline.weight(.semibold))
            Text(Self.countText(entries.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            if let zoomFactor {
                Text(String(format: "%.1fx", zoomFactor))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let status {
            Label {
                Text(status.message)
                    .font(.caption)
                    .lineLimit(3)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.tint)
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var list: some View {
        if entries.isEmpty {
            Text("Scan codes to add them to the list.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Short lists hug their content; longer ones scroll with the newest
            // entry kept in view.
            ViewThatFits(in: .vertical) {
                rows
                ScrollViewReader { proxy in
                    ScrollView {
                        rows
                    }
                    .onAppear { scrollToNewest(proxy, animated: false) }
                    .onChange(of: entries.last?.id) { _ in scrollToNewest(proxy, animated: true) }
                }
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                BatchScanRow(number: index + 1, entry: entry) {
                    onRemove(entry.id)
                }
                .id(entry.id)
                if index < entries.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var finishButton: some View {
        Button(action: onFinish) {
            Text(finishTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(verticalSizeClass == .compact ? .regular : .large)
        .disabled(entries.isEmpty)
        .accessibilityHint(finishHint)
    }

    private func scrollToNewest(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let newest = entries.last?.id else { return }
        if animated, !reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(newest, anchor: .bottom) }
        } else {
            proxy.scrollTo(newest, anchor: .bottom)
        }
    }

    static func countText(_ count: Int) -> String {
        count == 1
            ? NSLocalizedString("1 code", comment: "Batch list count, singular")
            : String(format: NSLocalizedString("%d codes", comment: "Batch list count, plural"), count)
    }
}

private struct BatchScanRow: View {
    let number: Int
    let entry: BatchScanEntry
    let onRemove: () -> Void

    @ScaledMetric(relativeTo: .body) private var numberWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number).")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: numberWidth, alignment: .trailing)
            Text(entry.value)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        // VoiceOver reads one element per entry with a Remove action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(number). \(entry.value), \(ScanHistoryItem.displayName(forCodeFormat: entry.codeFormat))"))
        .accessibilityAction(named: Text("Remove")) { onRemove() }
    }
}

/// Scanner toolbar control that switches Single / Batch for the current scan only.
struct BatchScanModeMenu: View {
    @Binding var selection: ScannerScanMode

    var body: some View {
        Menu {
            Picker("Scan Mode", selection: $selection) {
                ForEach(ScannerScanMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Image(systemName: selection == .batch ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                .foregroundStyle(selection == .batch ? .yellow : .primary)
        }
        .accessibilityLabel(Text("Scan Mode"))
        .accessibilityValue(Text(selection.title))
    }
}

extension View {
    /// Asks before a non-empty batch is thrown away (cancel, or switching to single scan).
    func batchDiscardConfirmation(
        _ reason: Binding<BatchScanDiscardReason?>,
        onConfirm: @escaping (BatchScanDiscardReason) -> Void
    ) -> some View {
        confirmationDialog(
            "Discard scanned codes?",
            isPresented: Binding(
                get: { reason.wrappedValue != nil },
                set: { if !$0 { reason.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: reason.wrappedValue
        ) { presented in
            Button(presented.confirmTitle, role: .destructive) {
                reason.wrappedValue = nil
                onConfirm(presented)
            }
            Button("Keep Scanning", role: .cancel) {
                reason.wrappedValue = nil
            }
        } message: { _ in
            Text("The codes in the list are not inserted or saved.")
        }
    }
}

/// What a confirmed discard of a non-empty batch leads to.
enum BatchScanDiscardReason: Identifiable {
    case cancel
    case switchToSingle

    var id: Self { self }

    var confirmTitle: String {
        switch self {
        case .cancel:
            NSLocalizedString("Discard and Close", comment: "Confirm discarding the batch and closing the scanner")
        case .switchToSingle:
            NSLocalizedString("Discard and Switch", comment: "Confirm discarding the batch and switching to single scan")
        }
    }
}

/// State of one batch scan inside the scanner screen: the collected codes,
/// transient notices and VoiceOver announcements. Lives only as long as the
/// scanner is presented.
@MainActor
final class BatchScanModel: ObservableObject {
    @Published private(set) var collection = BatchScanCollection()
    @Published private var notice: BatchScanPanelStatus?
    private var noticeToken = UUID()

    private static let noticeDuration: TimeInterval = 2.0

    /// Adds a decoded code. Returns false when the batch is already full.
    @discardableResult
    func add(_ result: ScannerCodeResult, playScanSound: Bool) -> Bool {
        let entry = BatchScanEntry(value: result.value, codeFormat: result.codeFormat)
        guard case .added(let count) = collection.append(entry) else {
            announce(Self.limitMessage)
            return false
        }
        ScanSoundPlayer.shared.playIfEnabled(playScanSound)
        show(BatchScanPanelStatus(
            message: String(format: NSLocalizedString("Added %@", comment: "Batch status after a code was added; %@ is the code"), result.value),
            systemImage: "checkmark.circle.fill",
            tint: .green
        ))
        var announcement = count == 1
            ? NSLocalizedString("Added, 1 code.", comment: "VoiceOver after the first batch code")
            : String(format: NSLocalizedString("Added, %d codes.", comment: "VoiceOver after a batch code; %d is the count"), count)
        if collection.isFull {
            announcement += " " + Self.limitMessage
        }
        announce(announcement)
        return true
    }

    /// A company-profile QR never joins a batch; the collected codes stay.
    func ignoreCompanyProfile() {
        let message = NSLocalizedString(
            "Company profile QR codes can't be added to a batch.",
            comment: "Batch status when a company profile QR code was scanned"
        )
        show(BatchScanPanelStatus(message: message, systemImage: "exclamationmark.triangle.fill", tint: .orange))
        announce(message)
    }

    func remove(id: BatchScanEntry.ID) {
        collection.remove(id: id)
        notice = nil
        announce(BatchScanPanel.countText(collection.count))
    }

    func removeAll() {
        collection.removeAll()
        notice = nil
    }

    func status(selectableCodeCount: Int) -> BatchScanPanelStatus? {
        if collection.isFull {
            return BatchScanPanelStatus(message: Self.limitMessage, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
        if let notice {
            return notice
        }
        if selectableCodeCount > 0 {
            return BatchScanPanelStatus(
                message: NSLocalizedString("Tap the code you want to use.", comment: "Hint when several codes are visible"),
                systemImage: "hand.tap.fill",
                tint: .yellow
            )
        }
        return nil
    }

    func finishTitle(insertsIntoKeyboard: Bool) -> String {
        let count = collection.count
        if insertsIntoKeyboard {
            switch count {
            case 0: return NSLocalizedString("Insert Codes", comment: "Batch finish button without codes")
            case 1: return NSLocalizedString("Insert 1 Code", comment: "Batch finish button, one code")
            default: return String(format: NSLocalizedString("Insert %d Codes", comment: "Batch finish button; %d is the count"), count)
            }
        }
        switch count {
        case 0: return NSLocalizedString("Done", comment: "Batch finish button for in-app scans without codes")
        case 1: return NSLocalizedString("Done – 1 Code", comment: "Batch finish button for in-app scans, one code")
        default: return String(format: NSLocalizedString("Done – %d Codes", comment: "Batch finish button for in-app scans; %d is the count"), count)
        }
    }

    func finishHint(insertsIntoKeyboard: Bool) -> String {
        insertsIntoKeyboard
            ? NSLocalizedString("Returns and inserts all codes at once.", comment: "Batch finish button accessibility hint, keyboard")
            : NSLocalizedString("Copies all codes and saves them to History.", comment: "Batch finish button accessibility hint, app")
    }

    private static var limitMessage: String {
        String(
            format: NSLocalizedString(
                "Limit of %d codes reached. Insert the list or remove codes to continue.",
                comment: "Batch status when the maximum number of codes is reached; %d is the limit"
            ),
            BatchScanLimit.maximumCodeCount
        )
    }

    private func show(_ status: BatchScanPanelStatus) {
        notice = status
        let token = UUID()
        noticeToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.noticeDuration) { [weak self] in
            guard let self, self.noticeToken == token else { return }
            self.notice = nil
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
