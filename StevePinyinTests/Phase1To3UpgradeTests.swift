import AppIntents
@preconcurrency import Contacts
import CoreSpotlight
import Foundation
import Testing
import UIKit
@testable import StevePinyin

@Suite(.serialized)
struct Phase1To3UpgradeTests {
    @Test("ContactResult 复用稳定联系人标识并支持标准本地化检索")
    func contactResultUsesStableIdentityAndStandardSearch() {
        let contact = ContactFixtures.makeContact(
            familyName: "周",
            givenName: "明",
            organizationName: "中国银行"
        )
        let first = ContactResult(from: contact)
        let second = ContactResult(from: contact)

        #expect(first.id == second.id)
        #expect(first.id == contact.stableIdentifier)
        #expect(first.matchesSearchQuery("银行"))
        #expect(first.matchesSearchQuery("周明"))
        #expect(first.matchesSearchQuery("不存在关键词") == false)
    }

    @Test("公司名多音字前缀桶匹配支持声调、全拼与 T9 首字母")
    func companyPolyphonicWordsMatchAccurately() {
        let contact = ContactFixtures.makeContact(
            familyName: "重",
            givenName: "庆",
            organizationName: "重庆银行"
        )
        let transformer = ContactPinyinTransformer.shared

        let withTone = transformer.convert(contact, format: .withTone)
        let compact = transformer.convert(contact, format: .plainNoSpace)
        let t9Initials = transformer.buildNickname(for: contact, format: .firstNoSpace)

        #expect(withTone.companyPinyin == "Chóng Qìng Yín Háng")
        #expect(compact.companyPinyin == "ChongQingYinHang")
        #expect(t9Initials.hasSuffix("CQYH"))
    }

    @Test("BatchTaskCoordinator 追踪实时进度与协同取消回调")
    @MainActor
    func batchTaskCoordinatorTracksProgressAndCancellation() {
        let coordinator = BatchTaskCoordinator()
        var didInvokeCancel = false

        let id = coordinator.beginTask(
            title: "添加拼音",
            subtitle: "准备中",
            totalCount: 200
        ) {
            didInvokeCancel = true
        }

        coordinator.updateTask(id: id, processedCount: 50, totalCount: 200, subtitle: "50 / 200")
        #expect(coordinator.activeTask?.percentageText == "25%")
        #expect(coordinator.canCancelActiveTask)

        coordinator.cancelActiveTask()
        #expect(didInvokeCancel)
        #expect(coordinator.activeTask?.isCancelling == true)

        coordinator.finishTask(id: id)
        #expect(coordinator.activeTask == nil)
    }

    @Test("Apple Intelligence 系统模式在模型可用或不可用时均返回合法结构")
    func systemModeQualityAndRecommendationGracefullyResolve() async throws {
        let service = AvatarIntelligenceService()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320), format: format)
        let data = renderer.pngData { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 80, y: 80, width: 160, height: 160))
        }

        let assessment = try await service.analyzeAvatarQuality(imageData: data, mode: .system)
        #expect(assessment.pixelSize == CGSize(width: 320, height: 320))
        #expect((0 ... 100).contains(assessment.score))
        #expect(service.availabilitySummary(mode: .system).isEmpty == false)

        let contact = ContactFixtures.makeContact(familyName: "王", givenName: "珊", organizationName: "Design")
        let icons = [
            Icon(name: "Design Studio", url: "system:paintbrush.fill"),
            Icon(name: "Moon", url: "system:moon.fill"),
        ]
        let ranked = try await service.recommendAvatarsAsync(for: contact, icons: icons, mode: .system, limit: 2)
        #expect(ranked.count == 2)
        #expect(ranked.first?.icon.name == "Design Studio")
    }

    @Test("AvatarPackageEntity 提供 Spotlight 属性集与 Ownership 元数据")
    func avatarPackageEntityProvidesIndexedAndOwnershipMetadata() {
        let package = AvatarPackage(
            id: "pkg-test-1",
            name: "商务精选头像包",
            description: "高清圆角头像",
            icons: [Icon(name: "Person", url: "system:person.fill")],
            isDefault: false,
            createdAt: Date()
        )
        let entity = AvatarPackageEntity(package: package)

        #expect(entity.ownership == .unknown)
        #expect(entity.attributeSet.title == "商务精选头像包")
        #expect(entity.attributeSet.contentDescription?.contains("1 个头像") == true)

        let searchIntent = SearchContactsInAppIntent(criteria: StringSearchCriteria(term: "银行"))
        #expect(searchIntent.criteria.term == "银行")
    }
}
