import Contacts
import SwiftUI

struct ExpandableImportContactRow: View {
    let contact: CNContact
    @Binding var expandedContactIds: Set<String>

    private var isExpanded: Bool {
        expandedContactIds.contains(contact.identifier)
    }

    var body: some View {
        ImportContactCard {
            ImportContactRowSummary(
                contact: contact,
                showsMissingAvatarBadge: contact.hasAvatarImage == false
            ) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded {
                        expandedContactIds.remove(contact.identifier)
                    } else {
                        expandedContactIds.insert(contact.identifier)
                    }
                }
            }

            if isExpanded {
                ImportExpandableContactDetails(contact: contact)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .transition(.opacity)
    }
}

struct SimpleImportContactRow: View {
    let contact: CNContact

    var body: some View {
        ImportContactCard {
            ImportContactRowSummary(
                contact: contact,
                showsMissingAvatarBadge: contact.hasAvatarImage == false
            ) {
                EmptyView()
            }
        }
    }
}

private struct ImportContactCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.cyan.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .glassCard(cornerRadius: 20)
    }
}

private struct ImportContactRowSummary<Trailing: View>: View {
    let contact: CNContact
    let showsMissingAvatarBadge: Bool
    let trailing: Trailing

    init(
        contact: CNContact,
        showsMissingAvatarBadge: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.contact = contact
        self.showsMissingAvatarBadge = showsMissingAvatarBadge
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 16) {
            importContactAvatar()
                .transition(.scale.combined(with: .opacity))

            importContactIdentity(for: contact)

            Spacer()

            if showsMissingAvatarBadge {
                importMissingAvatarBadge()
                    .transition(.scale.combined(with: .opacity))
            }

            trailing
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

private func importContactAvatar() -> some View {
    ZStack {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 40, height: 40)

        Image(systemName: "person.crop.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}

private func importContactIdentity(for contact: CNContact) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(contact.importDisplayName)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(contact.importDisplayNameIsFallback ? .secondary : .primary)
            .transition(.opacity)

        if let secondaryName = contact.importSecondaryName {
            Text(secondaryName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }
}

private func importMissingAvatarBadge() -> some View {
    Text(NSLocalizedString("No Avatar", comment: ""))
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.orange)
        }
}

func importContactHasAvatar(_ contact: CNContact) -> Bool {
    contact.hasAvatarImage
}

private extension CNContact {
    var importDisplayName: String {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let hasOrganization = isKeyAvailable(CNContactOrganizationNameKey) &&
            organizationName.isEmpty == false

        if hasOrganization {
            return organizationName
        }

        if name.isEmpty == false {
            return name
        }

        return NSLocalizedString("Unknown Contact", comment: "")
    }

    var importDisplayNameIsFallback: Bool {
        importDisplayName == NSLocalizedString("Unknown Contact", comment: "")
    }

    var importSecondaryName: String? {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let hasOrganization = isKeyAvailable(CNContactOrganizationNameKey) &&
            organizationName.isEmpty == false

        guard hasOrganization, name.isEmpty == false else {
            return nil
        }

        return name
    }
}
