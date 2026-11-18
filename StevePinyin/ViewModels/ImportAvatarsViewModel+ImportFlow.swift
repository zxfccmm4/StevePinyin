import Contacts
import Foundation
import SwiftUI

extension ImportAvatarsViewModel {
    // MARK: - Avatar Import
    func startMatching() {
        if let validationMessage = validationUseCase.validate(
            importMode: importMode,
            selectedPackage: selectedPackage,
            selectedUniformIcon: selectedUniformIcon
        ) {
            handleImportFlowFailure(message: validationMessage)
            return
        }

        Task {
            isMatching = true
            defer { isMatching = false }

            do {
                try await loadContacts(forceReload: true)

                let result = try matchingUseCase.execute(
                    contacts: contacts,
                    importMode: importMode,
                    selectedPackage: selectedPackage,
                    selectedUniformIcon: selectedUniformIcon,
                    manualSelections: manualSelections
                )
                let previewState = matchPreviewStateUseCase.execute(
                    result: result,
                    importMode: importMode,
                    selectedPackage: selectedPackage,
                    selectedUniformIcon: selectedUniformIcon
                )

                applyMatchPreviewState(previewState)

                if let alertMessage = previewState.alertMessage {
                    presentAlert(alertMessage)
                }
            } catch {
                if let localizedError = error as? LocalizedError,
                   let description = localizedError.errorDescription {
                    handleImportFlowFailure(message: description)
                } else {
                    handleImportFlowFailure(
                        message: String(
                            format: NSLocalizedString("Failed to load contacts: %@", comment: ""),
                            error.localizedDescription
                        )
                    )
                }
            }
        }
    }

    func importSelectedAvatars() async throws {
        guard matchedContacts.isEmpty == false else { return }
        importConfirmationState = nil

        isLoading = true
        downloadProgress = 0
        totalContactsToProcess = matchedContacts.count
        currentProcessingIndex = 0
        importErrors = []

        let total = matchedContacts.count
        let taskID = batchCoordinator.beginTask(
            title: NSLocalizedString("Import Avatars", comment: ""),
            subtitle: NSLocalizedString("Preparing avatars...", comment: ""),
            totalCount: total
        )
        defer { batchCoordinator.finishTask(id: taskID) }

        let importResult = await avatarImportUseCase.importAvatars(
            matches: matchedContacts,
            progressHandler: { [weak self] progress in
                guard let self else { return }
                currentProcessingContact = progress.contactName
                currentProcessingIndex = progress.currentIndex
                downloadProgress = progress.progress
                batchCoordinator.updateTask(
                    id: taskID,
                    processedCount: progress.currentIndex,
                    totalCount: progress.totalCount,
                    subtitle: progress.contactName
                )
            }
        )

        let completionState = flowCompletionUseCase.makeImportCompletionState(
            summaryMessage: summaryUseCase.execute(result: importResult),
            importErrors: importResult.errors
        )
        applyFlowCompletionState(completionState)

        AvatarThumbnailStore.shared.bumpContactAvatarRevision()
        try? await loadContacts(forceReload: true)
    }

    func prepareImportConfirmation(matches: [(CNContact, Icon)]) {
        guard matches.isEmpty == false else { return }

        matchedContacts = matches
        importConfirmationState = AvatarImportConfirmationState(
            importMode: importMode,
            contactCount: matches.count,
            uniqueAvatarCount: Set(matches.map(\.1)).count,
            packageName: currentPackageDisplayName,
            previewNames: Array(matches.prefix(3).map { contact, _ in
                Self.displayName(for: contact)
            })
        )
    }

    func unmatchContact(contact: CNContact) {
        withAnimation(.spring(response: 0.3)) {
            matchedContacts.removeAll { $0.0.stableIdentifier == contact.stableIdentifier }
        }
    }

    private func applyMatchPreviewState(_ state: AvatarMatchPreviewState) {
        matchedContacts = state.matchedContacts
        contactsNeedingSelection = state.contactsNeedingSelection
        matchPreviewIcons = state.availableIcons
        showingMatchPreview = state.shouldShowMatchPreview
        refreshAvatarRecommendations()
    }

    private func handleImportFlowFailure(message: String) {
        let failureState = flowCompletionUseCase.makeImportFailureState(alertMessage: message)
        applyFlowCompletionState(failureState)
    }

    private func presentAlert(_ message: String) {
        if let alertHandler {
            alertHandler(message)
            return
        }

        alertMessage = message
        showingAlert = true
    }

    private static func displayName(for contact: CNContact) -> String {
        let name = [contact.givenName, contact.familyName]
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        if name.isEmpty == false {
            return name
        }

        if contact.isKeyAvailable(CNContactOrganizationNameKey),
           contact.organizationName.isEmpty == false {
            return contact.organizationName
        }

        return NSLocalizedString("Unknown Contact", comment: "")
    }
}
