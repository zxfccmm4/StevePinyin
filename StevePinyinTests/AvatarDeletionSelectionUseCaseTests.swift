import Testing
@preconcurrency import Contacts
@testable import StevePinyin

struct AvatarDeletionSelectionUseCaseTests {
    private let sut = AvatarDeletionSelectionUseCase()

    @Test("Toggle selection adds and removes contact identifiers")
    func toggleSelectionAddsAndRemovesIdentifier() {
        let contact = ContactFixtures.makeContact(
            givenName: "First",
            phoneNumbers: ["13800000001"]
        )

        let selected = sut.toggleSelection(
            for: contact,
            currentSelection: []
        )
        let deselected = sut.toggleSelection(
            for: contact,
            currentSelection: selected
        )

        #expect(selected == Set([contact.stableIdentifier]))
        #expect(deselected.isEmpty)
    }

    @Test("Select all and isSelected use stable contact identifiers")
    func selectAllUsesStableIdentifiers() {
        let first = ContactFixtures.makeContact(
            givenName: "First",
            phoneNumbers: ["13800000001"]
        )
        let second = ContactFixtures.makeContact(
            givenName: "Second",
            phoneNumbers: ["13800000002"]
        )

        let selected = sut.selectAll(contacts: [first, second])

        #expect(selected == Set([first.stableIdentifier, second.stableIdentifier]))
        #expect(sut.isSelected(first, currentSelection: selected))
        #expect(sut.isSelected(second, currentSelection: selected))
        #expect(sut.deselectAll().isEmpty)
    }
}
