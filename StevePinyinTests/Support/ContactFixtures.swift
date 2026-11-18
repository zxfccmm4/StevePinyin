import Foundation
@preconcurrency import Contacts

enum ContactFixtures {
    static func makeContact(
        familyName: String = "",
        givenName: String = "",
        organizationName: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        phoneticFamilyName: String = "",
        phoneticGivenName: String = "",
        phoneticOrganizationName: String = "",
        nickname: String = "",
        imageData: Data? = nil
    ) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.familyName = familyName
        contact.givenName = givenName
        contact.organizationName = organizationName
        contact.phoneticFamilyName = phoneticFamilyName
        contact.phoneticGivenName = phoneticGivenName
        contact.phoneticOrganizationName = phoneticOrganizationName
        contact.nickname = nickname
        contact.phoneNumbers = phoneNumbers.map { number in
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: number))
        }
        contact.emailAddresses = emailAddresses.map { email in
            CNLabeledValue(label: CNLabelWork, value: email as NSString)
        }
        contact.imageData = imageData
        return contact
    }
}
