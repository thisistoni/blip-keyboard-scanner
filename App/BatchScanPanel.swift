import SwiftUI
import UIKit

private struct BatchScanPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 220

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Bottom edge of the screen, in global coordinates.
private struct BatchScanScreenBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Top edge of the visible panel, in global coordinates.
private struct BatchScanPanelTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A short line above the batch list: added confirmation, limit, hints.
struct BatchScanPanelStatus: Equatable {
    let message: String
    let systemImage: String
    let tint: Color
    /// Shows an Undo button for the last deleted row.
    var offersUndo = false
    /// The limit notice may take a second line where there is room.
    var isLimit = false
}

/// When the list was last touched. A reference, so noting a touch does not
/// redraw the panel.
private final class BatchScanListTouchClock {
    var lastTouch = Date.distantPast
}

/// Bottom panel over the camera while batch scanning: numbered list (newest
/// kept in view), per-entry delete, count, and the button that finishes the
/// batch. It stays below the centred scan guide so the target remains visible.
struct BatchScanPanel: View {
    let entries: [BatchScanEntry]
    let repeatedEntryIDs: Set<BatchScanEntry.ID>
    let separator: BatchSeparator
    let status: BatchScanPanelStatus?
    let finishTitle: String
    let finishHint: String
    let zoomFactor: Double?
    let onRemove: (BatchScanEntry.ID) -> Void
    let onUndo: () -> Void
    let onFinish: () -> Void
    /// Distance from the panel's top edge to the bottom of the screen, so the
    /// scanner can ignore codes behind the panel.
    let onObscuredHeightChange: (CGFloat) -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Never let the panel shrink to nothing on short (landscape) screens.
    private static let minimumHeight: CGFloat = 104
    private static let maximumWidth: CGFloat = 560
    private static let outerPadding: CGFloat = 12
    private static let guideSpacing: CGFloat = 8
    /// How long after a touch on the list a new code does not scroll it.
    private static let scrollPauseAfterTouch: TimeInterval = 2

    @State private var maximumHeight: CGFloat = 220
    @State private var screenBottom: CGFloat = 0
    @State private var panelTop: CGFloat = 0
    @State private var listTouchClock = BatchScanListTouchClock()
    @GestureState private var isTouchingList = false

    var body: some View {
        // Only the panel itself takes touches. The full-screen measuring layer
        // never hit-tests, and the empty area around the panel is not content,
        // so taps and pinches there reach the camera view underneath.
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: BatchScanPanelHeightKey.self, value: Self.maximumHeight(in: geometry))
                    .preference(
                        key: BatchScanScreenBottomKey.self,
                        value: geometry.frame(in: .global).maxY + geometry.safeAreaInsets.bottom
                    )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            panel
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: BatchScanPanelTopKey.self, value: geometry.frame(in: .global).minY)
                    }
                )
                .frame(maxWidth: Self.maximumWidth)
                .frame(maxHeight: maximumHeight, alignment: .bottom)
                .padding(.horizontal, 16)
                .padding(.bottom, Self.outerPadding)
        }
        .onPreferenceChange(BatchScanPanelHeightKey.self) { maximumHeight = $0 }
        // Reporting changes no layout here, so it cannot feed back into these values.
        .onPreferenceChange(BatchScanScreenBottomKey.self) { bottom in
            screenBottom = bottom
            reportObscuredHeight()
        }
        .onPreferenceChange(BatchScanPanelTopKey.self) { top in
            panelTop = top
            reportObscuredHeight()
        }
        // Very large text would otherwise push the panel over the scan target.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func reportObscuredHeight() {
        guard screenBottom > 0, panelTop > 0 else { return }
        onObscuredHeightChange(max(0, (screenBottom - panelTop).rounded(.up)))
    }

    /// The space between the bottom of the centred scan guide (drawn over the
    /// full screen) and the bottom of the safe area, minus the panel's margins.
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
                        separatorLine
                        statusLine
                        list
                    }
                    finishButton
                        .frame(maxWidth: 220)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    separatorLine
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

    private var separatorLine: some View {
        Text(String(format: NSLocalizedString("Separator: %@", comment: "Batch panel line naming the separator; %@ is its name"), separator.title))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let status {
            HStack(spacing: 8) {
                Label {
                    // One line keeps the list visible on small and landscape
                    // screens; only the limit notice may wrap where there is room.
                    Text(status.message)
                        .font(.caption)
                        .lineLimit(status.isLimit && verticalSizeClass == .regular ? 2 : 1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: status.systemImage)
                        .foregroundStyle(status.tint)
                }
                if status.offersUndo {
                    Spacer(minLength: 0)
                    Button("Undo", action: onUndo)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var list: some View {
        if entries.isEmpty {
            Text("Scan codes to add them to the list. Switch modes with the stack button at the top.")
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
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isTouchingList) { _, isTouching, _ in isTouching = true }
                            .onChanged { _ in listTouchClock.lastTouch = Date() }
                            .onEnded { _ in listTouchClock.lastTouch = Date() }
                    )
                    .onAppear { scrollToNewest(proxy, animated: false) }
                    .onChange(of: entries.last?.id) { _ in
                        // Never slide a row under the thumb of someone using the list.
                        guard !isTouchingList,
                              Date().timeIntervalSince(listTouchClock.lastTouch) > Self.scrollPauseAfterTouch else { return }
                        scrollToNewest(proxy, animated: true)
                    }
                }
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                BatchScanRow(
                    number: index + 1,
                    entry: entry,
                    isRepeat: repeatedEntryIDs.contains(entry.id),
                    containsSeparator: separator.occurs(in: entry.value)
                ) {
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
    /// The same value appears earlier in the list.
    let isRepeat: Bool
    /// The value contains the batch separator, so the joined text is ambiguous.
    let containsSeparator: Bool
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
            if containsSeparator {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if isRepeat {
                Text("Duplicate")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .fixedSize()
            }
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        // VoiceOver reads one element per entry with a Remove action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
        .accessibilityValue(Text(verbatim: entry.value))
        .accessibilityAction(named: Text("Remove")) { onRemove() }
    }

    /// Long payloads are cut here; the full code is the element's value.
    private var accessibilityLabel: String {
        var parts = [
            "\(number). \(entry.spokenValue)",
            ScanHistoryItem.displayName(forCodeFormat: entry.codeFormat),
        ]
        if isRepeat {
            parts.append(NSLocalizedString("Duplicate", comment: "Batch row marker: the value appears earlier in the list"))
        }
        if containsSeparator {
            parts.append(NSLocalizedString("Contains the separator", comment: "Batch row warning: the code contains the batch separator"))
        }
        return parts.joined(separator: ", ")
    }
}

/// Scanner toolbar control that switches Single / Batch for the current scan only.
struct BatchScanModeMenu: View {
    @Binding var selection: ScannerScanMode

    var body: some View {
        Menu {
            Picker("Scan Mode", selection: $selection) {
                ForEach(ScannerScanMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
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
    /// The last deleted row and its position, while Undo is offered.
    private var lastRemoval: (entry: BatchScanEntry, index: Int)?
    /// Earliest uptime for the next scan sound.
    private var nextSoundTime: TimeInterval = 0

    private static let noticeDuration: TimeInterval = 2.0
    private static let undoDuration: TimeInterval = 4.0
    /// Several codes can be added from one camera frame. The sound player
    /// restarts one short clip, so back-to-back plays would merge into a single
    /// beep; spacing them keeps one audible beep (and haptic) per code.
    private static let soundSpacing: TimeInterval = 0.15

    enum AddOutcome {
        case added
        /// Duplicates are skipped and the value is already in the list.
        case skippedDuplicate
        case full
    }

    /// Adds a decoded code, unless the list is full or the code is a duplicate
    /// that is to be skipped.
    @discardableResult
    func add(
        _ result: ScannerCodeResult,
        playScanSound: Bool,
        separator: BatchSeparator,
        skippingDuplicates: Bool
    ) -> AddOutcome {
        let entry = BatchScanEntry(value: result.value, codeFormat: result.codeFormat)
        let isRepeat = collection.contains(value: result.value)
        let count: Int
        switch collection.append(entry, skippingDuplicates: skippingDuplicates) {
        case .added(let newCount):
            count = newCount
        case .full:
            announce(Self.limitMessage)
            return .full
        case .duplicate:
            // Seen, but not added: say so, without the sound of an addition.
            ScanSoundPlayer.shared.playBatchDuplicate()
            show(BatchScanPanelStatus(
                message: String(format: NSLocalizedString("Already in the list: %@", comment: "Batch status when a duplicate code was skipped; %@ is the code"), result.value),
                systemImage: "equal.circle.fill",
                tint: .orange
            ))
            announce(NSLocalizedString("Already in the list.", comment: "VoiceOver when a duplicate batch code was skipped"))
            return .skippedDuplicate
        }
        // The new status replaces the Removed notice and with it the Undo button.
        lastRemoval = nil
        playFeedback(sound: playScanSound)
        var announcement = count == 1
            ? NSLocalizedString("Added, 1 code.", comment: "VoiceOver after the first batch code")
            : String(format: NSLocalizedString("Added, %d codes.", comment: "VoiceOver after a batch code; %d is the count"), count)
        if separator.occurs(in: result.value) {
            // Never blocked or altered, but the joined text will be ambiguous.
            let warning = NSLocalizedString(
                "This code contains the separator.",
                comment: "Batch status when the added code contains the batch separator"
            )
            show(BatchScanPanelStatus(message: warning, systemImage: "exclamationmark.triangle.fill", tint: .orange))
            announcement += " " + warning
        } else if isRepeat {
            show(BatchScanPanelStatus(
                message: String(format: NSLocalizedString("Added again: %@", comment: "Batch status when a value already in the list was added again; %@ is the code"), result.value),
                systemImage: "exclamationmark.circle.fill",
                tint: .orange
            ))
            announcement = String(format: NSLocalizedString("Added again, %d codes.", comment: "VoiceOver after a value already in the list was added again; %d is the count"), count)
        } else {
            show(BatchScanPanelStatus(
                message: String(format: NSLocalizedString("Added %@", comment: "Batch status after a code was added; %@ is the code"), result.value),
                systemImage: "checkmark.circle.fill",
                tint: .green
            ))
        }
        if collection.isFull {
            announcement += " " + Self.limitMessage
        }
        announce(announcement)
        return .added
    }

    /// A company-profile QR never joins a batch; the collected codes stay.
    func ignoreCompanyProfile() {
        let message = NSLocalizedString(
            "Company profile QR codes can't be added to the list.",
            comment: "Batch status when a company profile QR code was scanned"
        )
        show(BatchScanPanelStatus(message: message, systemImage: "exclamationmark.triangle.fill", tint: .orange))
        announce(message)
    }

    /// Removes a row and offers Undo for a few seconds. Returns the value when
    /// no other row has it any more, so the scanner stops treating it as added.
    func remove(id: BatchScanEntry.ID) -> String? {
        guard let removal = collection.remove(id: id) else { return nil }
        lastRemoval = removal
        show(
            BatchScanPanelStatus(
                message: String(format: NSLocalizedString("Removed %@", comment: "Batch status after a row was deleted; %@ is the code"), removal.entry.value),
                systemImage: "minus.circle.fill",
                tint: .red,
                offersUndo: true
            ),
            duration: Self.undoDuration
        )
        announce(
            String(format: NSLocalizedString("Removed %@", comment: "Batch status after a row was deleted; %@ is the code"), removal.entry.spokenValue)
                + " " + BatchScanPanel.countText(collection.count)
        )
        return collection.contains(value: removal.entry.value) ? nil : removal.entry.value
    }

    /// Puts the last deleted row back at its position. Returns the value when
    /// it had left the list, so the scanner treats it as added again.
    func undoRemoval() -> String? {
        guard let removal = lastRemoval else { return nil }
        lastRemoval = nil
        clearNotice()
        let wasInList = collection.contains(value: removal.entry.value)
        guard collection.restore(removal.entry, at: removal.index) else {
            announce(Self.limitMessage)
            return nil
        }
        announce(
            String(format: NSLocalizedString("Restored %@", comment: "VoiceOver after a deleted batch row was restored; %@ is the code"), removal.entry.spokenValue)
                + " " + BatchScanPanel.countText(collection.count)
        )
        return wasInList ? nil : removal.entry.value
    }

    func removeAll() {
        collection.removeAll()
        lastRemoval = nil
        clearNotice()
    }

    var status: BatchScanPanelStatus? {
        if collection.isFull {
            return BatchScanPanelStatus(message: Self.limitMessage, systemImage: "exclamationmark.triangle.fill", tint: .orange, isLimit: true)
        }
        return notice
    }

    /// One success haptic per added code, always; the sound follows the setting.
    private func playFeedback(sound: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        let playAt = max(now, nextSoundTime)
        nextSoundTime = playAt + Self.soundSpacing
        guard playAt > now else {
            ScanSoundPlayer.shared.playBatchAddition(soundEnabled: sound)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (playAt - now)) {
            ScanSoundPlayer.shared.playBatchAddition(soundEnabled: sound)
        }
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
                "Limit of %d codes reached. Finish the list or remove codes to keep scanning.",
                comment: "Batch status when the maximum number of codes is reached; %d is the limit"
            ),
            BatchScanLimit.maximumCodeCount
        )
    }

    private func show(_ status: BatchScanPanelStatus, duration: TimeInterval? = nil) {
        notice = status
        let token = UUID()
        noticeToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + (duration ?? Self.noticeDuration)) { [weak self] in
            guard let self, self.noticeToken == token else { return }
            self.notice = nil
            // Undo is offered only while its notice is visible.
            if status.offersUndo { self.lastRemoval = nil }
        }
    }

    private func clearNotice() {
        notice = nil
        noticeToken = UUID()
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
