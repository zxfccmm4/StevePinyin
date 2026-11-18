import Testing
@preconcurrency import Contacts
@testable import StevePinyin

@Suite
struct DuplicateContactResultTests {
    @Test("Selected contacts are deduplicated by contact identifier")
    func selectedContactsAreDeduplicatedAcrossGroups() {
        let sharedContact = ContactFixtures.makeContact(
            familyName: "张",
            givenName: "三",
            phoneNumbers: ["13800000000"]
        )
        let secondContact = ContactFixtures.makeContact(
            familyName: "李",
            givenName: "四",
            phoneNumbers: ["13900000000"]
        )

        let firstResult = ContactResult(from: sharedContact)
        let duplicatedResult = ContactResult(from: sharedContact)
        let secondResult = ContactResult(from: secondContact)

        var samePhoneGroup = DuplicateGroup(
            duplicateType: .samePhone,
            contacts: [firstResult, secondResult],
            matchingValue: "13800000000"
        )
        samePhoneGroup.selectedContacts = [firstResult.id]

        var sameNameGroup = DuplicateGroup(
            duplicateType: .exactName,
            contacts: [duplicatedResult],
            matchingValue: "张三"
        )
        sameNameGroup.selectedContacts = [duplicatedResult.id]

        let result = DuplicateContactResult(
            duplicateGroups: [samePhoneGroup, sameNameGroup],
            hasCompleted: true
        )

        #expect(result.selectedCount == 1)
        #expect(result.getSelectedContacts().count == 1)
        #expect(result.totalDuplicates == 2)
    }
}
