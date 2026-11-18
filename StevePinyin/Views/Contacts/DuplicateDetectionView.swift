import SwiftUI

struct DuplicateDetectionView: View {
    let showsDismissButton: Bool
    @State private var duplicateManager = DuplicateContactManager()
    @State private var showDeleteConfirmation = false
    @State private var showDetectionSettings = false
    @Environment(\.dismiss) private var dismiss

    init(showsDismissButton: Bool = false) {
        self.showsDismissButton = showsDismissButton
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                LazyVStack(spacing: 16) {
                    if duplicateManager.isDetecting {
                        DetectionProgressView(progress: duplicateManager.detectionProgress)
                            .transition(.scale.combined(with: .opacity))
                    } else if duplicateManager.duplicateResult.hasCompleted && duplicateManager.duplicateResult.duplicateGroups.isEmpty {
                        heroCard
                        DuplicateEmptyStateCard(
                            systemImage: "checkmark.circle.fill",
                            gradient: [.green, .mint],
                            title: NSLocalizedString("No Duplicates Found", comment: ""),
                            subtitle: NSLocalizedString("Great! Your contacts are clean and organized. No duplicate contacts were found in your address book.", comment: ""),
                            buttonTitle: NSLocalizedString("New Detection", comment: ""),
                            buttonIcon: "arrow.counterclockwise",
                            tint: .green
                        ) {
                            HapticManager.light()
                            duplicateManager.clearResults()
                        }
                    } else if duplicateManager.duplicateResult.duplicateGroups.isEmpty {
                        heroCard
                        DuplicateEmptyStateCard(
                            systemImage: "magnifyingglass.circle.fill",
                            gradient: [.orange, .red],
                            title: NSLocalizedString("Ready to Scan", comment: ""),
                            subtitle: NSLocalizedString("Tap the button below to start scanning for duplicate contacts", comment: ""),
                            buttonTitle: NSLocalizedString("Start Detection", comment: ""),
                            buttonIcon: "magnifyingglass",
                            tint: .orange
                        ) {
                            HapticManager.medium()
                            showDetectionSettings = true
                        }
                    } else {
                        heroCard
                        DuplicateResultsSummaryCard(duplicateManager: duplicateManager)

                        ForEach($duplicateManager.duplicateResult.duplicateGroups) { $group in
                            DuplicateGroupCard(group: $group)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle(NSLocalizedString("Duplicate Detection", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            if !duplicateManager.isDetecting, duplicateManager.duplicateResult.selectedCount > 0 {
                selectionActionBar
            }
        }
        .overlay {
            if duplicateManager.isDeleting {
                DuplicateDeletingOverlay(duplicateManager: duplicateManager)
            }
        }
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if duplicateManager.isDetecting {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        duplicateManager.cancelDetection()
                    }
                } else {
                    HStack(spacing: 12) {
                        if !duplicateManager.duplicateResult.duplicateGroups.isEmpty {
                            Button {
                                HapticManager.light()
                                duplicateManager.clearResults()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                        }
                        Button {
                            HapticManager.light()
                            showDetectionSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDetectionSettings) {
            DetectionSettingsSheet(duplicateManager: duplicateManager)
        }
        .task {
            if let groups = IntentRouter.shared.consumePendingDuplicateGroups() {
                duplicateManager.applyDetectedGroups(groups)
            }
        }
        .confirmationDialog(
            NSLocalizedString("Delete Selected Duplicates", comment: ""),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                Task {
                    let summary = await duplicateManager.deleteSelectedDuplicates()
                    if summary.failedCount > 0 {
                        HapticManager.error()
                    } else if summary.deletedCount > 0 {
                        HapticManager.success()
                    }
                }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("This will permanently delete the selected duplicate contacts. This action cannot be undone.", comment: ""))
        }
        .alert(NSLocalizedString("Error", comment: ""), isPresented: $duplicateManager.showingAlert) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
        } message: {
            Text(duplicateManager.alertMessage)
        }
    }

    private var heroCard: some View {
        FeatureHeroCard(
            eyebrow: NSLocalizedString("Cleanup Studio", comment: ""),
            title: NSLocalizedString("Duplicate Detection", comment: ""),
            subtitle: NSLocalizedString("Find and manage duplicate contacts in your address book", comment: ""),
            symbol: "person.2.badge.gearshape.fill",
            gradient: [.orange, .red],
            metrics: [
                FeatureHeroMetric(
                    title: NSLocalizedString("Engine", comment: ""),
                    value: NSLocalizedString("Smart Match", comment: ""),
                    symbol: "wand.and.stars",
                    tint: .orange
                ),
                FeatureHeroMetric(
                    title: NSLocalizedString("Goal", comment: ""),
                    value: NSLocalizedString("Cleanup", comment: ""),
                    symbol: "trash.slash.fill",
                    tint: .red
                ),
            ]
        )
    }

    private var selectionActionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(duplicateManager.duplicateResult.selectedCount) \(NSLocalizedString("Selected", comment: ""))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text(NSLocalizedString("Keep First, Select Others", comment: ""))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    HapticManager.selection()
                    duplicateManager.duplicateResult.selectAllWithMode(.selectOthersToDelete)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)

                Button(role: .destructive) {
                    HapticManager.warning()
                    showDeleteConfirmation = true
                } label: {
                    Label(
                        "\(NSLocalizedString("Delete", comment: "")) (\(duplicateManager.duplicateResult.selectedCount))",
                        systemImage: "trash.fill"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 22, tint: .red)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}

private struct DuplicateEmptyStateCard: View {
    let systemImage: String
    let gradient: [Color]
    let title: String
    let subtitle: String
    let buttonTitle: String
    let buttonIcon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        GlassSectionCard(cornerRadius: 24, padding: 28, tint: tint) {
            VStack(spacing: 22) {
                Image(systemName: systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: action) {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(tint)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        DuplicateDetectionView()
    }
}
