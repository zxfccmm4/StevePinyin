import Contacts
import Foundation

extension ImportAvatarsViewModel {
    // MARK: - Contact Avatar Management
    func deleteAllContactAvatars() async {
        isLoading = true

        do {
            let result = try await deleteAvatarFlowUseCase.deleteAllContactAvatars(
                keysToFetch: avatarManagementContactKeys
            )
            await handleDeleteFlowCompletion(with: result)
        } catch {
            handleDeleteFlowFailure(message: deleteAvatarFlowUseCase.makeDeleteErrorMessage(error))
        }
    }

    // MARK: - Manual Delete Selection Methods
    func loadContactsWithAvatars() async {
        isLoadingContacts = true

        do {
            contactsWithAvatars = try await deleteAvatarFlowUseCase.loadContactsWithAvatars(
                keysToFetch: contactsFetchKeys
            )
            isLoadingContacts = false
        } catch {
            handleDeleteContactsLoadingFailure(
                message: deleteAvatarFlowUseCase.makeLoadContactsErrorMessage(error)
            )
        }
    }

    func toggleDeleteSelection(for contact: CNContact) {
        deleteSelections = deletionSelectionUseCase.toggleSelection(
            for: contact,
            currentSelection: deleteSelections
        )
    }

    func selectAllForDeletion() {
        deleteSelections = deletionSelectionUseCase.selectAll(contacts: contactsWithAvatars)
    }

    func deselectAllForDeletion() {
        deleteSelections = deletionSelectionUseCase.deselectAll()
    }

    func isDeleteSelected(for contact: CNContact) -> Bool {
        deletionSelectionUseCase.isSelected(contact, currentSelection: deleteSelections)
    }

    func deleteSelectedContactAvatars() async {
        guard deleteSelections.isEmpty == false else { return }

        isLoading = true
        totalContactsToProcess = deleteSelections.count
        currentProcessingIndex = 0

        do {
            let result = try await deleteAvatarFlowUseCase.deleteSelectedContactAvatars(
                identifiers: Array(deleteSelections),
                keysToFetch: avatarManagementContactKeys,
                progressHandler: { [weak self] index in
                    self?.currentProcessingIndex = index
                }
            )
            await handleDeleteFlowCompletion(with: result, reloadContactsWithAvatars: true)
        } catch {
            handleDeleteFlowFailure(message: deleteAvatarFlowUseCase.makeDeleteErrorMessage(error))
        }
    }

    func applyFlowCompletionState(_ state: AvatarFlowCompletionState) {
        isLoading = state.isLoading
        if let isLoadingContacts = state.isLoadingContacts {
            self.isLoadingContacts = isLoadingContacts
        }
        downloadProgress = state.downloadProgress
        currentProcessingContact = state.currentProcessingContact
        currentProcessingIndex = state.currentProcessingIndex
        totalContactsToProcess = state.totalContactsToProcess
        alertMessage = state.alertMessage
        showingAlert = state.showingAlert
        importErrors = state.importErrors

        if state.shouldClearDeleteSelections {
            deleteSelections = deletionSelectionUseCase.deselectAll()
        }

        if state.shouldClearMatchedContacts {
            matchedContacts.removeAll()
            matchPreviewIcons.removeAll()
            showingMatchPreview = false
        }

        if state.shouldInvalidateLoadedContacts {
            invalidateLoadedContactsCache()
        }
    }

    private func handleDeleteFlowCompletion(
        with result: DeleteAvatarFlowResult,
        reloadContactsWithAvatars: Bool = false
    ) async {
        let completionState = flowCompletionUseCase.makeDeleteCompletionState(
            alertMessage: result.alertMessage
        )
        applyFlowCompletionState(completionState)
        AvatarThumbnailStore.shared.bumpContactAvatarRevision()
        try? await loadContacts(forceReload: true)
        if reloadContactsWithAvatars {
            await loadContactsWithAvatars()
        }
    }

    private func handleDeleteFlowFailure(message: String) {
        let failureState = flowCompletionUseCase.makeDeleteFailureState(alertMessage: message)
        applyFlowCompletionState(failureState)
    }

    private func handleDeleteContactsLoadingFailure(message: String) {
        let failureState = flowCompletionUseCase.makeDeleteContactsLoadingFailureState(
            alertMessage: message
        )
        applyFlowCompletionState(failureState)
    }
}
