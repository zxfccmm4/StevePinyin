import Contacts
import Foundation

struct AvatarDeletionSelectionUseCase {
    func toggleSelection(
        for contact: CNContact,
        currentSelection: Set<String>
    ) -> Set<String> {
        var selection = currentSelection
        let identifier = contact.stableIdentifier

        if selection.contains(identifier) {
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }

        return selection
    }

    func selectAll(contacts: [CNContact]) -> Set<String> {
        Set(contacts.map(\.stableIdentifier))
    }

    func deselectAll() -> Set<String> {
        []
    }

    func isSelected(
        _ contact: CNContact,
        currentSelection: Set<String>
    ) -> Bool {
        currentSelection.contains(contact.stableIdentifier)
    }
}
