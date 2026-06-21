import SwiftUI
import UniformTypeIdentifiers

struct CompanyProfilesView: View {
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var pendingImport: PendingCompanyProfile?
    @State private var alertMessage: String?

    var body: some View {
        List {
            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export Company Profile", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Prepare Export", systemImage: "doc.badge.gearshape")
                    }
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Import Company Profile", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Profiles contain Blip configuration only. Scan history is never included.")
            }

            Section("Included Settings") {
                ProfileIncludedRow(title: "Keyboard language", systemImage: "character.cursor.ibeam")
                ProfileIncludedRow(title: "Enabled keyboard layouts", systemImage: "keyboard")
                ProfileIncludedRow(title: "Opening layout", systemImage: "rectangle.and.pencil.and.ellipsis")
                ProfileIncludedRow(title: "Scan suffix", systemImage: "return")
                ProfileIncludedRow(title: "Scan formats", systemImage: "barcode.viewfinder")
                ProfileIncludedRow(title: "Return target", systemImage: "arrowshape.turn.up.backward")
                ProfileIncludedRow(title: "Sound, flashlight, zoom, and scan area", systemImage: "camera.viewfinder")
            }
        }
        .navigationTitle("Company Profiles")
        .onAppear(perform: prepareExport)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .sheet(item: $pendingImport) { pendingImport in
            CompanyProfilePreview(
                profile: pendingImport.profile,
                onCancel: {
                    self.pendingImport = nil
                },
                onApply: {
                    apply(pendingImport.profile)
                }
            )
        }
        .alert("Company Profile", isPresented: Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func prepareExport() {
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Blip-Company-Profile")
                .appendingPathExtension("blipprofile")
            try BlipCompanyProfile.current.exportData().write(to: url, options: .atomic)
            exportURL = url
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            pendingImport = PendingCompanyProfile(profile: try BlipCompanyProfile.decode(from: data))
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func apply(_ profile: BlipCompanyProfile) {
        do {
            try profile.apply()
            pendingImport = nil
            prepareExport()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct PendingCompanyProfile: Identifiable {
    let id = UUID()
    let profile: BlipCompanyProfile
}

private struct CompanyProfilePreview: View {
    let profile: BlipCompanyProfile
    let onCancel: () -> Void
    let onApply: () -> Void

    private var changes: [BlipCompanyProfileChange] {
        profile.changes()
    }

    var body: some View {
        NavigationStack {
            List {
                if changes.isEmpty {
                    Section {
                        Label("This profile matches the current settings.", systemImage: "checkmark.circle")
                    }
                } else {
                    Section {
                        ForEach(changes) { change in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(change.title)
                                    .font(.subheadline.weight(.semibold))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current: \(change.currentValue)")
                                        .foregroundStyle(.secondary)
                                    Text("Imported: \(change.incomingValue)")
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    } footer: {
                        Text("Review the changes before applying this company profile.")
                    }
                }
            }
            .navigationTitle("Preview Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: onApply)
                }
            }
        }
    }
}

private struct ProfileIncludedRow: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
    }
}
