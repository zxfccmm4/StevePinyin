import Testing
@preconcurrency import Contacts
@testable import StevePinyin

private enum ContactsPinyinMaintenanceUseCaseTestError: LocalizedError {
    case batchUpdateFailed

    var errorDescription: String? {
        switch self {
        case .batchUpdateFailed:
            return "batchUpdateFailed"
        }
    }
}

@Suite(.serialized)
struct ContactsPinyinMaintenanceUseCaseTests {
    @Test("Add pinyin updates Chinese contacts and skips English-only contacts")
    func addPinyinSkipsEnglishOnlyContacts() async throws {
        let chineseContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let englishContact = ContactFixtures.makeContact(familyName: "Appleseed", givenName: "John")
        let mockService = MockContactService(fetchedContacts: [chineseContact, englishContact])
        let sut = ContactsPinyinMaintenanceUseCase(contactService: mockService)

        let result = try await sut.addPinyin(format: .plainNoSpace) { _ in }

        #expect(result.successCount == 1)
        #expect(result.skippedEnglishCount == 1)
        #expect(result.failureCount == 0)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        let updatedContact = try #require(updatedContacts.first)
        #expect(updatedContacts.count == 1)
        #expect(updatedContact.phoneticFamilyName == "Zhang")
        #expect(updatedContact.phoneticGivenName == "San")
    }

    @Test("Add pinyin falls back to single-contact saves when batch save fails")
    func addPinyinFallsBackToSingleUpdatesWhenBatchWriteFails() async throws {
        let firstContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let secondContact = ContactFixtures.makeContact(familyName: "李", givenName: "四")
        let mockService = MockContactService(
            fetchedContacts: [firstContact, secondContact],
            batchUpdateError: ContactsPinyinMaintenanceUseCaseTestError.batchUpdateFailed
        )
        let sut = ContactsPinyinMaintenanceUseCase(contactService: mockService)

        let result = try await sut.addPinyin(format: .plainNoSpace) { _ in }

        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        #expect(updatedContacts.count == 2)
        #expect(updatedContacts.map(\.phoneticFamilyName) == ["Zhang", "Li"])
    }

    @Test("Cleanup deletes only contacts without phone numbers")
    func cleanupDeletesOnlyContactsWithoutPhoneNumbers() async throws {
        let withoutPhone = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let withPhone = ContactFixtures.makeContact(
            familyName: "李",
            givenName: "四",
            phoneNumbers: ["13800000000"]
        )
        let mockService = MockContactService(fetchedContacts: [withoutPhone, withPhone])
        let sut = ContactsPinyinMaintenanceUseCase(contactService: mockService)

        let result = try await sut.cleanupContactsWithoutPhoneNumbers { _ in }

        #expect(result.foundCount == 1)
        #expect(result.successCount == 1)
        #expect(result.failureCount == 0)

        let deletedContacts = await mockService.deletedContactsSnapshot()
        #expect(deletedContacts.count == 1)
        #expect(deletedContacts.first?.phoneNumbers.isEmpty == true)
    }
}
