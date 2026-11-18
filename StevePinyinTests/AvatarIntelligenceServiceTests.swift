import Foundation
import Testing
import UIKit
@preconcurrency import Contacts
@testable import StevePinyin

struct AvatarIntelligenceServiceTests {
    private let sut = AvatarIntelligenceService()

    @Test("高质量头像会得到推荐分")
    func highQualityAvatarIsRecommended() async throws {
        let data = try imageData(
            size: CGSize(width: 512, height: 512),
            colors: [.systemBlue, .white]
        )

        let assessment = try await sut.analyzeAvatarQuality(imageData: data)

        #expect(assessment.score >= 75)
        #expect(assessment.isRecommended)
        #expect(assessment.issues.contains(.tooSmall) == false)
        #expect(assessment.pixelSize == CGSize(width: 512, height: 512))
    }

    @Test("低分辨率暗色头像会暴露质量问题")
    func lowQualityAvatarReportsIssues() async throws {
        let data = try imageData(
            size: CGSize(width: 96, height: 96),
            colors: [.black]
        )

        let assessment = try await sut.analyzeAvatarQuality(imageData: data)

        #expect(assessment.score < 75)
        #expect(assessment.isRecommended == false)
        #expect(assessment.issues.contains(.tooSmall))
        #expect(assessment.issues.contains(.tooDark))
    }

    @Test("智能推荐优先匹配联系人姓名和组织关键词")
    func recommendationRanksNameAndOrganizationMatchesFirst() throws {
        let contact = ContactFixtures.makeContact(
            familyName: "Zhou",
            givenName: "Steve",
            organizationName: "Apple"
        )
        let icons = [
            Icon(name: "random moon", url: "system:moon.fill"),
            Icon(name: "Steve Apple profile", url: "https://example.com/steve-apple.png"),
            Icon(name: "work badge", url: "system:briefcase.fill"),
        ]

        let recommendations = try sut.recommendAvatars(for: contact, icons: icons)

        #expect(recommendations.count == 3)
        #expect(recommendations.first?.icon.name == "Steve Apple profile")
        #expect((recommendations.first?.score ?? 0) > (recommendations.last?.score ?? 0))
        #expect(recommendations.first?.reasons.isEmpty == false)
    }

    @Test("推荐 UseCase 会跳过已经有头像的联系人")
    func recommendationUseCaseSkipsContactsWithAvatar() throws {
        let pending = ContactFixtures.makeContact(familyName: "Zhou", givenName: "Steve")
        let completed = ContactFixtures.makeContact(
            familyName: "Li",
            givenName: "Ming",
            imageData: Data([0x01])
        )
        let icons = [
            Icon(name: "Steve avatar", url: "https://example.com/steve.png"),
            Icon(name: "Ming avatar", url: "https://example.com/ming.png"),
        ]

        let result = try BuildAvatarRecommendationsUseCase().execute(
            contacts: [pending, completed],
            icons: icons
        )

        #expect(result.recommendationsByContactID.keys.contains(pending.stableIdentifier))
        #expect(result.recommendationsByContactID.keys.contains(completed.stableIdentifier) == false)
        #expect(result.bestMatches.count == 1)
        #expect(result.bestMatches.first?.0.stableIdentifier == pending.stableIdentifier)
    }

    private func imageData(size: CGSize, colors: [UIColor]) throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            guard colors.count > 1 else {
                colors.first?.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                return
            }

            let stripeWidth = size.width / CGFloat(colors.count)
            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(
                    CGRect(
                        x: CGFloat(index) * stripeWidth,
                        y: 0,
                        width: stripeWidth,
                        height: size.height
                    )
                )
            }
        }

        return try #require(image.pngData())
    }
}
