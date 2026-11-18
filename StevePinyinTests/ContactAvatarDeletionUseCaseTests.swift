import Foundation
import Testing
@preconcurrency import Contacts
@testable import StevePinyin

private enum ContactAvatarDeletionTestError: LocalizedError {
    case updateFailed

    var errorDescription: String? {
        switch self {
        case .updateFailed:
            return "updateFailed"
        }
    }
}

@Suite(.serialized)
struct ContactAvatarDeletionUseCaseTests {
    @Test("Load contacts with avatars filters out contacts without image data")
    func loadContactsWithAvatarsFiltersContacts() async throws {
        let withAvatar = ContactFixtures.makeContact(
            givenName: "With Avatar",
            phoneNumbers: ["13800000001"],
            imageData: Data([0x01])
        )
        let withoutAvatar = ContactFixtures.makeContact(
            givenName: "Without Avatar",
            phoneNumbers: ["13800000002"]
        )
        let mockService = MockContactService(fetchedContacts: [withAvatar, withoutAvatar])
        let sut = ContactAvatarDeletionUseCase(contactService: mockService)

        let result = try await sut.loadContactsWithAvatars(keysToFetch: [])

        #expect(result.map(\.stableIdentifier) == [withAvatar.stableIdentifier])
    }

    @Test("Delete all clears avatar data only for contacts that currently have avatars")
    func deleteAllClearsOnlyContactsWithAvatars() async throws {
        let withAvatar = ContactFixtures.makeContact(
            givenName: "With Avatar",
            phoneNumbers: ["13800000001"],
            imageData: Data([0x01])
        )
        let withoutAvatar = ContactFixtures.makeContact(
            givenName: "Without Avatar",
            phoneNumbers: ["13800000002"]
        )
        let mockService = MockContactService(fetchedContacts: [withAvatar, withoutAvatar])
        let sut = ContactAvatarDeletionUseCase(contactService: mockService)

        let result = try await sut.deleteAllContactAvatars(keysToFetch: [])

        #expect(result.successCount == 1)
        #expect(result.failureCount == 0)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.count == 1)
        #expect(updatedContacts.first?.stableIdentifier == withAvatar.stableIdentifier)
        #expect(updatedContacts.first?.imageData == nil)
    }

    @Test("Delete all falls back to single-contact saves when batch save fails")
    func deleteAllFallsBackToSingleUpdatesWhenBatchWriteFails() async throws {
        let first = ContactFixtures.makeContact(
            givenName: "First",
            phoneNumbers: ["13800000001"],
            imageData: Data([0x01])
        )
        let second = ContactFixtures.makeContact(
            givenName: "Second",
            phoneNumbers: ["13800000002"],
            imageData: Data([0x02])
        )
        let mockService = MockContactService(
            fetchedContacts: [first, second],
            batchUpdateError: ContactAvatarDeletionTestError.updateFailed
        )
        let sut = ContactAvatarDeletionUseCase(contactService: mockService)

        let result = try await sut.deleteAllContactAvatars(keysToFetch: [])

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.count == 2)
        #expect(updatedContacts.allSatisfy { $0.imageData == nil })
    }

    @Test("Delete selected updates requested contacts and reports progress")
    @MainActor
    func deleteSelectedUpdatesRequestedContactsAndReportsProgress() async throws {
        let first = ContactFixtures.makeContact(
            givenName: "First",
            phoneNumbers: ["13800000001"],
            imageData: Data([0x01])
        )
        let second = ContactFixtures.makeContact(
            givenName: "Second",
            phoneNumbers: ["13800000002"],
            imageData: Data([0x02])
        )
        let mockService = MockContactService(
            fetchedContacts: [first, second],
            unifiedContacts: [
                first.stableIdentifier: first,
                second.stableIdentifier: second,
            ]
        )
        let sut = ContactAvatarDeletionUseCase(contactService: mockService)
        var progressEvents: [Int] = []

        let result = try await sut.deleteSelectedAvatars(
            identifiers: [first.stableIdentifier, second.stableIdentifier],
            keysToFetch: [],
            progressHandler: { progress in
                progressEvents.append(progress)
            }
        )

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)
        #expect(progressEvents == [1, 2])

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.map(\.stableIdentifier) == [first.stableIdentifier, second.stableIdentifier])
        #expect(updatedContacts.allSatisfy { $0.imageData == nil })
    }

    @Test("Delete selected collects failures when contact updates fail")
    @MainActor
    func deleteSelectedCollectsFailures() async throws {
        let contact = ContactFixtures.makeContact(
            givenName: "First",
            phoneNumbers: ["13800000001"],
            imageData: Data([0x01])
        )
        let mockService = MockContactService(
            fetchedContacts: [contact],
            unifiedContacts: [contact.stableIdentifier: contact],
            updateError: ContactAvatarDeletionTestError.updateFailed
        )
        let sut = ContactAvatarDeletionUseCase(contactService: mockService)

        let result = try await sut.deleteSelectedAvatars(
            identifiers: [contact.stableIdentifier],
            keysToFetch: [],
            progressHandler: { _ in }
        )

        #expect(result.successCount == 0)
        #expect(result.failureCount == 1)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.isEmpty)
    }
}
