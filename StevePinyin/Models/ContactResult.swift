//
//  ContactResult.swift
//  StevePinyin
//
//  Created by Steve Zhou on 11/1/24.
//

import Foundation
import Contacts

extension CNContact {
    var stableIdentifier: String {
        if identifier.isEmpty == false {
            return identifier
        }

        let displayName = [familyName, givenName].joined()
        let phones = phoneNumbers.map(\.value.stringValue).joined(separator: ",")
        let emails = emailAddresses.map { $0.value as String }.joined(separator: ",")
        return [displayName, organizationName, phones, emails].joined(separator: "|")
    }

    var hasAvatarImage: Bool {
        if isKeyAvailable(CNContactImageDataAvailableKey), imageDataAvailable {
            return true
        }
        if isKeyAvailable(CNContactThumbnailImageDataKey),
           let thumbnailData = thumbnailImageData,
           thumbnailData.isEmpty == false {
            return true
        }
        if isKeyAvailable(CNContactImageDataKey),
           let fullImageData = imageData,
           fullImageData.isEmpty == false {
            return true
        }
        return false
    }

    func makeMutableCopy() -> CNMutableContact {
        guard let mutable = mutableCopy() as? CNMutableContact else {
            preconditionFailure("CNContact.mutableCopy() must produce CNMutableContact")
        }
        return mutable
    }
}

extension CNGroup {
    func makeMutableCopy() -> CNMutableGroup {
        guard let mutable = mutableCopy() as? CNMutableGroup else {
            preconditionFailure("CNGroup.mutableCopy() must produce CNMutableGroup")
        }
        return mutable
    }
}

struct ContactResult: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    var pinyin: String
    let contact: CNContact
    var company: String
    var companyPinyin: String

    var contactIdentifier: String {
        id
    }

    static func == (lhs: ContactResult, rhs: ContactResult) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.pinyin == rhs.pinyin &&
        lhs.company == rhs.company &&
        lhs.companyPinyin == rhs.companyPinyin
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(pinyin)
        hasher.combine(company)
        hasher.combine(companyPinyin)
    }

    init(from contact: CNContact) {
        self.id = contact.stableIdentifier
        self.name = "\(contact.familyName)\(contact.givenName)"
        self.pinyin = "\(contact.phoneticFamilyName) \(contact.phoneticGivenName)".trimmingCharacters(in: .whitespaces)
        self.contact = contact
        self.company = contact.organizationName
        self.companyPinyin = contact.phoneticOrganizationName
    }

    func matchesSearchQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }
        return name.localizedStandardContains(trimmed) ||
            pinyin.localizedStandardContains(trimmed) ||
            company.localizedStandardContains(trimmed) ||
            companyPinyin.localizedStandardContains(trimmed)
    }
}
