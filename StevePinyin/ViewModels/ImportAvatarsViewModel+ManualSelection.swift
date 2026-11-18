import Contacts
import Foundation

extension ImportAvatarsViewModel {
    func avatarRecommendations(forContact contact: CNContact) -> [AvatarRecommendation] {
        avatarRecommendationsByContactID[contact.stableIdentifier] ?? []
    }

    func bestAvatarRecommendation(forContact contact: CNContact) -> AvatarRecommendation? {
        avatarRecommendations(forContact: contact).first
    }

    func applyBestAvatarRecommendation(forContact contact: CNContact) {
        guard let recommendation = bestAvatarRecommendation(forContact: contact) else { return }
        setAvatar(recommendation.icon, forContact: contact)
    }

    func setAvatar(_ avatar: AvatarIcon, forContact contact: CNContact) {
        applyManualSelectionState(
            ManualAvatarSelectionUseCase().setAvatar(
                avatar,
                for: contact,
                currentSelections: manualSelections,
                contactsNeedingSelection: contactsNeedingSelection
            )
        )
    }

    func removeManualSelection(forContact contact: CNContact) {
        applyManualSelectionState(
            ManualAvatarSelectionUseCase().removeSelection(
                for: contact,
                currentSelections: manualSelections,
                contactsNeedingSelection: contactsNeedingSelection
            )
        )
    }

    func isManualSelectionComplete() -> Bool {
        ManualAvatarSelectionUseCase().isSelectionComplete(
            contactsNeedingSelection: contactsNeedingSelection,
            manualSelections: manualSelections
        )
    }

    func getSelectedAvatar(forContact contact: CNContact) -> AvatarIcon? {
        manualSelections[contact.stableIdentifier]
    }

    func hasManualSelection(forContact contact: CNContact) -> Bool {
        manualSelections[contact.stableIdentifier] != nil
    }

    func clearManualSelections() {
        applyManualSelectionState(ManualAvatarSelectionUseCase().clearSelections())
        contactsNeedingSelection.removeAll()
        avatarRecommendationsByContactID.removeAll()
    }

    func refreshAvatarRecommendations() {
        guard contactsNeedingSelection.isEmpty == false else {
            avatarRecommendationsByContactID.removeAll()
            return
        }

        guard matchPreviewIcons.isEmpty == false else {
            avatarRecommendationsByContactID.removeAll()
            return
        }

        do {
            avatarRecommendationsByContactID = try avatarRecommendationsUseCase
                .execute(
                    contacts: contactsNeedingSelection,
                    icons: matchPreviewIcons,
                    limitPerContact: 3
                )
                .recommendationsByContactID
        } catch {
            avatarRecommendationsByContactID.removeAll()
        }
    }

    private func applyManualSelectionState(_ state: ManualAvatarSelectionState) {
        manualSelections = state.manualSelections
        matchedContacts = state.matchedContacts
    }
}
