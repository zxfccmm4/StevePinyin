import Foundation
import Testing
@preconcurrency import Contacts
@testable import StevePinyin

struct BuildAvatarMatchPreviewStateUseCaseTests {
    private let sut = BuildAvatarMatchPreviewStateUseCase()

    @Test("Sequential mode shows preview with package icons")
    func sequentialModeUsesPackageIcons() {
        let first = ContactFixtures.makeContact(givenName: "张三")
        let selectedIcon = Icon(name: "one", url: "system:person.crop.circle.fill")
        let packageIcon = Icon(name: "two", url: "system:star.fill")
        let package = IconPackage(name: "Pkg", description: "Desc", icons: [selectedIcon, packageIcon])

        let state = sut.execute(
            result: AvatarMatchingResult(
                matches: [(first, selectedIcon)],
                contactsNeedingSelection: []
            ),
            importMode: .sequential,
            selectedPackage: package,
            selectedUniformIcon: nil
        )

        #expect(state.matchedContacts.count == 1)
        #expect(state.contactsNeedingSelection.isEmpty)
        #expect(state.availableIcons == [selectedIcon, packageIcon])
        #expect(state.shouldShowMatchPreview)
        #expect(state.alertMessage == nil)
    }

    @Test("Single mode falls back to the chosen avatar when no package exists")
    func singleModeFallsBackToSelectedUniformIcon() {
        let first = ContactFixtures.makeContact(givenName: "李四")
        let selectedIcon = Icon(name: "solo", url: "system:person.crop.circle.badge.checkmark")

        let state = sut.execute(
            result: AvatarMatchingResult(
                matches: [(first, selectedIcon)],
                contactsNeedingSelection: []
            ),
            importMode: .single,
            selectedPackage: nil,
            selectedUniformIcon: selectedIcon
        )

        #expect(state.availableIcons == [selectedIcon])
        #expect(state.shouldShowMatchPreview)
        #expect(state.alertMessage == nil)
    }

    @Test("Manual mode without ready matches keeps preview closed and shows no alert")
    func manualModeWithoutMatchesDoesNotAlert() {
        let first = ContactFixtures.makeContact(givenName: "王五")

        let state = sut.execute(
            result: AvatarMatchingResult(
                matches: [],
                contactsNeedingSelection: [first]
            ),
            importMode: .manual,
            selectedPackage: nil,
            selectedUniformIcon: nil
        )

        #expect(state.matchedContacts.isEmpty)
        #expect(state.contactsNeedingSelection.map(\.stableIdentifier) == [first.stableIdentifier])
        #expect(state.availableIcons.isEmpty)
        #expect(state.shouldShowMatchPreview == false)
        #expect(state.alertMessage == nil)
    }
}
