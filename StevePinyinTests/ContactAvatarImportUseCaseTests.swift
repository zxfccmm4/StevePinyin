import Foundation
import Testing
@preconcurrency import Contacts
@testable import StevePinyin

private enum ContactAvatarImportTestError: Error {
    case resolveFailed
    case batchFetchFailed
    case batchUpdateFailed
}

@Suite(.serialized)
struct ContactAvatarImportUseCaseTests {
    @Test("Empty matches return an empty import result")
    func emptyMatchesReturnEmptyResult() async {
        let sut = ContactAvatarImportUseCase(
            contactService: MockContactService(),
            imageDataResolver: MockAvatarImageDataResolver(result: .success(Data([0x01]))),
            delayNanoseconds: 0
        )

        let result = await sut.importAvatars(matches: []) { _ in }

        #expect(result.successCount == 0)
        #expect(result.failureCount == 0)
        #expect(result.errors.isEmpty)
    }

    @Test("Successful import updates the fetched contact image data")
    func successfulImportUpdatesContact() async throws {
        let storedContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let icon = Icon(name: "avatar", url: "https://example.com/avatar.png")
        let imageData = Data([0x01, 0x02, 0x03])
        let mockService = MockContactService(
            unifiedContacts: [storedContact.stableIdentifier: storedContact]
        )
        let resolver = MockAvatarImageDataResolver(result: .success(imageData))
        let sut = ContactAvatarImportUseCase(
            contactService: mockService,
            imageDataResolver: resolver,
            delayNanoseconds: 0
        )
        var progressUpdates: [AvatarImportProgress] = []

        let result = await sut.importAvatars(matches: [(storedContact, icon)]) { progress in
            progressUpdates.append(progress)
        }

        #expect(result.successCount == 1)
        #expect(result.failureCount == 0)
        #expect(result.errors.isEmpty)
        #expect(progressUpdates.count == 1)
        #expect(progressUpdates.first?.currentIndex == 1)
        #expect(progressUpdates.first?.contactName == "三 张")

        let updatedContacts = await mockService.updatedContactsSnapshot()
        let updatedContact = try #require(updatedContacts.first)
        #expect(updatedContact.imageData == imageData)
        #expect(await mockService.unifiedContactsFetchCountSnapshot() == 1)
        #expect(await mockService.unifiedContactFetchCountSnapshot() == 0)

        let requestedIcons = await resolver.requestedIconsSnapshot()
        #expect(requestedIcons == [icon])
    }

    @Test("Resolver failures are collected as import errors")
    func resolverFailuresAreCollected() async {
        let storedContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let mockService = MockContactService(
            unifiedContacts: [storedContact.stableIdentifier: storedContact]
        )
        let resolver = MockAvatarImageDataResolver(result: .failure(ContactAvatarImportTestError.resolveFailed))
        let sut = ContactAvatarImportUseCase(
            contactService: mockService,
            imageDataResolver: resolver,
            delayNanoseconds: 0
        )

        let result = await sut.importAvatars(
            matches: [(storedContact, Icon(name: "avatar", url: "https://example.com/avatar.png"))]
        ) { _ in }

        #expect(result.successCount == 0)
        #expect(result.failureCount == 1)
        #expect(result.errors.count == 1)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.isEmpty)
    }

    @Test("Duplicate icons are resolved once per import batch")
    func duplicateIconsAreResolvedOncePerImportBatch() async throws {
        let firstContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let secondContact = ContactFixtures.makeContact(familyName: "李", givenName: "四")
        let sharedIcon = Icon(name: "avatar", url: "https://example.com/avatar.png")
        let imageData = Data([0x0A, 0x0B, 0x0C])
        let mockService = MockContactService(
            unifiedContacts: [
                firstContact.stableIdentifier: firstContact,
                secondContact.stableIdentifier: secondContact,
            ]
        )
        let resolver = MockAvatarImageDataResolver(result: .success(imageData))
        let sut = ContactAvatarImportUseCase(
            contactService: mockService,
            imageDataResolver: resolver,
            delayNanoseconds: 0
        )

        let result = await sut.importAvatars(
            matches: [
                (firstContact, sharedIcon),
                (secondContact, sharedIcon),
            ]
        ) { _ in }

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.count == 2)
        #expect(updatedContacts.allSatisfy { $0.imageData == imageData })
        #expect(await mockService.unifiedContactsFetchCountSnapshot() == 1)
        #expect(await mockService.unifiedContactFetchCountSnapshot() == 0)

        let requestedIcons = await resolver.requestedIconsSnapshot()
        #expect(requestedIcons == [sharedIcon])
    }

    @Test("Import falls back to single-contact saves when batch save fails")
    func importFallsBackToSingleUpdatesWhenBatchWriteFails() async {
        let firstContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let secondContact = ContactFixtures.makeContact(familyName: "李", givenName: "四")
        let sharedIcon = Icon(name: "avatar", url: "https://example.com/avatar.png")
        let imageData = Data([0x0A, 0x0B, 0x0C])
        let mockService = MockContactService(
            unifiedContacts: [
                firstContact.stableIdentifier: firstContact,
                secondContact.stableIdentifier: secondContact,
            ],
            batchUpdateError: ContactAvatarImportTestError.batchUpdateFailed
        )
        let resolver = MockAvatarImageDataResolver(result: .success(imageData))
        let sut = ContactAvatarImportUseCase(
            contactService: mockService,
            imageDataResolver: resolver,
            delayNanoseconds: 0
        )

        let result = await sut.importAvatars(
            matches: [
                (firstContact, sharedIcon),
                (secondContact, sharedIcon),
            ]
        ) { _ in }

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.count == 2)
        #expect(updatedContacts.allSatisfy { $0.imageData == imageData })
        #expect(await mockService.unifiedContactsFetchCountSnapshot() == 1)
        #expect(await mockService.unifiedContactFetchCountSnapshot() == 0)
    }

    @Test("Import falls back to per-contact fetches when batch contact lookup fails")
    func importFallsBackToSingleFetchesWhenBatchLookupFails() async {
        let firstContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let secondContact = ContactFixtures.makeContact(familyName: "李", givenName: "四")
        let sharedIcon = Icon(name: "avatar", url: "https://example.com/avatar.png")
        let imageData = Data([0x0A, 0x0B, 0x0C])
        let mockService = MockContactService(
            unifiedContacts: [
                firstContact.stableIdentifier: firstContact,
                secondContact.stableIdentifier: secondContact,
            ],
            batchFetchError: ContactAvatarImportTestError.batchFetchFailed
        )
        let resolver = MockAvatarImageDataResolver(result: .success(imageData))
        let sut = ContactAvatarImportUseCase(
            contactService: mockService,
            imageDataResolver: resolver,
            delayNanoseconds: 0
        )

        let result = await sut.importAvatars(
            matches: [
                (firstContact, sharedIcon),
                (secondContact, sharedIcon),
            ]
        ) { _ in }

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)
        #expect(await mockService.unifiedContactsFetchCountSnapshot() == 1)
        #expect(await mockService.unifiedContactFetchCountSnapshot() == 2)
    }
}
