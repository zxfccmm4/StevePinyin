import Contacts
import SwiftUI

struct ContactSpotlightCard: View {
    let contact: CNContact
    let iconCount: Int
    let recommendation: AvatarRecommendation?
    var onApplyAllRecommendations: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        GlassSectionCard(cornerRadius: 24, tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    AvatarThumbnailView(
                        source: .contact(contact, fallbackText: contact.manualSheetDisplayName),
                        size: 50,
                        tint: .blue
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(contact.manualSheetDisplayName)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        if let secondary = contact.manualSheetSecondaryLine {
                            Text(secondary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let recommendation {
                        HStack(spacing: 6) {
                            AvatarThumbnailView(source: .icon(recommendation.icon), size: 28)
                            Text("AI \(recommendation.score)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.purple)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: 10) {
                    Button(action: action) {
                        Label(NSLocalizedString("Avatar Picker", comment: ""), systemImage: "hand.tap.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)

                    if let onApplyAllRecommendations {
                        Button(action: onApplyAllRecommendations) {
                            Label("智能填满", systemImage: "apple.intelligence")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
    }
}

struct ContactSelectionRow: View {
    let contact: CNContact
    let selectedAvatar: AvatarIcon?
    let recommendation: AvatarRecommendation?
    let onSelectAvatar: () -> Void
    let onApplyRecommendation: () -> Void
    let onRemoveAvatar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarThumbnailView(
                    source: .contact(contact, fallbackText: contact.manualSheetDisplayName),
                    size: 44,
                    tint: selectedAvatar == nil ? .orange : .green
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.manualSheetDisplayName)
                        .font(.subheadline.weight(.semibold))
                    if let org = contact.manualSheetSecondaryLine {
                        Text(org)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let selectedAvatar {
                    AvatarThumbnailView(source: .icon(selectedAvatar), size: 36)
                }
            }

            if let selectedAvatar {
                HStack(spacing: 8) {
                    Text(selectedAvatar.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(NSLocalizedString("Change", comment: ""), action: onSelectAvatar)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glass)
                    Button(NSLocalizedString("Remove", comment: ""), role: .destructive, action: onRemoveAvatar)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glass)
                }
            } else {
                HStack(spacing: 8) {
                    if let recommendation {
                        Button(action: onApplyRecommendation) {
                            HStack(spacing: 6) {
                                AvatarThumbnailView(source: .icon(recommendation.icon), size: 22)
                                Text("推荐：\(recommendation.icon.name)")
                                    .lineLimit(1)
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                    }

                    Spacer(minLength: 0)

                    Button(NSLocalizedString("Select Avatar", comment: ""), action: onSelectAvatar)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension CNContact {
    var manualSheetDisplayName: String {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let hasOrganization = isKeyAvailable(CNContactOrganizationNameKey) && !organizationName.isEmpty
        if hasOrganization { return organizationName }
        if !name.isEmpty { return name }
        return NSLocalizedString("Unknown Contact", comment: "")
    }

    var manualSheetSecondaryLine: String? {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let hasOrganization = isKeyAvailable(CNContactOrganizationNameKey) && !organizationName.isEmpty
        guard hasOrganization, !name.isEmpty else { return nil }
        return name
    }
}

@MainActor
func manualSelectionPreviewViewModel() -> ImportAvatarsViewModel {
    let packageManager = AvatarPackageManagementViewModel()
    let viewModel = ImportAvatarsViewModel(packageManager: packageManager)
    let icons = [
        AvatarIcon(name: "Monogram", url: "system:person.crop.circle.fill"),
        AvatarIcon(name: "Bolt", url: "system:bolt.circle.fill"),
        AvatarIcon(name: "Leaf", url: "system:leaf.circle.fill"),
    ]
    let package = AvatarPackage(
        id: "preview-pack",
        name: "Preview Pack",
        description: "Preview avatars for manual assignment",
        icons: icons,
        isDefault: false,
        createdAt: .now
    )
    let contacts = [
        previewContact(givenName: "Avery", familyName: "Lin", organizationName: "Northwind"),
        previewContact(givenName: "Mika", familyName: "Sato"),
        previewContact(givenName: "Jordan", familyName: "Chen", organizationName: "Orbital Labs"),
    ]
    packageManager.selectedPackages = [package]
    packageManager.currentPackage = package
    packageManager.selectedIcons = icons
    packageManager.sequentialIcons = icons
    viewModel.contactsNeedingSelection = contacts
    viewModel.manualSelections = [contacts[0].stableIdentifier: icons[0]]
    viewModel.matchedContacts = [(contacts[0], icons[0])]
    viewModel.matchPreviewIcons = icons
    viewModel.refreshAvatarRecommendations()
    return viewModel
}

func previewContact(givenName: String, familyName: String, organizationName: String = "") -> CNContact {
    let contact = CNMutableContact()
    contact.givenName = givenName
    contact.familyName = familyName
    contact.organizationName = organizationName
    return contact.copy() as? CNContact ?? contact
}
