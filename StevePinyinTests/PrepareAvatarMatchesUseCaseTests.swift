import Foundation
import Testing
@preconcurrency import Contacts
@testable import StevePinyin

struct PrepareAvatarMatchesUseCaseTests {
    private let sut = PrepareAvatarMatchesUseCase()

    @Test("Single mode skips contacts that already have avatars")
    func singleModeSkipsContactsWithExistingAvatar() throws {
        let icon = Icon(name: "star", url: "system:star.fill")
        let contactWithoutAvatar = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let contactWithAvatar = ContactFixtures.makeContact(
            familyName: "李",
            givenName: "四",
            imageData: Data([0x01])
        )

        let result = try sut.execute(
            contacts: [contactWithoutAvatar, contactWithAvatar],
            importMode: .single,
            selectedPackage: nil,
            selectedUniformIcon: icon,
            manualSelections: [:]
        )

        #expect(result.matches.count == 1)
        #expect(result.matches.first?.1 == icon)
        #expect(result.contactsNeedingSelection.isEmpty)
    }

    @Test("Sequential mode cycles package icons")
    func sequentialModeCyclesIcons() throws {
        let iconA = Icon(name: "a", url: "system:star.fill")
        let iconB = Icon(name: "b", url: "system:heart.fill")
        let package = IconPackage(name: "Pkg", description: "Desc", icons: [iconA, iconB])
        let contacts = [
            ContactFixtures.makeContact(familyName: "张", givenName: "三"),
            ContactFixtures.makeContact(familyName: "李", givenName: "四"),
            ContactFixtures.makeContact(familyName: "王", givenName: "五"),
        ]

        let result = try sut.execute(
            contacts: contacts,
            importMode: .sequential,
            selectedPackage: package,
            selectedUniformIcon: nil,
            manualSelections: [:]
        )

        #expect(result.matches.map(\.1) == [iconA, iconB, iconA])
        #expect(result.contactsNeedingSelection.isEmpty)
    }

    @Test("Manual mode returns all pending contacts and keeps chosen matches")
    func manualModeReturnsPendingContactsAndChosenMatches() throws {
        let contact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let icon = Icon(name: "star", url: "system:star.fill")

        let result = try sut.execute(
            contacts: [contact],
            importMode: .manual,
            selectedPackage: IconPackage(name: "Pkg", description: "Desc", icons: [icon]),
            selectedUniformIcon: nil,
            manualSelections: [contact.stableIdentifier: icon]
        )

        #expect(result.contactsNeedingSelection.count == 1)
        #expect(result.matches.count == 1)
        #expect(result.matches.first?.1 == icon)
    }

    @Test("Throws when every contact already has an avatar")
    func throwsWhenNoContactsNeedUpdate() {
        let contact = ContactFixtures.makeContact(
            familyName: "张",
            givenName: "三",
            imageData: Data([0x01])
        )

        #expect(throws: AvatarMatchingUseCaseError.noContactsNeedUpdate) {
            try sut.execute(
                contacts: [contact],
                importMode: .single,
                selectedPackage: nil,
                selectedUniformIcon: Icon(name: "star", url: "system:star.fill"),
                manualSelections: [:]
            )
        }
    }
}
