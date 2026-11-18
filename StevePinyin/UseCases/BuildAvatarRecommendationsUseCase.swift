import Contacts
import Foundation

struct AvatarRecommendationResult {
    let recommendationsByContactID: [String: [AvatarRecommendation]]

    var bestMatches: [(CNContact, Icon)] {
        contacts.compactMap { contact in
            guard let recommendation = recommendationsByContactID[contact.stableIdentifier]?.first else {
                return nil
            }
            return (contact, recommendation.icon)
        }
    }

    private let contacts: [CNContact]

    init(contacts: [CNContact], recommendationsByContactID: [String: [AvatarRecommendation]]) {
        self.contacts = contacts
        self.recommendationsByContactID = recommendationsByContactID
    }
}

struct BuildAvatarRecommendationsUseCase {
    private let intelligenceService: AvatarIntelligenceService

    init(intelligenceService: AvatarIntelligenceService = AvatarIntelligenceService()) {
        self.intelligenceService = intelligenceService
    }

    func execute(
        contacts: [CNContact],
        icons: [Icon],
        limitPerContact: Int = 3,
        mode: AvatarIntelligenceMode = .demo
    ) throws -> AvatarRecommendationResult {
        let contactsWithoutAvatar = contacts.filter { !$0.hasAvatarImage }

        let recommendations = try intelligenceService.recommendAvatars(
            for: contactsWithoutAvatar,
            icons: icons,
            mode: mode,
            limitPerContact: limitPerContact
        )

        return AvatarRecommendationResult(
            contacts: contactsWithoutAvatar,
            recommendationsByContactID: recommendations
        )
    }
}
