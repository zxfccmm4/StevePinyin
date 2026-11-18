import Foundation
import Testing
@preconcurrency import Contacts
@testable import StevePinyin

private enum DeleteAvatarFlowTestError: LocalizedError {
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "loadFailed"
        }
    }
}

@Suite(.serialized)
struct DeleteAvatarFlowUseCaseTests {
    @Test("Delete all builds the localized summary message")
    func deleteAllBuildsSummaryMessage() async throws {
        let deletionResult = AvatarDeletionResult(successCount: 2, failureCount: 1)
        let mockDeletion = MockContactAvatarDeleting(
            deleteAllResult: .success(deletionResult)
        )
        let sut = DeleteAvatarFlowUseCase(deletionUseCase: mockDeletion)

        let result = try await sut.deleteAllContactAvatars(keysToFetch: [])

        #expect(result.alertMessage == BuildAvatarDeletionSummaryUseCase().execute(result: deletionResult))
    }

    @Test("Delete selected forwards identifiers and uses the summary builder")
    @MainActor
    func deleteSelectedForwardsIdentifiers() async throws {
        let deletionResult = AvatarDeletionResult(successCount: 1, failureCount: 0)
        let mockDeletion = MockContactAvatarDeleting(
            deleteSelectedResult: .success(deletionResult)
        )
        let sut = DeleteAvatarFlowUseCase(deletionUseCase: mockDeletion)
        var progressEvents: [Int] = []
        let identifiers = ["first", "second"]

        let result = try await sut.deleteSelectedContactAvatars(
            identifiers: identifiers,
            keysToFetch: [],
            progressHandler: { progress in
                progressEvents.append(progress)
            }
        )

        #expect(result.alertMessage == BuildAvatarDeletionSummaryUseCase().execute(result: deletionResult))
        #expect(progressEvents == [1, 2])
        let recordedIdentifiers = await mockDeletion.lastDeleteSelectedIdentifiersSnapshot()
        #expect(recordedIdentifiers == identifiers)
    }

    @Test("Loading contacts with avatars passes through the underlying result")
    func loadContactsWithAvatarsPassesThroughContacts() async throws {
        let contact = ContactFixtures.makeContact(
            givenName: "With Avatar",
            phoneNumbers: ["13800000001"],
            imageData: Data([0x01])
        )
        let mockDeletion = MockContactAvatarDeleting(
            contactsWithAvatarsResult: .success([contact])
        )
        let sut = DeleteAvatarFlowUseCase(deletionUseCase: mockDeletion)

        let result = try await sut.loadContactsWithAvatars(keysToFetch: [])

        #expect(result.map(\.stableIdentifier) == [contact.stableIdentifier])
    }

    @Test("Error helper formats underlying error descriptions")
    func errorHelperFormatsErrorDescription() {
        let sut = DeleteAvatarFlowUseCase(deletionUseCase: MockContactAvatarDeleting())

        #expect(sut.makeLoadContactsErrorMessage(DeleteAvatarFlowTestError.loadFailed).contains("loadFailed"))
        #expect(sut.makeDeleteErrorMessage(DeleteAvatarFlowTestError.loadFailed).contains("loadFailed"))
    }
}
