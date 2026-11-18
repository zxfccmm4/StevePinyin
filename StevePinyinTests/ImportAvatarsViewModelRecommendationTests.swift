import Testing
@preconcurrency import Contacts
@testable import StevePinyin

@MainActor
struct ImportAvatarsViewModelRecommendationTests {
    @Test("刷新头像推荐会缓存每个待选联系人的候选")
    func refreshAvatarRecommendationsCachesCandidates() throws {
        let viewModel = ImportAvatarsViewModel()
        let contact = ContactFixtures.makeContact(
            familyName: "Zhou",
            givenName: "Steve",
            organizationName: "Apple"
        )
        let icons = [
            Icon(name: "Moon", url: "system:moon.fill"),
            Icon(name: "Steve Apple profile", url: "https://example.com/steve-apple.png"),
        ]

        viewModel.contactsNeedingSelection = [contact]
        viewModel.matchPreviewIcons = icons

        viewModel.refreshAvatarRecommendations()

        let recommendations = viewModel.avatarRecommendations(forContact: contact)
        #expect(recommendations.count == 2)
        #expect(recommendations.first?.icon.name == "Steve Apple profile")
        #expect(viewModel.bestAvatarRecommendation(forContact: contact)?.icon.name == "Steve Apple profile")
    }

    @Test("一键应用推荐会同步手动选择和匹配结果")
    func applyBestRecommendationUpdatesManualSelection() throws {
        let viewModel = ImportAvatarsViewModel()
        let contact = ContactFixtures.makeContact(
            familyName: "Zhou",
            givenName: "Steve",
            organizationName: "Apple"
        )
        let icons = [
            Icon(name: "Moon", url: "system:moon.fill"),
            Icon(name: "Steve Apple profile", url: "https://example.com/steve-apple.png"),
        ]

        viewModel.contactsNeedingSelection = [contact]
        viewModel.matchPreviewIcons = icons
        viewModel.refreshAvatarRecommendations()

        viewModel.applyBestAvatarRecommendation(forContact: contact)

        #expect(viewModel.manualSelections[contact.stableIdentifier]?.name == "Steve Apple profile")
        #expect(viewModel.matchedContacts.count == 1)
        #expect(viewModel.matchedContacts.first?.0.stableIdentifier == contact.stableIdentifier)
        #expect(viewModel.matchedContacts.first?.1.name == "Steve Apple profile")
    }
}
