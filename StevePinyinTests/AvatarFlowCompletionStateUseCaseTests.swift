import Testing
@testable import StevePinyin

struct AvatarFlowCompletionStateUseCaseTests {
    private let sut = AvatarFlowCompletionStateUseCase()

    @Test("Import completion resets progress and preserves delete selection state")
    func importCompletionResetsProgressAndPreservesDeleteSelection() {
        let state = sut.makeImportCompletionState(
            summaryMessage: "Import finished",
            importErrors: ["first failure"]
        )

        #expect(state.isLoading == false)
        #expect(state.isLoadingContacts == nil)
        #expect(state.downloadProgress == 1.0)
        #expect(state.currentProcessingContact.isEmpty)
        #expect(state.currentProcessingIndex == 0)
        #expect(state.totalContactsToProcess == 0)
        #expect(state.alertMessage == "Import finished")
        #expect(state.showingAlert)
        #expect(state.importErrors == ["first failure"])
        #expect(state.shouldClearDeleteSelections == false)
        #expect(state.shouldClearMatchedContacts)
        #expect(state.shouldInvalidateLoadedContacts)
    }

    @Test("Import failure resets progress state without clearing selections")
    func importFailureKeepsExistingSelectionState() {
        let state = sut.makeImportFailureState(alertMessage: "Import failed")

        #expect(state.isLoading == false)
        #expect(state.isLoadingContacts == nil)
        #expect(state.downloadProgress == 0)
        #expect(state.currentProcessingContact.isEmpty)
        #expect(state.currentProcessingIndex == 0)
        #expect(state.totalContactsToProcess == 0)
        #expect(state.alertMessage == "Import failed")
        #expect(state.showingAlert)
        #expect(state.importErrors.isEmpty)
        #expect(state.shouldClearDeleteSelections == false)
        #expect(state.shouldClearMatchedContacts == false)
        #expect(state.shouldInvalidateLoadedContacts == false)
    }

    @Test("Delete completion clears stale import errors and delete selections")
    func deleteCompletionClearsDeleteSpecificState() {
        let state = sut.makeDeleteCompletionState(alertMessage: "Delete finished")

        #expect(state.isLoading == false)
        #expect(state.isLoadingContacts == nil)
        #expect(state.downloadProgress == 0)
        #expect(state.currentProcessingContact.isEmpty)
        #expect(state.currentProcessingIndex == 0)
        #expect(state.totalContactsToProcess == 0)
        #expect(state.alertMessage == "Delete finished")
        #expect(state.showingAlert)
        #expect(state.importErrors.isEmpty)
        #expect(state.shouldClearDeleteSelections)
        #expect(state.shouldClearMatchedContacts)
        #expect(state.shouldInvalidateLoadedContacts)
    }

    @Test("Delete failure preserves retry state while clearing stale import errors")
    func deleteFailurePreservesRetryState() {
        let state = sut.makeDeleteFailureState(alertMessage: "Delete failed")

        #expect(state.isLoading == false)
        #expect(state.isLoadingContacts == nil)
        #expect(state.downloadProgress == 0)
        #expect(state.currentProcessingContact.isEmpty)
        #expect(state.currentProcessingIndex == 0)
        #expect(state.totalContactsToProcess == 0)
        #expect(state.alertMessage == "Delete failed")
        #expect(state.showingAlert)
        #expect(state.importErrors.isEmpty)
        #expect(state.shouldClearDeleteSelections == false)
        #expect(state.shouldClearMatchedContacts == false)
        #expect(state.shouldInvalidateLoadedContacts == false)
    }

    @Test("Delete contacts loading failure only closes the loading state")
    func deleteContactsLoadingFailureStopsContactsSpinner() {
        let state = sut.makeDeleteContactsLoadingFailureState(alertMessage: "Load failed")

        #expect(state.isLoading == false)
        #expect(state.isLoadingContacts == false)
        #expect(state.downloadProgress == 0)
        #expect(state.currentProcessingContact.isEmpty)
        #expect(state.currentProcessingIndex == 0)
        #expect(state.totalContactsToProcess == 0)
        #expect(state.alertMessage == "Load failed")
        #expect(state.showingAlert)
        #expect(state.importErrors.isEmpty)
        #expect(state.shouldClearDeleteSelections == false)
        #expect(state.shouldClearMatchedContacts == false)
        #expect(state.shouldInvalidateLoadedContacts == false)
    }
}
