import Contacts
import SwiftUI
import UIKit

struct ContactListView: View {
    @Binding var processedContacts: [ContactResult]
    @Binding var searchText: String

    private var processedContactIndices: [String: Int] {
        Dictionary(uniqueKeysWithValues: processedContacts.enumerated().map { ($1.id, $0) })
    }

    var filteredContacts: [ContactResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return processedContacts }
        return processedContacts.filter { $0.matchesSearchQuery(query) }
    }

    var body: some View {
        List {
            ForEach(filteredContacts) { contact in
                if let index = processedContactIndices[contact.id] {
                    NavigationLink {
                        ContactDetailView(
                            contact: $processedContacts[index],
                            processedContacts: $processedContacts
                        )
                    } label: {
                        ContactRow(contact: contact)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            let valueToCopy = contact.company.isEmpty ? contact.pinyin : contact.companyPinyin
                            UIPasteboard.general.string = valueToCopy
                            HapticManager.success()
                        } label: {
                            Label(NSLocalizedString("Copy Pinyin", comment: ""), systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AmbientGlassBackdrop())
        .swipeActionsContainer()
        .navigationTitle(NSLocalizedString("Contact List", comment: ""))
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: NSLocalizedString("Search contacts, companies or pinyin", comment: "")
        )
        .searchToolbarBehavior(.minimize)
        .overlay {
            if filteredContacts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

private struct ContactRow: View {
    let contact: ContactResult

    private var primaryTitle: String {
        !contact.name.isEmpty ? contact.name : contact.company
    }

    private var primaryPinyin: String {
        !contact.pinyin.isEmpty ? contact.pinyin : contact.companyPinyin
    }

    var body: some View {
        HStack(spacing: 14) {
            AvatarThumbnailView(
                source: .contact(contact.contact, fallbackText: primaryTitle),
                size: 44,
                tint: .blue
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryTitle)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                if !primaryPinyin.isEmpty {
                    Text(primaryPinyin)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.blue)
                }

                if !contact.name.isEmpty, !contact.company.isEmpty {
                    Text(contact.company)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
