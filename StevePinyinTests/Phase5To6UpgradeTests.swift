@preconcurrency import Contacts
import Foundation
import Testing
@testable import StevePinyin

private enum DuplicateManagerTestError: LocalizedError {
    case batchRejected

    var errorDescription: String? {
        "ReadOnlyContainerError"
    }
}

@Suite(.serialized)
struct Phase5To6UpgradeTests {
    @Test("轻量扫描键描述符排除全尺寸 CNContactImageDataKey 并保留安全头像检测")
    func lightweightContactScansExcludeFullResolutionImageDataKey() async throws {
        let withAvatar = ContactFixtures.makeContact(
            familyName: "林",
            givenName: "墨",
            phoneNumbers: ["13800138001"],
            imageData: Data([0x89, 0x50, 0x4E, 0x47])
        )
        let withoutAvatar = ContactFixtures.makeContact(
            familyName: "林",
            givenName: "墨",
            phoneNumbers: ["13800138001"]
        )

        #expect((withAvatar as CNContact).hasAvatarImage == true)
        #expect((withoutAvatar as CNContact).hasAvatarImage == false)

        let mockService = MockContactService(fetchedContacts: [withAvatar, withoutAvatar])
        let duplicateUseCase = DuplicateContactDetectionUseCase(contactService: mockService)
        let groups = try await duplicateUseCase.execute(types: [.exactName]) { _ in }

        #expect(groups.count == 1)
        let duplicateFetchedKeys = await mockService.lastFetchedKeyStringsSnapshot()
        #expect(duplicateFetchedKeys.contains(CNContactImageDataAvailableKey))
        #expect(duplicateFetchedKeys.contains(CNContactThumbnailImageDataKey))
        #expect(duplicateFetchedKeys.contains(CNContactImageDataKey) == false)

        let updateUseCase = UpdateContactPinyinUseCase(contactService: mockService)
        _ = try await updateUseCase.execute(contact: ContactResult(from: withoutAvatar), newPinyin: "Lin Mo")
        let updateFetchedKeys = await mockService.lastUnifiedFetchKeyStringsSnapshot()
        #expect(updateFetchedKeys.contains(CNContactThumbnailImageDataKey))
        #expect(updateFetchedKeys.contains(CNContactImageDataKey) == false)
    }

    @Test("DuplicateContactManager 批量删除失败时回退逐条删除并保留部分成功状态与错误提示")
    @MainActor
    func duplicateManagerFallsBackToIndividualDeletesAndPreservesPartialSuccess() async {
        let keepContact = ContactFixtures.makeContact(
            familyName: "陈",
            givenName: "宇",
            phoneNumbers: ["13900001111"]
        )
        let deletableDuplicate = ContactFixtures.makeContact(
            familyName: "陈",
            givenName: "宇",
            phoneNumbers: ["13900002222"]
        )
        let readOnlyDuplicate = ContactFixtures.makeContact(
            familyName: "陈",
            givenName: "宇",
            phoneNumbers: ["13900003333"]
        )

        let keepResult = ContactResult(from: keepContact)
        let deletableResult = ContactResult(from: deletableDuplicate)
        let readOnlyResult = ContactResult(from: readOnlyDuplicate)

        let mockService = MockContactService(
            fetchedContacts: [keepContact, deletableDuplicate, readOnlyDuplicate],
            batchDeleteError: DuplicateManagerTestError.batchRejected,
            failingDeleteIdentifiers: [readOnlyResult.contactIdentifier]
        )
        let coordinator = BatchTaskCoordinator()
        let manager = DuplicateContactManager(
            contactService: mockService,
            batchCoordinator: coordinator
        )

        var group = DuplicateGroup(
            duplicateType: .exactName,
            contacts: [keepResult, deletableResult, readOnlyResult],
            matchingValue: "陈宇"
        )
        group.selectWithMode(.selectOthersToDelete)
        manager.applyDetectedGroups([group])

        #expect(manager.duplicateResult.selectedCount == 2)

        let summary = await manager.deleteSelectedDuplicates()

        #expect(summary == DuplicateDeletionSummary(deletedCount: 1, failedCount: 1))
        #expect(coordinator.activeTask == nil)
        #expect(manager.isDeleting == false)
        #expect(manager.showingAlert == true)
        #expect(manager.alertMessage.contains("1"))

        let deletedInStore = await mockService.deletedContactsSnapshot()
        #expect(deletedInStore.map { ($0 as CNContact).stableIdentifier } == [deletableResult.contactIdentifier])

        #expect(manager.duplicateResult.duplicateGroups.count == 1)
        let remainingIDs = manager.duplicateResult.duplicateGroups[0].contacts.map(\.contactIdentifier)
        #expect(remainingIDs == [keepResult.contactIdentifier, readOnlyResult.contactIdentifier])
        #expect(manager.duplicateResult.selectedCount == 0)
    }

    @Test("DuplicateContactManager 扫描失败时显式暴露错误告警而非静默吞掉异常")
    @MainActor
    func duplicateManagerDetectionSurfacesFetchError() async {
        let mockService = MockContactService(fetchError: ContactError.accessDenied)
        let coordinator = BatchTaskCoordinator()
        let manager = DuplicateContactManager(
            contactService: mockService,
            batchCoordinator: coordinator
        )

        await manager.performDetection()

        #expect(manager.isDetecting == false)
        #expect(coordinator.activeTask == nil)
        #expect(manager.showingAlert == true)
        #expect(manager.alertMessage == ContactError.accessDenied.localizedDescription)
    }

    @Test("IntentRouter 传递重复联系人结果后单次消费并清理导航状态")
    @MainActor
    func intentRouterConsumesPendingDuplicateGroupsOnceAndClearsNavigation() {
        let first = ContactResult(from: ContactFixtures.makeContact(familyName: "赵", givenName: "敏"))
        let second = ContactResult(from: ContactFixtures.makeContact(familyName: "赵", givenName: "敏"))
        let group = DuplicateGroup(
            duplicateType: .exactName,
            contacts: [first, second],
            matchingValue: "赵敏"
        )

        let router = IntentRouter.shared
        router.clearNavigation()
        _ = router.consumePendingDuplicateGroups()

        router.handleDuplicateCheckResult(groups: [group])
        #expect(router.isHandlingIntent == true)
        #expect(
            router.navigationTarget == .duplicateContacts(
                duplicates: [[first.contactIdentifier, second.contactIdentifier]]
            )
        )

        let consumed = router.consumePendingDuplicateGroups()
        #expect(consumed?.count == 1)
        #expect(consumed?.first?.matchingValue == "赵敏")
        #expect(router.consumePendingDuplicateGroups() == nil)

        router.clearNavigation()
        #expect(router.navigationTarget == nil)
        #expect(router.isHandlingIntent == false)
    }
}
