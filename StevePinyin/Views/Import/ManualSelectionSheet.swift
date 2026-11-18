import Contacts
import SwiftUI

private struct AvatarPickerItem: Identifiable {
    let id = UUID()
    let contact: CNContact
    let icons: [AvatarIcon]
    let recommendations: [AvatarRecommendation]
}

struct ManualSelectionSheet: View {
    @Bindable var viewModel: ImportAvatarsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var avatarPickerItem: AvatarPickerItem?

    private var allSelectedIcons: [AvatarIcon] {
        if !viewModel.selectedPackages.isEmpty {
            return viewModel.selectedPackages.flatMap(\.icons)
        } else if let package = viewModel.currentPackage {
            return package.icons
        }
        return []
    }

    private var completedContacts: [CNContact] {
        viewModel.contactsNeedingSelection.filter { viewModel.hasManualSelection(forContact: $0) }
    }

    private var pendingContacts: [CNContact] {
        viewModel.contactsNeedingSelection.filter { !viewModel.hasManualSelection(forContact: $0) }
    }

    private var progress: Double {
        guard !viewModel.contactsNeedingSelection.isEmpty else { return 0 }
        return Double(viewModel.manualSelections.count) / Double(viewModel.contactsNeedingSelection.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 18) {
                        headerCard

                        if viewModel.contactsNeedingSelection.isEmpty {
                            ImportEmptyStateView(
                                icon: "person.slash",
                                message: NSLocalizedString("No contacts without avatars found", comment: ""),
                                action: { dismiss() },
                                actionLabel: NSLocalizedString("Done", comment: "")
                            )
                        } else {
                            if let nextPending = pendingContacts.first {
                                ContactSpotlightCard(
                                    contact: nextPending,
                                    iconCount: allSelectedIcons.count,
                                    recommendation: viewModel.bestAvatarRecommendation(forContact: nextPending),
                                    onApplyAllRecommendations: applyAllAIRecommendations,
                                    action: { openPicker(for: nextPending) }
                                )
                            }

                            if !pendingContacts.isEmpty {
                                contactsGroupCard(
                                    title: NSLocalizedString("Awaiting Selection", comment: ""),
                                    tint: .orange,
                                    contacts: pendingContacts
                                )
                            }

                            if !completedContacts.isEmpty {
                                contactsGroupCard(
                                    title: NSLocalizedString("Selected", comment: ""),
                                    tint: .green,
                                    contacts: completedContacts
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(NSLocalizedString("Select Avatars", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Close", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "")) { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
            .sheet(item: $avatarPickerItem) { item in
                MultiPackageAvatarPickerSheet(
                    contact: item.contact,
                    icons: item.icons,
                    recommendations: item.recommendations,
                    onSelect: { avatar in
                        viewModel.setAvatar(avatar, forContact: item.contact)
                        avatarPickerItem = nil
                    }
                )
            }
            .safeAreaBar(edge: .bottom) {
                footerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
    }

    private var headerCard: some View {
        GlassSectionCard(cornerRadius: 24, tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Manual Assignment", comment: ""))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text(NSLocalizedString("Choose avatars contact by contact when you want more control than single or sequential import.", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)
                }

                ProgressView(value: progress)
                    .tint(.orange)

                HStack(spacing: 8) {
                    GlassMetricBadge(title: NSLocalizedString("Selected", comment: ""), value: "\(completedContacts.count)", systemImage: "checkmark.circle.fill", tint: .green)
                    GlassMetricBadge(title: NSLocalizedString("Remaining", comment: ""), value: "\(pendingContacts.count)", systemImage: "hourglass", tint: .orange)
                    GlassMetricBadge(title: NSLocalizedString("Library", comment: ""), value: "\(allSelectedIcons.count)", systemImage: "photo.stack", tint: .blue)
                }
            }
        }
    }

    private func contactsGroupCard(title: String, tint: Color, contacts: [CNContact]) -> some View {
        GlassSectionCard(cornerRadius: 24, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                    Text("\(contacts.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.15), in: Capsule())
                }

                LazyVStack(spacing: 10) {
                    ForEach(contacts, id: \.stableIdentifier) { contact in
                        ContactSelectionRow(
                            contact: contact,
                            selectedAvatar: viewModel.getSelectedAvatar(forContact: contact),
                            recommendation: viewModel.bestAvatarRecommendation(forContact: contact),
                            onSelectAvatar: { openPicker(for: contact) },
                            onApplyRecommendation: { viewModel.applyBestAvatarRecommendation(forContact: contact) },
                            onRemoveAvatar: { viewModel.removeManualSelection(forContact: contact) }
                        )
                    }
                }
            }
        }
    }

    private var footerBar: some View {
        GlassSectionCard(cornerRadius: 22, padding: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pendingContacts.isEmpty ? NSLocalizedString("All Set", comment: "") : NSLocalizedString("Awaiting Selection", comment: ""))
                        .font(.subheadline.weight(.semibold))
                    Text("\(viewModel.manualSelections.count) / \(viewModel.contactsNeedingSelection.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(NSLocalizedString("Done", comment: "")) {
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(pendingContacts.isEmpty ? .green : .blue)
            }
        }
    }

    private func applyAllAIRecommendations() {
        for contact in pendingContacts {
            viewModel.applyBestAvatarRecommendation(forContact: contact)
        }
    }

    private func openPicker(for contact: CNContact) {
        let icons = allSelectedIcons
        guard !icons.isEmpty else { return }
        avatarPickerItem = AvatarPickerItem(
            contact: contact,
            icons: icons,
            recommendations: viewModel.avatarRecommendations(forContact: contact)
        )
    }
}

#Preview("Manual Selection") {
    ManualSelectionSheet(viewModel: manualSelectionPreviewViewModel())
}
