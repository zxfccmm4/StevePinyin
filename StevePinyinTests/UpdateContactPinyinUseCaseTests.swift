import Testing
@preconcurrency import Contacts
@testable import StevePinyin

@Suite(.serialized)
struct UpdateContactPinyinUseCaseTests {
    @Test("Person pinyin updates family and given name in one save")
    func updatesPersonPinyinInOneSave() async throws {
        let storedContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let mockService = MockContactService(fetchedContacts: [storedContact])
        let sut = UpdateContactPinyinUseCase(contactService: mockService)
        let contact = ContactResult(from: storedContact)

        let result = try await sut.execute(contact: contact, newPinyin: "Zhang San")

        #expect(result.pinyin == "Zhang San")
        #expect(result.companyPinyin.isEmpty)

        let updatedContacts = await mockService.updatedContactsSnapshot()
        let updatedContact = try #require(updatedContacts.first)
        #expect(updatedContacts.count == 1)
        #expect(updatedContact.phoneticFamilyName == "Zhang")
        #expect(updatedContact.phoneticGivenName == "San")
        #expect(updatedContact.phoneticOrganizationName.isEmpty)
    }

    @Test("Company pinyin updates organization in one save")
    func updatesCompanyPinyinInOneSave() async throws {
        let storedContact = ContactFixtures.makeContact(organizationName: "苹果")
        let mockService = MockContactService(fetchedContacts: [storedContact])
        let sut = UpdateContactPinyinUseCase(contactService: mockService)
        let contact = ContactResult(from: storedContact)

        let result = try await sut.execute(contact: contact, newPinyin: "Ping Guo")

        #expect(result.pinyin.isEmpty)
        #expect(result.companyPinyin == "Ping Guo")

        let updatedContacts = await mockService.updatedContactsSnapshot()
        let updatedContact = try #require(updatedContacts.first)
        #expect(updatedContacts.count == 1)
        #expect(updatedContact.phoneticOrganizationName == "Ping Guo")
        #expect(updatedContact.phoneticFamilyName.isEmpty)
        #expect(updatedContact.phoneticGivenName.isEmpty)
    }
}
