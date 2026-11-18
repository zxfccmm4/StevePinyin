import Testing
@preconcurrency import Contacts
@testable import StevePinyin

@Suite(.serialized)
struct ContactPinyinTransformerTests {
    private let sut = ContactPinyinTransformer.shared

    @Test("No-space pinyin keeps compact display output")
    func convertUsesCompactDisplayForNoSpaceFormats() {
        let contact = ContactFixtures.makeContact(familyName: "张", givenName: "三")

        let converted = sut.convert(contact, format: .plainNoSpace)

        #expect(converted.familyNamePinyin == "Zhang")
        #expect(converted.givenNamePinyin == "San")
        #expect(converted.displayPinyin == "ZhangSan")
    }

    @Test("English-only contacts are skipped")
    func skipsEnglishOnlyContacts() {
        let englishContact = ContactFixtures.makeContact(familyName: "Appleseed", givenName: "John")
        let chineseContact = ContactFixtures.makeContact(familyName: "张", givenName: "三")

        #expect(sut.shouldSkipEnglishOnlyContact(englishContact))
        #expect(sut.shouldSkipEnglishOnlyContact(chineseContact) == false)
    }

    @Test("Nickname generation combines person and company initials")
    func buildsNicknameFromContactAndCompany() {
        let contact = ContactFixtures.makeContact(
            familyName: "张",
            givenName: "三",
            organizationName: "苹果"
        )

        let nickname = sut.buildNickname(for: contact, format: .firstLetter)

        #expect(nickname == "ZSPG")
    }
}
