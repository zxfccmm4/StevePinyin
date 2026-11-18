import Contacts
import SwiftUI

struct DeleteAvatarsSheet: View {
    @Bindable var viewModel: ImportAvatarsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""

    private var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return viewModel.contactsWithAvatars
        }

        return viewModel.contactsWithAvatars.filter { contact in
            contact.deleteSheetDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 14) {
                    LazyVStack(spacing: 14) {
                        headerPanel

                        if viewModel.isLoadingContacts {
                            loadingPanel
                        } else if viewModel.contactsWithAvatars.isEmpty {
                            emptyPanel
                        } else {
                            ForEach(filteredContacts, id: \.stableIdentifier) { contact in
                                DeleteContactRow(
                                    contact: contact,
                                    isSelected: viewModel.isDeleteSelected(for: contact),
                                    onToggle: {
                                        HapticManager.selection()
                                        viewModel.toggleDeleteSelection(for: contact)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(NSLocalizedString("Delete Avatars", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    toolbarCancelButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    toolbarDeleteButton
                }
            }
            .confirmationDialog(
                NSLocalizedString("Confirm Delete", comment: ""),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                    Task {
                        await viewModel.deleteSelectedContactAvatars()
                        dismiss()
                    }
                }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(deleteConfirmationMessage)
            }
            .overlay {
                if viewModel.isLoading {
                    deleteProgressOverlay
                }
            }
            .task {
                await viewModel.loadContactsWithAvatars()
            }
        }
    }

    private var toolbarCancelButton: some View {
        Button(NSLocalizedString("Cancel", comment: "")) {
            viewModel.deselectAllForDeletion()
            dismiss()
        }
        .buttonStyle(.glass)
    }

    private var toolbarDeleteButton: some View {
        Button(NSLocalizedString("Delete", comment: "")) {
            showingDeleteConfirmation = true
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
        .disabled(viewModel.deleteSelections.isEmpty)
    }

    private var headerPanel: some View {
        ImportSubpanel(tint: .red) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Avatar Cleanup", comment: ""))
                            .font(.headline.weight(.semibold))

                        Text(NSLocalizedString("Choose which contacts should lose their current avatars before applying a new look.", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        if viewModel.deleteSelections.count == viewModel.contactsWithAvatars.count {
                            viewModel.deselectAllForDeletion()
                        } else {
                            viewModel.selectAllForDeletion()
                        }
                    } label: {
                        Label(
                            viewModel.deleteSelections.count == viewModel.contactsWithAvatars.count
                                ? NSLocalizedString("Deselect", comment: "")
                                : NSLocalizedString("Select All", comment: ""),
                            systemImage: viewModel.deleteSelections.count == viewModel.contactsWithAvatars.count
                                ? "minus.circle"
                                : "checkmark.circle"
                        )
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .glassCapsule(interactive: true)
                }

                HStack(spacing: 10) {
                    ImportStatusChip(
                        title: NSLocalizedString("Selected", comment: ""),
                        value: "\(viewModel.deleteSelections.count)",
                        systemImage: "checkmark.circle.fill",
                        tint: .red
                    )

                    ImportStatusChip(
                        title: NSLocalizedString("Available", comment: ""),
                        value: "\(viewModel.contactsWithAvatars.count)",
                        systemImage: "person.crop.circle.fill",
                        tint: .blue
                    )
                }

                if viewModel.contactsWithAvatars.isEmpty == false {
                    ImportGlassSearchField(
                        text: $searchText,
                        prompt: NSLocalizedString("Search contacts", comment: ""),
                        tint: .red
                    )
                }
            }
        }
    }


    private var loadingPanel: some View {
        ImportSubpanel(tint: .red) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 52, height: 52)
                        .glassCapsule()

                    ProgressView()
                        .tint(.red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Loading contacts...", comment: ""))
                        .font(.headline.weight(.semibold))

                    Text(NSLocalizedString("Scanning your contacts for existing avatars that can be removed.", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyPanel: some View {
        ImportEmptyStateView(
            icon: "person.crop.circle.badge.checkmark",
            message: NSLocalizedString("None of your contacts have avatars to delete.", comment: ""),
            action: { dismiss() },
            actionLabel: NSLocalizedString("Done", comment: "")
        )
    }

    private var deleteProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()

            GlassSectionCard(cornerRadius: 28, padding: 32, tint: .red) {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.red)

                    VStack(spacing: 8) {
                        Text(NSLocalizedString("Deleting Avatars...", comment: ""))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                        if viewModel.totalContactsToProcess > 0 {
                            Text(
                                String(
                                    format: NSLocalizedString("Contact %d of %d", comment: ""),
                                    viewModel.currentProcessingIndex,
                                    viewModel.totalContactsToProcess
                                )
                            )
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 300)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }

    private var deleteConfirmationMessage: String {
        String(
            format: NSLocalizedString(
                "Are you sure you want to delete avatars for %d contacts? This action cannot be undone.",
                comment: ""
            ),
            viewModel.deleteSelections.count
        )
    }
}

struct DeleteContactRow: View {
    let contact: CNContact
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                onToggle()
            }
        } label: {
            HStack(spacing: 14) {
                avatarView
                contactInfo
                Spacer()
                selectionView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 20, tint: isSelected ? .red : nil, interactive: true)
    }

    private var avatarView: some View {
        AvatarThumbnailView(
            source: .contact(contact, fallbackText: contact.deleteSheetDisplayName),
            size: 52,
            tint: .red
        )
        .overlay {
            if isSelected {
                Circle()
                    .strokeBorder(.red, lineWidth: 2.5)
            }
        }
    }

    private var contactInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.deleteSheetDisplayName)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(isSelected ? .red : .primary)
                .lineLimit(1)

            if let secondary = contact.deleteSheetSecondaryLine {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Label(NSLocalizedString("Has Avatar", comment: ""), systemImage: "photo.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
        }
    }

    private var selectionView: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? .red : Color(.systemGray4), lineWidth: 2)
                .frame(width: 28, height: 28)

            if isSelected {
                Circle()
                    .fill(.red)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

private extension CNContact {
    var deleteSheetDisplayName: String {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let hasOrganization = isKeyAvailable(CNContactOrganizationNameKey) && organizationName.isEmpty == false

        if hasOrganization && name.isEmpty {
            return organizationName
        }

        if name.isEmpty == false {
            return name
        }

        if hasOrganization {
            return organizationName
        }

        return NSLocalizedString("Unknown Contact", comment: "")
    }

    var deleteSheetSecondaryLine: String? {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let hasOrganization = isKeyAvailable(CNContactOrganizationNameKey) && organizationName.isEmpty == false

        if hasOrganization && name.isEmpty == false {
            return organizationName
        }

        return nil
    }

    var deleteSheetInitials: String {
        let first = givenName.first.map(String.init) ?? ""
        let last = familyName.first.map(String.init) ?? ""

        if first.isEmpty == false || last.isEmpty == false {
            return "\(first)\(last)".uppercased()
        }

        if isKeyAvailable(CNContactOrganizationNameKey) && organizationName.isEmpty == false {
            return String(organizationName.prefix(2)).uppercased()
        }

        return "?"
    }
}

#Preview {
    DeleteAvatarsSheet(viewModel: ImportAvatarsViewModel())
}
