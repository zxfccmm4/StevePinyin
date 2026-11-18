import SwiftUI

struct ImportConfirmationSheet: View {
    let state: AvatarImportConfirmationState
    var viewModel: ImportAvatarsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    heroPanel
                    detailPanel
                    previewPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        dismiss()
                    }
                    .disabled(isConfirming)
                }
            }
            .safeAreaBar(edge: .bottom) {
                confirmBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var heroPanel: some View {
        ImportSubpanel(tint: .teal) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal.opacity(0.24), Color.blue.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.teal)
                }
                .glassCard(cornerRadius: 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Review Before Writing", comment: ""))
                        .font(.title3.weight(.bold))

                    Text(state.primarySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var detailPanel: some View {
        ImportSubpanel(tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                Text(NSLocalizedString("Import Scope", comment: ""))
                    .font(.headline.weight(.semibold))

                HStack(spacing: 10) {
                    ImportStatusChip(
                        title: NSLocalizedString("Mode", comment: ""),
                        value: state.modeTitle,
                        systemImage: state.importMode.systemImageName,
                        tint: .blue,
                        fillsWidth: true
                    )

                    ImportStatusChip(
                        title: NSLocalizedString("Contacts", comment: ""),
                        value: "\(state.contactCount)",
                        systemImage: "person.2.fill",
                        tint: .teal,
                        fillsWidth: true
                    )
                }

                HStack(spacing: 10) {
                    ImportStatusChip(
                        title: NSLocalizedString("Avatars", comment: ""),
                        value: "\(state.uniqueAvatarCount)",
                        systemImage: "photo.stack",
                        tint: .purple,
                        fillsWidth: true
                    )

                    ImportStatusChip(
                        title: NSLocalizedString("Package", comment: ""),
                        value: state.packageSummary,
                        systemImage: "archivebox.fill",
                        tint: .orange,
                        fillsWidth: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var previewPanel: some View {
        if state.previewNames.isEmpty == false {
            ImportSubpanel(tint: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("First Contacts", comment: ""))
                        .font(.headline.weight(.semibold))

                    ForEach(Array(state.previewNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.purple)
                                .frame(width: 26, height: 26)
                                .background(Color.purple.opacity(0.12), in: Circle())

                            Text(name)
                                .font(.subheadline.weight(.medium))

                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var confirmBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("This will update Contacts", comment: ""))
                    .font(.subheadline.weight(.semibold))

                Text(NSLocalizedString("You can cancel now or confirm the write operation.", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                confirmImport()
            } label: {
                HStack(spacing: 8) {
                    if isConfirming {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }

                    Text(NSLocalizedString("Import", comment: ""))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isConfirming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24)
    }

    private func confirmImport() {
        guard isConfirming == false else { return }
        isConfirming = true

        Task {
            dismiss()
            try? await Task.sleep(nanoseconds: 200_000_000)

            do {
                try await viewModel.importSelectedAvatars()
            } catch {
                viewModel.showError(error.localizedDescription)
            }
        }
    }
}
