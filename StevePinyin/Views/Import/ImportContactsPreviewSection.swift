import Contacts
import SwiftUI

struct ImportContactsPreviewSection: View {
    var viewModel: ImportAvatarsViewModel
    @Binding var expandedContactIds: Set<String>
    @Binding var showingAllContactsSheet: Bool

    private var contactsWithoutAvatars: [CNContact] {
        viewModel.contacts.filter { importContactHasAvatar($0) == false }
    }

    private var contactsWithAvatarsCount: Int {
        max(viewModel.contacts.count - contactsWithoutAvatars.count, 0)
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if viewModel.isLoadingContacts {
                loadingPanel
            } else if viewModel.contacts.isEmpty {
                ImportEmptyStateView(
                    icon: "person.slash",
                    message: NSLocalizedString("No contacts found or permission denied", comment: ""),
                    action: reloadContacts,
                    actionLabel: NSLocalizedString("Grant Access", comment: "")
                )
            } else {
                previewPanel
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Contact Preview", comment: ""))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("Review the contacts that still need avatars before you commit the import flow.", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if viewModel.contacts.isEmpty == false {
                Button {
                    Task {
                        try? await viewModel.loadContacts(forceReload: true)
                    }
                } label: {
                    Label(NSLocalizedString("Refresh", comment: ""), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .glassCapsule(interactive: true)
            }
        }
    }

    private var loadingPanel: some View {
        ImportSubpanel(tint: .blue) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .frame(width: 52, height: 52)
                        .glassCapsule()

                    ProgressView()
                        .tint(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Loading contacts...", comment: ""))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(NSLocalizedString("Checking your address book and finding contacts that still need avatars.", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var previewPanel: some View {
        ImportSubpanel(tint: contactsWithoutAvatars.isEmpty ? .green : .orange) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            contactsWithoutAvatars.isEmpty
                                ? NSLocalizedString("All Set", comment: "")
                                : NSLocalizedString("Pending Contacts", comment: "")
                        )
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                        Text(
                            contactsWithoutAvatars.isEmpty
                                ? NSLocalizedString("Every loaded contact already has an avatar, so you can switch modes or refresh anytime.", comment: "")
                                : NSLocalizedString("These contacts will be affected by the next import, so you can inspect a few before continuing.", comment: "")
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if contactsWithoutAvatars.isEmpty == false {
                        ImportStatusChip(
                            title: NSLocalizedString("Previewing", comment: ""),
                            value: "\(min(contactsWithoutAvatars.count, 5))",
                            systemImage: "eye.fill",
                            tint: .orange
                        )
                    }
                }

                if contactsWithoutAvatars.isEmpty == false {
                    VStack(spacing: 10) {
                        ForEach(Array(contactsWithoutAvatars.prefix(5)), id: \.identifier) { contact in
                            ExpandableImportContactRow(
                                contact: contact,
                                expandedContactIds: $expandedContactIds
                            )
                        }
                    }

                    if contactsWithoutAvatars.count > 5 {
                        Button {
                            showingAllContactsSheet = true
                        } label: {
                            Label(
                                String(
                                    format: NSLocalizedString("Review All %d Contacts", comment: ""),
                                    contactsWithoutAvatars.count
                                ),
                                systemImage: "list.bullet.rectangle.portrait"
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .glassCapsule(interactive: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)

                        Text(NSLocalizedString("All contacts already have avatars", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.12), Color.clear, Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .glassCard(cornerRadius: 20)
                }
            }
        }
        .sheet(isPresented: $showingAllContactsSheet) {
            ImportAllContactsSheet(
                contacts: viewModel.contacts,
                initialFilter: .withoutAvatar
            )
        }
    }

    private func reloadContacts() {
        Task {
            if await viewModel.requestContactAccess() {
                try? await viewModel.loadContacts(forceReload: true)
            }
        }
    }
}
