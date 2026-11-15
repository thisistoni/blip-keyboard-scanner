import SwiftUI
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins
import UIKit

struct CompanyProfilesView: View {
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var pendingImport: PendingCompanyProfile?
    @State private var alertMessage: String?
    @State private var profileQRCode: CompanyProfileQRCode?

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

                Button {
                    prepareQRCode()
                } label: {
                    Label("Show QR Code", systemImage: "qrcode")
                }
            } footer: {
                Text("Profiles contain Blip configuration only. Scan history is never included.")
            }

            Section("Included Settings") {
                ProfileIncludedRow(title: "Keyboard language", systemImage: "character.cursor.ibeam")
                ProfileIncludedRow(title: "Enabled keyboard layouts", systemImage: "keyboard")
                ProfileIncludedRow(title: "Opening layout", systemImage: "rectangle.and.pencil.and.ellipsis")
                ProfileIncludedRow(title: "Scan suffix", systemImage: "return")
                ProfileIncludedRow(title: "Insert Scans Automatically", systemImage: "text.insert")
                ProfileIncludedRow(title: "Scan formats", systemImage: "barcode.viewfinder")
                ProfileIncludedRow(title: "Return Target", systemImage: "arrowshape.turn.up.backward")
                ProfileIncludedRow(title: "Sound, flashlight, zoom, and scan area", systemImage: "camera.viewfinder")
                ProfileIncludedRow(title: "Keyboard Appearance", systemImage: "paintpalette")
                ProfileIncludedRow(title: "Key Clicks", systemImage: "speaker.wave.2")
                ProfileIncludedRow(title: "Key Haptics", systemImage: "hand.tap")
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
        .sheet(item: $profileQRCode) { code in
            CompanyProfileQRCodeView(code: code)
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

    private func prepareQRCode() {
        do {
            profileQRCode = try CompanyProfileQRCode(profile: .current)
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

struct PendingCompanyProfile: Identifiable {
    let id = UUID()
    let profile: BlipCompanyProfile
}

struct CompanyProfilePreview: View {
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
                                Text(LocalizedStringKey(change.title))
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

private struct CompanyProfileQRCode: Identifiable {
    let id = UUID()
    let image: UIImage
    let profile: BlipCompanyProfile

    init(profile: BlipCompanyProfile) throws {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = try BlipCompanyProfileQR.encode(profile)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { throw BlipCompanyProfileQRError.cannotRender }
        // Bound matrix density in addition to byte count; preserve a four-module quiet zone.
        guard output.extent.width <= 129 else { throw BlipCompanyProfileQRError.tooLarge }
        let quietZone = output.extent.insetBy(dx: -4, dy: -4)
        let white = CIImage(color: .white).cropped(to: quietZone)
        let printable = output.composited(over: white).transformed(by: .init(scaleX: 8, y: 8))
        guard let cgImage = CIContext().createCGImage(printable, from: printable.extent) else {
            throw BlipCompanyProfileQRError.cannotRender
        }
        image = UIImage(cgImage: cgImage)
        self.profile = profile
    }
}

private struct CompanyProfileQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let code: CompanyProfileQRCode

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Image(uiImage: code.image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 280)
                        .accessibilityLabel("Company Profile QR Code")

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Included Settings")
                            .font(.headline)
                            .padding(.bottom, 12)

                        ForEach(code.profile.includedSettings) { setting in
                            LabeledContent {
                                Text(setting.value)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.trailing)
                                    .textSelection(.enabled)
                            } label: {
                                Text(LocalizedStringKey(setting.title))
                            }
                            .padding(.vertical, 12)
                            Divider()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Share Company Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
