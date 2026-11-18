import Contacts
import Foundation

enum AvatarMatchingUseCaseError: LocalizedError, Equatable {
    case noContactsNeedUpdate
    case noIconSelected
    case noIconsAvailable

    var errorDescription: String? {
        switch self {
        case .noContactsNeedUpdate:
            return NSLocalizedString("No contacts found needing avatar update", comment: "")
        case .noIconSelected:
            return NSLocalizedString("Please select an avatar first", comment: "")
        case .noIconsAvailable:
            return NSLocalizedString("No avatars available in package", comment: "")
        }
    }
}

struct AvatarMatchingResult {
    let matches: [(CNContact, Icon)]
    let contactsNeedingSelection: [CNContact]
}

struct PrepareAvatarMatchesUseCase {
    func execute(
        contacts: [CNContact],
        importMode: AvatarImportMode,
        selectedPackage: IconPackage?,
        selectedUniformIcon: Icon?,
        manualSelections: [String: AvatarIcon]
    ) throws -> AvatarMatchingResult {
        try PerformanceMonitor.trackAvatarMatching(
            contactCount: contacts.count,
            mode: importMode
        ) {
            try performExecute(
                contacts: contacts,
                importMode: importMode,
                selectedPackage: selectedPackage,
                selectedUniformIcon: selectedUniformIcon,
                manualSelections: manualSelections
            )
        }
    }

    private func performExecute(
        contacts: [CNContact],
        importMode: AvatarImportMode,
        selectedPackage: IconPackage?,
        selectedUniformIcon: Icon?,
        manualSelections: [String: AvatarIcon]
    ) throws -> AvatarMatchingResult {
        let contactsWithoutAvatar = contacts.filter { !$0.hasAvatarImage }

        guard !contactsWithoutAvatar.isEmpty else {
            throw AvatarMatchingUseCaseError.noContactsNeedUpdate
        }

        switch importMode {
        case .single:
            guard let icon = selectedUniformIcon else {
                throw AvatarMatchingUseCaseError.noIconSelected
            }
            return AvatarMatchingResult(
                matches: contactsWithoutAvatar.map { ($0, icon) },
                contactsNeedingSelection: []
            )

        case .sequential:
            guard let package = selectedPackage, !package.icons.isEmpty else {
                throw AvatarMatchingUseCaseError.noIconsAvailable
            }
            let matches = contactsWithoutAvatar.enumerated().map { index, contact in
                (contact, package.icons[index % package.icons.count])
            }
            return AvatarMatchingResult(
                matches: matches,
                contactsNeedingSelection: []
            )

        case .manual:
            let matches = contactsWithoutAvatar.compactMap { contact -> (CNContact, Icon)? in
                guard let selectedIcon = manualSelections[contact.stableIdentifier] else {
                    return nil
                }
                return (contact, selectedIcon)
            }
            return AvatarMatchingResult(
                matches: matches,
                contactsNeedingSelection: contactsWithoutAvatar
            )
        }
    }
}
