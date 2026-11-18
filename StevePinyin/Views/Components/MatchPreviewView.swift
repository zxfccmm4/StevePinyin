import Contacts
import SwiftUI

private struct MatchPreviewPair: Identifiable {
    var id: String { contact.stableIdentifier }
    var contact: CNContact
    var icon: Icon
}

struct MatchPreviewView: View {
    let matches: [(CNContact, Icon)]
    let availableIcons: [Icon]
    let onConfirm: ([(CNContact, Icon)]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var matchedPairs: [MatchPreviewPair]
    @State private var searchText = ""

    init(
        matches: [(CNContact, Icon)],
        availableIcons: [Icon],
        onConfirm: @escaping ([(CNContact, Icon)]) -> Void
    ) {
        self.matches = matches
        self.availableIcons = availableIcons
        self.onConfirm = onConfirm
        _matchedPairs = State(
            initialValue: matches.map { MatchPreviewPair(contact: $0.0, icon: $0.1) }
        )
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedPairs: [MatchPreviewPair] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return matchedPairs }
        return matchedPairs.filter { pair in
            let fullName = "\(pair.contact.familyName)\(pair.contact.givenName)"
            let org = pair.contact.isKeyAvailable(CNContactOrganizationNameKey) ? pair.contact.organizationName : ""
            return fullName.localizedStandardContains(query) || org.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryHeader

                List {
                    ForEach(displayedPairs) { pair in
                        MatchPreviewRow(
                            contact: pair.contact,
                            selectedIcon: pair.icon,
                            availableIcons: availableIcons,
                            rank: rank(for: pair.id)
                        ) { newIcon in
                            updateIcon(newIcon, for: pair.id)
                        }
                    }
                    .reorderable()
                    .onMove(perform: isFiltering ? nil : moveMatches)
                }
                .reorderContainer(for: MatchPreviewPair.self, isEnabled: !isFiltering) { difference in
                    applyReorder(difference)
                }
                .searchable(text: $searchText, prompt: NSLocalizedString("Search contacts", comment: ""))
                .searchToolbarBehavior(.minimize)
                .overlay {
                    if displayedPairs.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("No matching contacts", comment: ""),
                            systemImage: "magnifyingglass",
                            description: Text(NSLocalizedString("Try another name or organization.", comment: ""))
                        )
                    }
                }
            }
            .navigationTitle(String(localized: "preview_matches"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        dismiss()
                    }
                }

                if !isFiltering {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Confirm", comment: "")) {
                        let confirmed = matchedPairs.map { ($0.contact, $0.icon) }
                        dismiss()
                        onConfirm(confirmed)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(matchedPairs.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var summaryHeader: some View {
        HStack(spacing: 10) {
            GlassMetricBadge(
                title: NSLocalizedString("Contacts", comment: ""),
                value: "\(matchedPairs.count)",
                systemImage: "person.2.fill",
                tint: .blue
            )
            GlassMetricBadge(
                title: NSLocalizedString("Avatars", comment: ""),
                value: "\(Set(matchedPairs.map(\.icon)).count)",
                systemImage: "photo.stack",
                tint: .purple
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func rank(for id: String) -> Int? {
        matchedPairs.firstIndex(where: { $0.id == id }).map { $0 + 1 }
    }

    private func updateIcon(_ icon: Icon, for id: String) {
        guard let index = matchedPairs.firstIndex(where: { $0.id == id }) else { return }
        matchedPairs[index].icon = icon
    }

    private func moveMatches(from source: IndexSet, to destination: Int) {
        matchedPairs.move(fromOffsets: source, toOffset: destination)
    }

    private func applyReorder(_ difference: ReorderDifference<String, ReorderableSingleCollectionIdentifier>) {
        let movingIDs = Set(difference.sources)
        let movingItems = matchedPairs.filter { movingIDs.contains($0.id) }
        guard !movingItems.isEmpty else { return }

        var remaining = matchedPairs.filter { !movingIDs.contains($0.id) }
        switch difference.destination.position {
        case .before(let targetID):
            let insertIndex = remaining.firstIndex(where: { $0.id == targetID }) ?? remaining.endIndex
            remaining.insert(contentsOf: movingItems, at: insertIndex)
        case .end:
            remaining.append(contentsOf: movingItems)
        @unknown default:
            remaining.append(contentsOf: movingItems)
        }
        matchedPairs = remaining
    }
}

struct MatchPreviewRow: View {
    let contact: CNContact
    let selectedIcon: Icon
    let availableIcons: [Icon]
    let rank: Int?
    let onIconSelect: (Icon) -> Void

    private var displayName: String {
        let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        if !fullName.isEmpty { return fullName }
        if contact.isKeyAvailable(CNContactOrganizationNameKey), !contact.organizationName.isEmpty {
            return contact.organizationName
        }
        return NSLocalizedString("Unknown Contact", comment: "")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(rank.map(String.init) ?? "-")
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text(String(format: String(localized: "current_avatar"), selectedIcon.name))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AvatarThumbnailView(source: .icon(selectedIcon), size: 38)

            Menu {
                ForEach(availableIcons) { icon in
                    Button {
                        onIconSelect(icon)
                    } label: {
                        HStack {
                            Text(icon.name)
                            if selectedIcon.id == icon.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
