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
    @State private var copiedItemID: ScanHistoryItem.ID?

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
                                    isCopied: copiedItemID == item.id,
                                    onCopy: {
                                        copy(item)
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

    private func copy(_ item: ScanHistoryItem) {
        UIPasteboard.general.string = item.value
        copiedItemID = item.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard copiedItemID == item.id else { return }
            copiedItemID = nil
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

private struct HistoryRow: View {
    let item: ScanHistoryItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(item.value)
                    .font(.title3.monospaced())
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onCopy()
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isCopied ? "Copied" : "Copy")

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

            Text(metadataLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if isCopied {
                Text("Copied")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }

    private var metadataLine: String {
        var parts = [
            HistoryDateFormatter.string(from: item.scannedAt),
            item.displayCodeFormat,
            item.source.title,
        ]

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

        return "Successful real scans will appear here."
    }
}
