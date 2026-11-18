import SwiftUI
import UIKit

struct ImportPackageView: View {
    @Bindable var viewModel: ImportAvatarsViewModel
    @Binding var isPresented: Bool
    var onImportSuccess: ((String) -> Void)?

    @State private var urlString = ""
    @State private var isDownloading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var trimmedURLString: String {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidURL: Bool {
        guard !trimmedURLString.isEmpty else { return false }
        let candidate = (trimmedURLString.lowercased().hasPrefix("http://") || trimmedURLString.lowercased().hasPrefix("https://"))
            ? trimmedURLString
            : "https://" + trimmedURLString
        guard let url = URL(string: candidate), let host = url.host() else { return false }
        return host.contains(".") || host == "localhost"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    VStack(spacing: 18) {
                        FeatureHeroCard(
                            eyebrow: NSLocalizedString("Package Library", comment: ""),
                            title: NSLocalizedString("Import Avatar Package", comment: ""),
                            subtitle: NSLocalizedString("Add custom avatar packages from URL", comment: ""),
                            symbol: isDownloading ? "arrow.down.circle.fill" : "square.and.arrow.down.fill",
                            gradient: [.blue, .indigo],
                            metrics: [
                                FeatureHeroMetric(
                                    title: NSLocalizedString("saved_avatar_packages", comment: ""),
                                    value: "\(viewModel.savedPackages.count)",
                                    symbol: "folder.fill",
                                    tint: .blue
                                ),
                            ]
                        )

                        urlInputCard
                        statusCard
                        instructionsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .background(AmbientGlassBackdrop())
            .safeAreaBar(edge: .bottom) {
                bottomActionBar
            }
            .navigationTitle(NSLocalizedString("Import Package", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        isPresented = false
                    }
                    .disabled(isDownloading)
                }
            }
            .alert(NSLocalizedString("Error", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("OK", comment: "")) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var urlInputCard: some View {
        GlassSectionCard(cornerRadius: 24, tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(NSLocalizedString("Package URL", comment: ""), systemImage: "link.circle.fill")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !pasted.isEmpty {
                            HapticManager.light()
                            urlString = pasted
                        }
                    } label: {
                        Label(NSLocalizedString("Paste URL", comment: ""), systemImage: "doc.on.clipboard")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                }

                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)

                    TextField(
                        NSLocalizedString("https://example.com/package.json", comment: ""),
                        text: $urlString
                    )
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.subheadline, design: .monospaced))
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await importPackage() }
                    }

                    if !urlString.isEmpty {
                        Button {
                            urlString = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 14)

                if !trimmedURLString.isEmpty {
                    Label(
                        isValidURL
                            ? NSLocalizedString("Valid URL format", comment: "")
                            : NSLocalizedString("Please enter a valid URL", comment: ""),
                        systemImage: isValidURL ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(isValidURL ? .green : .orange)
                }
            }
        }
    }

    private var statusCard: some View {
        GlassSectionCard(cornerRadius: 24, tint: isDownloading ? .indigo : nil) {
            if isDownloading {
                HStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Importing...", comment: ""))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Text(NSLocalizedString("Please wait while we fetch your package...", comment: ""))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .glassCapsule(tint: .blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("Ready to Use", comment: ""))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text(NSLocalizedString("Package will be available immediately", comment: ""))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var instructionsCard: some View {
        GlassSectionCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(NSLocalizedString("How It Works", comment: ""))
                    .font(.system(.headline, design: .rounded, weight: .bold))

                instructionRow(
                    icon: "1.circle.fill",
                    title: NSLocalizedString("Enter package URL", comment: ""),
                    subtitle: NSLocalizedString("Paste a package link and pull it straight into your active library.", comment: ""),
                    tint: .blue
                )
                instructionRow(
                    icon: "2.circle.fill",
                    title: NSLocalizedString("Tap Import to download the package", comment: ""),
                    subtitle: NSLocalizedString("We'll fetch and validate the package", comment: ""),
                    tint: .purple
                )
                instructionRow(
                    icon: "3.circle.fill",
                    title: NSLocalizedString("Ready to Use", comment: ""),
                    subtitle: NSLocalizedString("Package will be available immediately", comment: ""),
                    tint: .green
                )
            }
        }
    }

    private var bottomActionBar: some View {
        GlassEffectContainer(spacing: 12) {
            Button {
                Task { await importPackage() }
            } label: {
                HStack(spacing: 10) {
                    if isDownloading {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    Text(
                        isDownloading
                            ? NSLocalizedString("Importing...", comment: "")
                            : NSLocalizedString("Import Package", comment: "")
                    )
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(!isValidURL || isDownloading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func instructionRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func importPackage() async {
        guard isValidURL, !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }

        do {
            let packageId = try await viewModel.importPackage(from: trimmedURLString)
            HapticManager.success()
            onImportSuccess?(packageId)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            HapticManager.error()
        }
    }
}
