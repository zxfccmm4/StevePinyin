import Foundation
import Testing
@preconcurrency import Contacts
@testable import StevePinyin

private enum Phase8To10TestError: LocalizedError {
    case batchFetchUnavailable

    var errorDescription: String? {
        "batchFetchUnavailable"
    }
}

@Suite("Phase 8–10 Batch Fetch & ContactsPinyinViewModel Regression Tests", .serialized)
struct Phase8To10UpgradeTests {
    @Test("deleteSelectedAvatars batches unified contact fetches into a single store query and falls back on batch error")
    @MainActor
    func deleteSelectedAvatarsUsesBatchFetchWithFallback() async throws {
        let first = ContactFixtures.makeContact(
            familyName: "张",
            givenName: "三",
            phoneNumbers: ["10086"],
            imageData: Data([0xAA])
        )
        let second = ContactFixtures.makeContact(
            familyName: "李",
            givenName: "四",
            phoneNumbers: ["10010"],
            imageData: Data([0xBB])
        )
        let third = ContactFixtures.makeContact(
            familyName: "王",
            givenName: "五",
            phoneNumbers: ["10000"],
            imageData: Data([0xCC])
        )

        let happyService = MockContactService(
            fetchedContacts: [first, second, third],
            unifiedContacts: [
                first.stableIdentifier: first,
                second.stableIdentifier: second,
                third.stableIdentifier: third,
            ]
        )
        let happySUT = ContactAvatarDeletionUseCase(contactService: happyService)

        let happyResult = try await happySUT.deleteSelectedAvatars(
            identifiers: [first.stableIdentifier, second.stableIdentifier, third.stableIdentifier],
            keysToFetch: [],
            progressHandler: { _ in }
        )

        #expect(happyResult.successCount == 3)
        #expect(happyResult.failureCount == 0)
        #expect(await happyService.unifiedContactsFetchCountSnapshot() == 1)
        #expect(await happyService.unifiedContactFetchCountSnapshot() == 0)

        let fallbackService = MockContactService(
            fetchedContacts: [first, second],
            unifiedContacts: [
                first.stableIdentifier: first,
                second.stableIdentifier: second,
            ],
            batchFetchError: Phase8To10TestError.batchFetchUnavailable
        )
        let fallbackSUT = ContactAvatarDeletionUseCase(contactService: fallbackService)

        let fallbackResult = try await fallbackSUT.deleteSelectedAvatars(
            identifiers: [first.stableIdentifier, second.stableIdentifier],
            keysToFetch: [],
            progressHandler: { _ in }
        )

        #expect(fallbackResult.successCount == 2)
        #expect(fallbackResult.failureCount == 0)
        #expect(await fallbackService.unifiedContactsFetchCountSnapshot() == 1)
        #expect(await fallbackService.unifiedContactFetchCountSnapshot() == 2)
    }

    @Test("ContactsPinyinViewModel surfaces permission denial and releases BatchTaskCoordinator state")
    @MainActor
    func contactsPinyinViewModelHandlesPermissionDenied() async {
        let mockService = MockContactService(requestAccessResult: false)
        let coordinator = BatchTaskCoordinator()
        let viewModel = ContactsPinyinViewModel(
            contactService: mockService,
            batchCoordinator: coordinator
        )

        viewModel.handleSelection(format: .withTone)
        await viewModel.waitForActiveTask()

        #expect(viewModel.isProcessing == false)
        #expect(viewModel.showAlert == true)
        #expect(viewModel.alertTone == .permission)
        #expect(coordinator.activeTask == nil)
    }

    @Test("ContactsPinyinViewModel processes Chinese contacts, skips English contacts, and filters search live")
    @MainActor
    func contactsPinyinViewModelProcessesAndFiltersContacts() async {
        let chineseContact = ContactFixtures.makeContact(
            familyName: "单",
            givenName: "雄信",
            organizationName: "重庆银行",
            phoneNumbers: ["10086"]
        )
        let englishContact = ContactFixtures.makeContact(
            familyName: "Jobs",
            givenName: "Steve",
            phoneNumbers: ["10010"]
        )

        let mockService = MockContactService(fetchedContacts: [chineseContact, englishContact])
        let coordinator = BatchTaskCoordinator()
        let viewModel = ContactsPinyinViewModel(
            contactService: mockService,
            batchCoordinator: coordinator
        )

        viewModel.handleSelection(format: .plainLetter)
        await viewModel.waitForActiveTask()

        #expect(viewModel.isProcessing == false)
        #expect(coordinator.activeTask == nil)
        #expect(viewModel.counter == 1)
        #expect(viewModel.processedContacts.count == 1)
        #expect(viewModel.filteredProcessedContacts.count == 1)

        viewModel.searchText = "chong"
        #expect(viewModel.filteredProcessedContacts.count == 1)

        viewModel.searchText = "nonexistent-keyword"
        #expect(viewModel.filteredProcessedContacts.isEmpty)
    }

    @Test("ContactsPinyinViewModel cleanupNoPhone deletes only phone-less contacts")
    @MainActor
    func contactsPinyinViewModelCleanupNoPhoneDeletesTargetContacts() async {
        let withPhone = ContactFixtures.makeContact(
            familyName: "陈",
            givenName: "明",
            phoneNumbers: ["10086"]
        )
        let withoutPhone = ContactFixtures.makeContact(
            familyName: "空",
            givenName: "号"
        )

        let mockService = MockContactService(fetchedContacts: [withPhone, withoutPhone])
        let coordinator = BatchTaskCoordinator()
        let viewModel = ContactsPinyinViewModel(
            contactService: mockService,
            batchCoordinator: coordinator
        )

        viewModel.requestCleanupConfirmation(.cleanupNoPhone)
        #expect(viewModel.showCleanupConfirmation == true)

        viewModel.executeCleanupAction()
        await viewModel.waitForActiveTask()

        let deleted = await mockService.deletedContactsSnapshot()
        #expect(deleted.count == 1)
        #expect((deleted.first as CNContact?)?.stableIdentifier == withoutPhone.stableIdentifier)
        #expect(viewModel.alertTone == .success)
        #expect(coordinator.activeTask == nil)
    }
}
