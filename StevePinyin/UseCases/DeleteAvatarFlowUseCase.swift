import Contacts
import Foundation

struct DeleteAvatarFlowResult {
    let alertMessage: String
}

final class DeleteAvatarFlowUseCase {
    private let deletionUseCase: any ContactAvatarDeleting
    private let summaryUseCase: BuildAvatarDeletionSummaryUseCase

    init(
        deletionUseCase: any ContactAvatarDeleting = ContactAvatarDeletionUseCase(),
        summaryUseCase: BuildAvatarDeletionSummaryUseCase = BuildAvatarDeletionSummaryUseCase()
    ) {
        self.deletionUseCase = deletionUseCase
        self.summaryUseCase = summaryUseCase
    }

    func deleteAllContactAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> DeleteAvatarFlowResult {
        let result = try await deletionUseCase.deleteAllContactAvatars(keysToFetch: keysToFetch)
        return buildResult(from: result)
    }

    func deleteSelectedContactAvatars(
        identifiers: [String],
        keysToFetch: [CNKeyDescriptor],
        progressHandler: @escaping @MainActor (Int) -> Void
    ) async throws -> DeleteAvatarFlowResult {
        let result = try await deletionUseCase.deleteSelectedAvatars(
            identifiers: identifiers,
            keysToFetch: keysToFetch,
            progressHandler: progressHandler
        )
        return buildResult(from: result)
    }

    func loadContactsWithAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> [CNContact] {
        try await deletionUseCase.loadContactsWithAvatars(keysToFetch: keysToFetch)
    }

    func makeDeleteErrorMessage(_ error: Error) -> String {
        String(format: NSLocalizedString("Failed to delete avatars: %@", comment: ""), error.localizedDescription)
    }

    func makeLoadContactsErrorMessage(_ error: Error) -> String {
        String(format: NSLocalizedString("Failed to load contacts: %@", comment: ""), error.localizedDescription)
    }

    private func buildResult(from result: AvatarDeletionResult) -> DeleteAvatarFlowResult {
        return DeleteAvatarFlowResult(
            alertMessage: summaryUseCase.execute(result: result)
        )
    }
}
