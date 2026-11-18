import Contacts
import Foundation

struct AvatarMatchPreviewState {
    let matchedContacts: [(CNContact, Icon)]
    let contactsNeedingSelection: [CNContact]
    let availableIcons: [Icon]
    let shouldShowMatchPreview: Bool
    let alertMessage: String?
}

struct BuildAvatarMatchPreviewStateUseCase {
    func execute(
        result: AvatarMatchingResult,
        importMode: AvatarImportMode,
        selectedPackage: IconPackage?,
        selectedUniformIcon: Icon?
    ) -> AvatarMatchPreviewState {
        let matchedContacts = result.matches
        let shouldShowMatchPreview = matchedContacts.isEmpty == false

        return AvatarMatchPreviewState(
            matchedContacts: matchedContacts,
            contactsNeedingSelection: result.contactsNeedingSelection,
            availableIcons: resolveAvailableIcons(
                result: result,
                selectedPackage: selectedPackage,
                selectedUniformIcon: selectedUniformIcon
            ),
            shouldShowMatchPreview: shouldShowMatchPreview,
            alertMessage: resolveAlertMessage(
                importMode: importMode,
                shouldShowMatchPreview: shouldShowMatchPreview
            )
        )
    }

    private func resolveAvailableIcons(
        result: AvatarMatchingResult,
        selectedPackage: IconPackage?,
        selectedUniformIcon: Icon?
    ) -> [Icon] {
        if let package = selectedPackage, package.icons.isEmpty == false {
            return package.icons
        }

        if let selectedUniformIcon {
            return [selectedUniformIcon]
        }

        var seen = Set<String>()
        return result.matches.compactMap { _, icon in
            guard seen.insert(icon.id).inserted else { return nil }
            return icon
        }
    }

    private func resolveAlertMessage(
        importMode: AvatarImportMode,
        shouldShowMatchPreview: Bool
    ) -> String? {
        guard shouldShowMatchPreview == false else {
            return nil
        }

        switch importMode {
        case .manual:
            return nil
        case .single, .sequential:
            return NSLocalizedString("No contacts found needing avatar update", comment: "")
        }
    }
}
