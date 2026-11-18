import Foundation
import Observation
enum CleanupAction: Identifiable {
    case removePinyinOnly
    case removeT9Only
    case cleanupNoPhone
    case deleteVCardGroup
    case removeAll

    var id: String {
        switch self {
        case .removePinyinOnly: return "removePinyinOnly"
        case .removeT9Only: return "removeT9Only"
        case .cleanupNoPhone: return "cleanupNoPhone"
        case .deleteVCardGroup: return "deleteVCardGroup"
        case .removeAll: return "removeAll"
        }
    }

    var confirmTitle: String {
        switch self {
        case .removePinyinOnly:
            return NSLocalizedString("Clean Pinyin", comment: "")
        case .removeT9Only:
            return NSLocalizedString("Clean T9 Search", comment: "")
        case .cleanupNoPhone:
            return NSLocalizedString("Cleanup No-Phone Contacts", comment: "")
        case .deleteVCardGroup:
            return NSLocalizedString("Delete vCards Group", comment: "")
        case .removeAll:
            return NSLocalizedString("Remove All", comment: "")
        }
    }

    var confirmMessage: String {
        switch self {
        case .removePinyinOnly:
            return NSLocalizedString("This will remove all pinyin from your contacts. This action cannot be undone.", comment: "")
        case .removeT9Only:
            return NSLocalizedString("This will remove all T9 search data from your contacts. This action cannot be undone.", comment: "")
        case .cleanupNoPhone:
            return NSLocalizedString("This will permanently delete all contacts without phone numbers. This action cannot be undone.", comment: "")
        case .deleteVCardGroup:
            return NSLocalizedString("This will delete the StevePinyin vCards group and all contacts in it. This action cannot be undone.", comment: "")
        case .removeAll:
            return NSLocalizedString("This will remove all pinyin and T9 search data from your contacts. This action cannot be undone.", comment: "")
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .removePinyinOnly:
            return NSLocalizedString("Clean Pinyin", comment: "")
        case .removeT9Only:
            return NSLocalizedString("Clean T9", comment: "")
        case .cleanupNoPhone:
            return NSLocalizedString("Delete Contacts", comment: "")
        case .deleteVCardGroup:
            return NSLocalizedString("Delete Group", comment: "")
        case .removeAll:
            return NSLocalizedString("Remove All", comment: "")
        }
    }
}

@Observable
@MainActor
final class ContactsPinyinViewModel {
    var isProcessing = false
    var processedCount = 0
    var totalCount = 0
    var showAlert = false
    var alertMessage = ""
    var alertTone: ModernAlertTone = .info
    var processedContacts: [ContactResult] = [] {
        didSet { rebuildFilteredContacts() }
    }
    var showFormatSelection = false
    var selectedFormat: PinyinFormat = .withTone
    var counter = 0
    var searchText = "" {
        didSet { rebuildFilteredContacts() }
    }
    private(set) var filteredProcessedContacts: [ContactResult] = []
    var showNicknameFormatSelection = false
    var selectedNicknameFormat: PinyinFormat = .plainNoSpace
    var isAnimating = false
    var showDuplicateDetection = false
    var showCleanupSheet = false
    var showCleanupConfirmation = false
    var pendingCleanupAction: CleanupAction?

    private let contactService: any ContactServing
    private let maintenanceUseCase: ContactsPinyinMaintenanceUseCase
    private let importService = VCardImportService()
    private let batchCoordinator: BatchTaskCoordinator
    private var activeTask: Task<Void, Never>?

    init(
        contactService: any ContactServing = ContactService.shared,
        maintenanceUseCase: ContactsPinyinMaintenanceUseCase? = nil,
        batchCoordinator: BatchTaskCoordinator? = nil
    ) {
        self.contactService = contactService
        self.maintenanceUseCase = maintenanceUseCase ?? ContactsPinyinMaintenanceUseCase(contactService: contactService)
        self.batchCoordinator = batchCoordinator ?? .shared
    }

    func onAppear() {
        isAnimating = true
    }

    func cancelCurrentTask() {
        activeTask?.cancel()
        activeTask = nil
        isProcessing = false
    }

    func waitForActiveTask() async {
        await activeTask?.value
    }

    private func rebuildFilteredContacts() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredProcessedContacts = processedContacts
        } else {
            filteredProcessedContacts = processedContacts.filter { $0.matchesSearchQuery(query) }
        }
    }
    func showPinyinFormatSheet() {
        showFormatSelection = true
    }

    func showT9FormatSheet() {
        showNicknameFormatSelection = true
    }

    func showDuplicateSheet() {
        showDuplicateDetection = true
    }

    func showCleanupOptions() {
        showCleanupSheet = true
    }

    func requestCleanupConfirmation(_ action: CleanupAction) {
        pendingCleanupAction = action
        showCleanupConfirmation = true
    }

    func executeCleanupAction() {
        guard let action = pendingCleanupAction else { return }
        pendingCleanupAction = nil

        switch action {
        case .removePinyinOnly:
            processedContacts.removeAll()
            requestContactsAccessAndRun(taskTitle: NSLocalizedString("Clean Pinyin", comment: "")) { [weak self] taskID in
                await self?.removePinyinOnly(taskID: taskID)
            }
        case .removeT9Only:
            processedContacts.removeAll()
            requestContactsAccessAndRun(taskTitle: NSLocalizedString("Clean T9 Search", comment: "")) { [weak self] taskID in
                await self?.removeT9Only(taskID: taskID)
            }
        case .cleanupNoPhone:
            confirmCleanupNoPhoneContacts()
        case .deleteVCardGroup:
            deleteVCardGroup()
        case .removeAll:
            confirmRemoveAll()
        }
    }

    func handleSelection(format: PinyinFormat) {
        processedContacts.removeAll()
        showFormatSelection = false
        selectedFormat = format
        requestContactsAccessAndRun(taskTitle: NSLocalizedString("Add Pinyin", comment: "")) { [weak self] taskID in
            await self?.processContacts(taskID: taskID)
        }
    }

    func handleT9Selection(_ format: PinyinFormat) {
        showNicknameFormatSelection = false
        selectedNicknameFormat = format
        requestContactsAccessAndRun(taskTitle: NSLocalizedString("T9 Search", comment: "")) { [weak self] taskID in
            await self?.addNicknames(taskID: taskID)
        }
    }

    func confirmRemoveAll() {
        processedContacts.removeAll()
        requestContactsAccessAndRun(taskTitle: NSLocalizedString("Remove All", comment: "")) { [weak self] taskID in
            await self?.removePinyin(taskID: taskID)
        }
    }

    func confirmCleanupNoPhoneContacts() {
        processedContacts.removeAll()
        requestContactsAccessAndRun(taskTitle: NSLocalizedString("Cleanup No-Phone Contacts", comment: "")) { [weak self] taskID in
            await self?.cleanupContactsWithoutPhoneNumbers(taskID: taskID)
        }
    }

    private func requestContactsAccessAndRun(
        taskTitle: String = NSLocalizedString("Processing...", comment: ""),
        _ operation: @escaping @MainActor (UUID) async -> Void
    ) {
        activeTask?.cancel()
        isProcessing = true

        let taskID = batchCoordinator.beginTask(
            title: taskTitle,
            subtitle: NSLocalizedString("Preparing...", comment: ""),
            totalCount: 0
        ) { [weak self] in
            self?.cancelCurrentTask()
        }

        activeTask = Task { [weak self] in
            guard let self else { return }
            defer {
                batchCoordinator.finishTask(id: taskID)
                activeTask = nil
            }
            do {
                let granted = try await contactService.requestAccess()
                guard granted else {
                    presentError(NSLocalizedString("Permission denied to access contacts", comment: ""), tone: .permission)
                    return
                }

                await operation(taskID)
            } catch is CancellationError {
                isProcessing = false
            } catch {
                presentError(NSLocalizedString("Permission denied to access contacts", comment: ""), tone: .permission)
            }
        }
    }

    func runAddPinyinFromIntent(format: PinyinFormat) async throws -> ContactsPinyinMaintenanceUseCase.AddPinyinResult {
        selectedFormat = format
        prepareForProcessing()
        defer { isProcessing = false }
        let result = try await maintenanceUseCase.addPinyin(format: format) { [weak self] progress in
            self?.apply(progress: progress, taskID: nil)
        }
        processedContacts = result.processedContacts
        return result
    }

    private func processContacts(taskID: UUID) async {
        prepareForProcessing()

        do {
            let result = try await maintenanceUseCase.addPinyin(format: selectedFormat) { [weak self] progress in
                self?.apply(progress: progress, taskID: taskID)
            }
            processedContacts = result.processedContacts
            counter += 1

            if result.failureCount > 0 || result.skippedEnglishCount > 0 {
                let failureDetails = result.failureReasons
                    .map { reason, count in
                        String(format: NSLocalizedString("\"%@\": %d contacts", comment: ""), reason, count)
                    }
                    .joined(separator: "\n")

                var message = String(format: NSLocalizedString(
                    "Processing completed.\nSuccessfully added pinyin to %d contacts\n",
                    comment: ""
                ), result.successCount)

                if result.skippedEnglishCount > 0 {
                    message += String(format: NSLocalizedString(
                        "Skipped %d English contacts\n",
                        comment: ""
                    ), result.skippedEnglishCount)
                }

                if result.failureCount > 0 {
                    message += String(format: NSLocalizedString(
                        "Failed: %d contacts\n\nFailure reasons:\n%@",
                        comment: ""
                    ), result.failureCount, failureDetails)
                }

                finishProcessing(with: message, tone: .success)
            } else {
                finishProcessing(with: String(format: NSLocalizedString(
                    "Successfully added pinyin to all %d contacts",
                    comment: ""
                ), result.successCount), tone: .success)
            }
        } catch is CancellationError {
            isProcessing = false
        } catch {
            presentError(String(format: NSLocalizedString("Error processing contacts: %@", comment: ""), error.localizedDescription), tone: .error)
        }
    }

    private func removePinyin(taskID: UUID) async {
        prepareForProcessing()

        do {
            let result = try await maintenanceUseCase.removePinyin { [weak self] progress in
                self?.apply(progress: progress, taskID: taskID)
            }
            processedContacts = result.processedContacts

            finishProcessing(with: String(format: NSLocalizedString(
                "Successfully removed pinyin and T9 Search from %@ contacts",
                comment: ""
            ), "\(result.removedCount)"), tone: .success)
        } catch is CancellationError {
            isProcessing = false
        } catch {
            presentError(String(format: NSLocalizedString("Error removing pinyin: %@", comment: ""), error.localizedDescription), tone: .error)
        }
    }

    private func addNicknames(taskID: UUID) async {
        prepareForProcessing()

        do {
            let result = try await maintenanceUseCase.enableT9(format: selectedNicknameFormat) { [weak self] progress in
                self?.apply(progress: progress, taskID: taskID)
            }
            counter += 1
            if result.failureCount > 0 {
                let failureDetails = result.failureReasons
                    .map { reason, count in "\(reason): \(count) contacts" }
                    .joined(separator: "\n")

                finishProcessing(with: String(format: NSLocalizedString(
                    "Processing completed.\nSuccessfully enabled T9 search for %d contacts\nFailed: %d contacts\n\nFailure reasons:\n%@",
                    comment: ""
                ), result.successCount, result.failureCount, failureDetails), tone: .success)
            } else {
                finishProcessing(with: String(format: NSLocalizedString(
                    "Successfully enabled T9 search for all %d contacts",
                    comment: ""
                ), result.successCount), tone: .success)
            }
        } catch is CancellationError {
            isProcessing = false
        } catch {
            presentError(String(format: NSLocalizedString(
                "Error enabling T9 search: %@",
                comment: ""
            ), error.localizedDescription), tone: .error)
        }
    }

    private func cleanupContactsWithoutPhoneNumbers(taskID: UUID) async {
        prepareForProcessing()

        do {
            let result = try await maintenanceUseCase.cleanupContactsWithoutPhoneNumbers { [weak self] progress in
                self?.apply(progress: progress, taskID: taskID)
            }

            if result.foundCount == 0 {
                finishProcessing(with: NSLocalizedString("No contacts without phone numbers were found.", comment: ""), tone: .info)
            } else if result.failureCount > 0 {
                let failureDetails = result.failureReasons
                    .map { reason, count in "\(reason): \(count)" }
                    .joined(separator: "\n")

                finishProcessing(with: String(format: NSLocalizedString(
                    "Cleanup completed.\nDeleted %d contacts without phone numbers\nFailed: %d\n%@",
                    comment: ""
                ), result.successCount, result.failureCount, failureDetails), tone: .success)
            } else {
                finishProcessing(with: String(format: NSLocalizedString(
                    "Successfully deleted %d contacts without phone numbers",
                    comment: ""
                ), result.successCount), tone: .success)
            }
        } catch is CancellationError {
            isProcessing = false
        } catch {
            presentError(String(format: NSLocalizedString("Error cleaning contacts: %@", comment: ""), error.localizedDescription), tone: .error)
        }
    }

    private func removePinyinOnly(taskID: UUID) async {
        prepareForProcessing()

        do {
            let result = try await maintenanceUseCase.removePinyinOnly { [weak self] progress in
                self?.apply(progress: progress, taskID: taskID)
            }

            finishProcessing(with: String(format: NSLocalizedString(
                "Successfully removed pinyin from %@ contacts",
                comment: ""
            ), "\(result.removedCount)"), tone: .success)
        } catch is CancellationError {
            isProcessing = false
        } catch {
            presentError(String(format: NSLocalizedString("Error removing pinyin: %@", comment: ""), error.localizedDescription), tone: .error)
        }
    }

    private func removeT9Only(taskID: UUID) async {
        prepareForProcessing()

        do {
            let result = try await maintenanceUseCase.removeT9Only { [weak self] progress in
                self?.apply(progress: progress, taskID: taskID)
            }

            finishProcessing(with: String(format: NSLocalizedString(
                "Successfully removed T9 search from %@ contacts",
                comment: ""
            ), "\(result.removedCount)"), tone: .success)
        } catch is CancellationError {
            isProcessing = false
        } catch {
            presentError(String(format: NSLocalizedString("Error removing T9 search: %@", comment: ""), error.localizedDescription), tone: .error)
        }
    }
    private func deleteVCardGroup() {
        Task {
            do {
                let result = try await importService.deleteVCardGroup()
                if result.groupDeleted {
                    alertMessage = String(format: NSLocalizedString(
                        "Successfully deleted StevePinyin vCards group and %d contacts",
                        comment: ""
                    ), result.contactsDeleted)
                    alertTone = .success
                } else {
                    alertMessage = NSLocalizedString("StevePinyin vCards group not found", comment: "")
                    alertTone = .info
                }
                showAlert = true
            } catch {
                presentError(String(format: NSLocalizedString("Error deleting group: %@", comment: ""), error.localizedDescription), tone: .error)
            }
        }
    }

    private func prepareForProcessing() {
        isProcessing = true
        processedCount = 0
        totalCount = 0
    }

    private func apply(
        progress: ContactsPinyinMaintenanceUseCase.Progress,
        taskID: UUID?
    ) {
        processedCount = progress.processedCount
        totalCount = progress.totalCount
        if let taskID {
            batchCoordinator.updateTask(
                id: taskID,
                processedCount: progress.processedCount,
                totalCount: progress.totalCount,
                subtitle: progress.totalCount > 0 ? "\(progress.processedCount) / \(progress.totalCount)" : nil
            )
        }
    }
    private func finishProcessing(with message: String, tone: ModernAlertTone) {
        isProcessing = false
        alertMessage = message
        alertTone = tone
        showAlert = true
    }

    private func presentError(_ message: String, tone: ModernAlertTone = .error) {
        isProcessing = false
        alertMessage = message
        alertTone = tone
        showAlert = true
    }
}
