import Foundation

struct AvatarFlowCompletionState {
    let isLoading: Bool
    let isLoadingContacts: Bool?
    let downloadProgress: Double
    let currentProcessingContact: String
    let currentProcessingIndex: Int
    let totalContactsToProcess: Int
    let alertMessage: String
    let showingAlert: Bool
    let importErrors: [String]
    let shouldClearDeleteSelections: Bool
    let shouldClearMatchedContacts: Bool
    let shouldInvalidateLoadedContacts: Bool
}

struct AvatarFlowCompletionStateUseCase {
    func makeImportCompletionState(
        summaryMessage: String,
        importErrors: [String]
    ) -> AvatarFlowCompletionState {
        makeState(
            alertMessage: summaryMessage,
            downloadProgress: 1.0,
            importErrors: importErrors,
            shouldClearMatchedContacts: true,
            shouldInvalidateLoadedContacts: true
        )
    }

    func makeImportFailureState(alertMessage: String) -> AvatarFlowCompletionState {
        makeState(alertMessage: alertMessage)
    }

    func makeDeleteCompletionState(alertMessage: String) -> AvatarFlowCompletionState {
        makeState(
            alertMessage: alertMessage,
            shouldClearDeleteSelections: true,
            shouldClearMatchedContacts: true,
            shouldInvalidateLoadedContacts: true
        )
    }

    func makeDeleteFailureState(alertMessage: String) -> AvatarFlowCompletionState {
        makeState(alertMessage: alertMessage)
    }

    func makeDeleteContactsLoadingFailureState(alertMessage: String) -> AvatarFlowCompletionState {
        makeState(
            alertMessage: alertMessage,
            isLoadingContacts: false
        )
    }

    private func makeState(
        alertMessage: String,
        isLoading: Bool = false,
        isLoadingContacts: Bool? = nil,
        downloadProgress: Double = 0,
        importErrors: [String] = [],
        shouldClearDeleteSelections: Bool = false,
        shouldClearMatchedContacts: Bool = false,
        shouldInvalidateLoadedContacts: Bool = false
    ) -> AvatarFlowCompletionState {
        AvatarFlowCompletionState(
            isLoading: isLoading,
            isLoadingContacts: isLoadingContacts,
            downloadProgress: downloadProgress,
            currentProcessingContact: "",
            currentProcessingIndex: 0,
            totalContactsToProcess: 0,
            alertMessage: alertMessage,
            showingAlert: true,
            importErrors: importErrors,
            shouldClearDeleteSelections: shouldClearDeleteSelections,
            shouldClearMatchedContacts: shouldClearMatchedContacts,
            shouldInvalidateLoadedContacts: shouldInvalidateLoadedContacts
        )
    }
}
