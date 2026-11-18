import Contacts
import SwiftUI

struct ImportAllContactsSheet: View {
    enum FilterMode: String, CaseIterable, Identifiable {
        case all
        case withAvatar
        case withoutAvatar

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                NSLocalizedString("All", comment: "")
            case .withAvatar:
                NSLocalizedString("Matched", comment: "")
            case .withoutAvatar:
                NSLocalizedString("Unmatched", comment: "")
            }
        }

        var panelTitle: String {
            switch self {
            case .all:
                NSLocalizedString("All Contacts", comment: "")
            case .withAvatar:
                NSLocalizedString("Contacts With Avatars", comment: "")
            case .withoutAvatar:
                NSLocalizedString("Pending Contacts", comment: "")
            }
        }

        var tint: Color {
            switch self {
            case .all:
                .blue
            case .withAvatar:
                .green
            case .withoutAvatar:
                .orange
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var filterMode: FilterMode

    let contacts: [CNContact]

    init(contacts: [CNContact], initialFilter: FilterMode = .all) {
        self.contacts = contacts
        _filterMode = State(initialValue: initialFilter)
    }

    private var contactsWithAvatars: [CNContact] {
        contacts.filter(importContactHasAvatar)
    }

    private var contactsWithoutAvatars: [CNContact] {
        contacts.filter { importContactHasAvatar($0) == false }
    }

    private var filteredContacts: [CNContact] {
        switch filterMode {
        case .all:
            contacts
        case .withAvatar:
            contactsWithAvatars
        case .withoutAvatar:
            contactsWithoutAvatars
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerPanel
                    filterPicker
                    contactsPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(NSLocalizedString("Contact Queue", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Done", comment: "")) {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerPanel: some View {
        ImportSubpanel(tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                Text(NSLocalizedString("Review Queue", comment: ""))
                    .font(.headline.weight(.semibold))

                Text(NSLocalizedString("Use the segmented filter to compare every contact, contacts that already have avatars, and contacts still waiting for avatar coverage.", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    ImportStatusChip(
                        title: NSLocalizedString("All", comment: ""),
                        value: "\(contacts.count)",
                        systemImage: "person.2.fill",
                        tint: .blue,
                        fillsWidth: true
                    )

                    ImportStatusChip(
                        title: NSLocalizedString("Matched", comment: ""),
                        value: "\(contactsWithAvatars.count)",
                        systemImage: "checkmark.circle.fill",
                        tint: .green,
                        fillsWidth: true
                    )

                    ImportStatusChip(
                        title: NSLocalizedString("Unmatched", comment: ""),
                        value: "\(contactsWithoutAvatars.count)",
                        systemImage: "hourglass",
                        tint: .orange,
                        fillsWidth: true
                    )
                }
            }
        }
    }

    private var filterPicker: some View {
        Picker(NSLocalizedString("Filter", comment: ""), selection: $filterMode) {
            ForEach(FilterMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var contactsPanel: some View {
        ImportSubpanel(tint: filterMode.tint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(filterMode.panelTitle)
                        .font(.headline.weight(.semibold))

                    Spacer()

                    ImportStatusChip(
                        title: NSLocalizedString("Shown", comment: ""),
                        value: "\(filteredContacts.count)",
                        systemImage: "line.3.horizontal.decrease.circle",
                        tint: filterMode.tint,
                        fixedWidth: 100
                    )
                }

                if filteredContacts.isEmpty {
                    ImportEmptyStateView(
                        icon: "person.slash",
                        message: NSLocalizedString("No contacts match this filter.", comment: ""),
                        action: { filterMode = .all },
                        actionLabel: NSLocalizedString("Show All", comment: "")
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredContacts, id: \.identifier) { contact in
                            SimpleImportContactRow(contact: contact)
                        }
                    }
                }
            }
        }
    }
}
