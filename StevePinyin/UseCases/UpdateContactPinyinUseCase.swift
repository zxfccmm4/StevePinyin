import Foundation
@preconcurrency import Contacts

struct UpdateContactPinyinUseCase {
    struct Result {
        let pinyin: String
        let companyPinyin: String
    }

    private let contactService: any ContactServing

    init(contactService: any ContactServing = ContactService.shared) {
        self.contactService = contactService
    }

    func execute(contact: ContactResult, newPinyin: String) async throws -> Result {
        let trimmedPinyin = newPinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneticGivenNameKey,
            CNContactPhoneticFamilyNameKey,
            CNContactPhoneticMiddleNameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneticOrganizationNameKey,
            CNContactThumbnailImageDataKey,
        ] as [CNKeyDescriptor]

        let unifiedContact = try await contactService.fetchUnifiedContact(
            identifier: contact.contact.identifier,
            keys: keysToFetch
        )
        let mutableContact = unifiedContact.makeMutableCopy()

        mutableContact.phoneticFamilyName = ""
        mutableContact.phoneticGivenName = ""
        mutableContact.phoneticMiddleName = ""
        mutableContact.phoneticOrganizationName = ""

        if !contact.company.isEmpty {
            mutableContact.phoneticOrganizationName = trimmedPinyin
            try await contactService.updateContact(mutableContact)
            return Result(pinyin: contact.pinyin, companyPinyin: trimmedPinyin)
        }

        let pinyinComponents = trimmedPinyin
            .split(separator: " ")
            .map(String.init)

        if !mutableContact.familyName.isEmpty, let familyNamePinyin = pinyinComponents.first {
            mutableContact.phoneticFamilyName = familyNamePinyin
            if pinyinComponents.count > 1 {
                mutableContact.phoneticGivenName = pinyinComponents.dropFirst().joined(separator: " ")
            }
        } else {
            mutableContact.phoneticGivenName = trimmedPinyin
        }

        try await contactService.updateContact(mutableContact)
        return Result(pinyin: trimmedPinyin, companyPinyin: contact.companyPinyin)
    }
}
