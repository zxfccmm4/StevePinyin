import Contacts
import Foundation

struct ManualAvatarSelectionState {
    let manualSelections: [String: AvatarIcon]
    let matchedContacts: [(CNContact, Icon)]
}

struct ManualAvatarSelectionUseCase {
    func setAvatar(
        _ avatar: AvatarIcon,
        for contact: CNContact,
        currentSelections: [String: AvatarIcon],
        contactsNeedingSelection: [CNContact]
    ) -> ManualAvatarSelectionState {
        var selections = currentSelections
        selections[contact.stableIdentifier] = avatar
        return makeState(
            contactsNeedingSelection: contactsNeedingSelection,
            manualSelections: selections
        )
    }

    func removeSelection(
        for contact: CNContact,
        currentSelections: [String: AvatarIcon],
        contactsNeedingSelection: [CNContact]
    ) -> ManualAvatarSelectionState {
        var selections = currentSelections
        selections.removeValue(forKey: contact.stableIdentifier)
        return makeState(
            contactsNeedingSelection: contactsNeedingSelection,
            manualSelections: selections
        )
    }

    func clearSelections() -> ManualAvatarSelectionState {
        ManualAvatarSelectionState(
            manualSelections: [:],
            matchedContacts: []
        )
    }

    func isSelectionComplete(
        contactsNeedingSelection: [CNContact],
        manualSelections: [String: AvatarIcon]
    ) -> Bool {
        contactsNeedingSelection.count == manualSelections.count
    }

    func matchedContacts(
        contactsNeedingSelection: [CNContact],
        manualSelections: [String: AvatarIcon]
    ) -> [(CNContact, Icon)] {
        contactsNeedingSelection.compactMap { contact in
            guard let selectedIcon = manualSelections[contact.stableIdentifier] else {
                return nil
            }
            return (contact, selectedIcon)
        }
    }

    private func makeState(
        contactsNeedingSelection: [CNContact],
        manualSelections: [String: AvatarIcon]
    ) -> ManualAvatarSelectionState {
        ManualAvatarSelectionState(
            manualSelections: manualSelections,
            matchedContacts: matchedContacts(
                contactsNeedingSelection: contactsNeedingSelection,
                manualSelections: manualSelections
            )
        )
    }
}
