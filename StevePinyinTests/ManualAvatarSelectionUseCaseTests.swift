import Testing
@preconcurrency import Contacts
@testable import StevePinyin

struct ManualAvatarSelectionUseCaseTests {
    private let sut = ManualAvatarSelectionUseCase()

    @Test("Setting an avatar stores the selection and rebuilds matches")
    func setAvatarBuildsMatchState() {
        let contact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let icon = Icon(name: "star", url: "system:star.fill")

        let state = sut.setAvatar(
            icon,
            for: contact,
            currentSelections: [:],
            contactsNeedingSelection: [contact]
        )

        #expect(state.manualSelections[contact.stableIdentifier] == icon)
        #expect(state.matchedContacts.count == 1)
        #expect(state.matchedContacts.first?.1 == icon)
    }

    @Test("Removing a selection drops the corresponding match")
    func removeSelectionDropsMatch() {
        let contact = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let icon = Icon(name: "star", url: "system:star.fill")

        let state = sut.removeSelection(
            for: contact,
            currentSelections: [contact.stableIdentifier: icon],
            contactsNeedingSelection: [contact]
        )

        #expect(state.manualSelections.isEmpty)
        #expect(state.matchedContacts.isEmpty)
    }

    @Test("Selection completeness compares selected count to pending contacts")
    func selectionCompletenessUsesPendingContactsCount() {
        let contactA = ContactFixtures.makeContact(familyName: "张", givenName: "三")
        let contactB = ContactFixtures.makeContact(familyName: "李", givenName: "四")
        let icon = Icon(name: "star", url: "system:star.fill")

        #expect(
            sut.isSelectionComplete(
                contactsNeedingSelection: [contactA, contactB],
                manualSelections: [contactA.stableIdentifier: icon]
            ) == false
        )
        #expect(
            sut.isSelectionComplete(
                contactsNeedingSelection: [contactA],
                manualSelections: [contactA.stableIdentifier: icon]
            )
        )
    }
}
