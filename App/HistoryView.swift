import SwiftUI
import UIKit

struct HistoryView: View {
    private let screenshotItems: [ScanHistoryItem]?

    @AppStorage(SharedKeyboardState.Keys.scanHistoryRetention, store: SharedKeyboardState.appStorageDefaults)
    private var retentionRawValue = SharedKeyboardState.scanHistoryRetention.rawValue

    @State private var items: [ScanHistoryItem] = []
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @State private var showingMailError = false
    @State private var copiedTarget: HistoryCopyTarget?

    init(screenshotItems: [ScanHistoryItem]? = nil) {
        self.screenshotItems = screenshotItems
    }

    private var retention: ScanHistoryRetention {
        ScanHistoryRetention(rawValue: retentionRawValue) ?? .thirtyDays
    }

    private var filteredItems: [ScanHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }

        return items.filter { item in
            [
                item.value,
                item.codeFormat ?? "",
                item.source.title,
                item.returnTarget?.title ?? "",
                item.insertionStatus.title,
            ]
            .contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    HistoryEmptyState(isSearching: !searchText.isEmpty, retention: retention)
                } else {
                    List {
                        Section {
                            ForEach(filteredItems) { item in
                                HistoryRow(
                                    item: item,
                                    copiedTarget: copiedTarget?.itemID == item.id ? copiedTarget : nil,
                                    onCopy: { codeIndex in
                                        copy(item, codeIndex: codeIndex)
                                    },
                                    onReport: {
                                        report(item)
                                    }
                                )
                                .swipeActions {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } footer: {
                            Text("History stays on this device. Feedback emails are only created when you choose to send them.")
                        }
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search scans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear History")
                    .disabled(items.isEmpty)
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: retentionRawValue) { _ in
                refresh()
            }
            .confirmationDialog("Clear all scan history?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    ScanHistoryStore.clear()
                    refresh()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes local scan history from this device.")
            }
            .alert("Mail is not available", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Install or configure Mail, or copy the scan and send it with another email app.")
            }
        }
    }

    private func refresh() {
        if let screenshotItems {
            items = screenshotItems.sorted { $0.scannedAt > $1.scannedAt }
        } else {
            items = ScanHistoryStore.applyRetention()
        }
    }

    /// Copies the whole entry, or one code of a batch when `codeIndex` is given.
    private func copy(_ item: ScanHistoryItem, codeIndex: Int?) {
        if let codeIndex, let codes = item.batchCodes, codes.indices.contains(codeIndex) {
            UIPasteboard.general.string = codes[codeIndex].value
        } else {
            UIPasteboard.general.string = item.value
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let target = HistoryCopyTarget(itemID: item.id, codeIndex: codeIndex)
        copiedTarget = target

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard copiedTarget == target else { return }
            copiedTarget = nil
        }
    }

    private func delete(_ item: ScanHistoryItem) {
        ScanHistoryStore.delete(item)
        refresh()
    }

    private func report(_ item: ScanHistoryItem) {
        guard let url = SupportEmail.scanIssueURL(for: item) else {
            showingMailError = true
            return
        }

        SupportEmail.open(url) {
            showingMailError = true
        }
    }
}

/// What the user last copied: a whole entry, or one code of a batch entry.
private struct HistoryCopyTarget: Equatable {
    let itemID: ScanHistoryItem.ID
    let codeIndex: Int?
}

private struct HistoryRow: View {
    /// A longer batch shows this many codes until it is expanded.
    private static let collapsedCodeCount = 3
    /// Values longer than this are shown in the smaller code font.
    private static let largeValueLength = 18

    let item: ScanHistoryItem
    /// Set while something of this entry was just copied.
    let copiedTarget: HistoryCopyTarget?
    /// Nil copies the whole entry, an index one code of a batch.
    let onCopy: (Int?) -> Void
    let onReport: () -> Void

    @State private var isExpanded = false

    private var isWholeEntryCopied: Bool {
        copiedTarget != nil && copiedTarget?.codeIndex == nil
    }

    var body: some View {
        if let codes = item.batchCodes {
            batchBody(codes)
        } else {
            singleBody
        }
    }

    private var singleBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Short codes stay large; long payloads such as links get the
                // smaller size so more of them fits. Always one line, cut off at
                // the end: copying still takes the whole value.
                Text(item.value)
                    .font(item.value.count > Self.largeValueLength ? .body.monospaced() : .title3.monospaced())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onCopy(nil)
                } label: {
                    Image(systemName: isWholeEntryCopied ? "checkmark" : "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isWholeEntryCopied ? Color.green : Color.accentColor)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isWholeEntryCopied ? "Copied" : "Copy")

                moreMenu
            }

            // The confirmation takes the place of the details, so the row
            // keeps its height while it shows.
            Text(isWholeEntryCopied ? NSLocalizedString("Copied", comment: "History row after copying") : metadataLine)
                .font(isWholeEntryCopied ? .footnote.weight(.semibold) : .footnote)
                .foregroundStyle(isWholeEntryCopied ? Color.green : Color.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { onCopy(nil) }
    }

    /// A batch is one entry: a header that copies the whole joined text, and
    /// the codes as their own lines, each of which copies just that code.
    private func batchBody(_ codes: [ScanHistoryBatchCode]) -> some View {
        let canCollapse = codes.count > Self.collapsedCodeCount + 1
        let visibleCount = canCollapse && !isExpanded ? Self.collapsedCodeCount : codes.count
        // A batch of one format names it once below; a mixed one per code.
        let showsFormats = item.codeFormat == nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: ScannerScanMode.batch.systemImage)
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                    Text(String(format: NSLocalizedString("%d codes", comment: "Batch list count, plural"), codes.count))
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onCopy(nil)
                } label: {
                    Text(isWholeEntryCopied ? LocalizedStringKey("Copied") : LocalizedStringKey("Copy All"))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(isWholeEntryCopied ? Color.green : Color.accentColor)

                moreMenu
            }

            VStack(spacing: 0) {
                ForEach(0..<visibleCount, id: \.self) { index in
                    if index > 0 {
                        Divider()
                    }
                    batchCodeLine(codes[index], index: index, showsFormat: showsFormats)
                }
            }
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if canCollapse {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(
                        isExpanded
                            ? NSLocalizedString("Show Less", comment: "Collapse the codes of a batch in History")
                            : String(
                                format: NSLocalizedString("Show all %d codes", comment: "Expand the codes of a batch in History; %d is the count"),
                                codes.count
                            )
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }

            Text(metadataLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        // The line below the row starts at the row's edge, not after the icon.
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in dimensions[.leading] }
    }

    private func batchCodeLine(_ code: ScanHistoryBatchCode, index: Int, showsFormat: Bool) -> some View {
        let isCopied = copiedTarget?.codeIndex == index

        return Button {
            onCopy(index)
        } label: {
            HStack(spacing: 10) {
                // Explicit colours: inside a button, `.secondary` follows the tint.
                Text(verbatim: "\(index + 1)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    // One line per code, cut off at the end; tapping copies all of it.
                    Text(verbatim: code.value)
                        .font(.body.monospaced())
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if showsFormat {
                        Text(verbatim: ScanHistoryItem.displayName(forCodeFormat: code.codeFormat))
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isCopied ? Color.green : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityHint(isCopied ? LocalizedStringKey("Copied") : LocalizedStringKey("Copy"))
    }

    private var moreMenu: some View {
        Menu {
            Button {
                onReport()
            } label: {
                Label("Report Issue", systemImage: "envelope")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More")
    }

    private var metadataLine: String {
        var parts = [HistoryDateFormatter.string(from: item.scannedAt)]

        // A batch that mixes formats names the format on each code instead.
        if !item.isBatch || item.codeFormat != nil {
            parts.append(item.displayCodeFormat)
        }
        parts.append(item.source.title)

        if let returnTarget = item.returnTarget {
            parts.append(returnTarget.title)
        }

        return parts.joined(separator: " • ")
    }
}

private enum HistoryDateFormatter {
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()

        if Bundle.main.preferredLocalizations.first == "de" {
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        } else {
            formatter.locale = .autoupdatingCurrent
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }

        return formatter
    }()
}

private struct HistoryEmptyState: View {
    let isSearching: Bool
    let retention: ScanHistoryRetention

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "clock.arrow.circlepath")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(isSearching ? "No matching scans" : "No scan history")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var message: LocalizedStringKey {
        if isSearching {
            return "Try a different search term."
        }

        if retention == .off {
            return "History is off. Turn it on in Settings if you want Blip to keep local scan history."
        }

        return "Your scans will appear here."
    }
}
