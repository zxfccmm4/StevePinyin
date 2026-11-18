import Foundation
import Observation
@preconcurrency import Contacts

struct DuplicateDeletionSummary: Equatable, Sendable {
    let deletedCount: Int
    let failedCount: Int
}

@Observable
@MainActor
final class DuplicateContactManager {
    private static let deleteBatchSize = 200

    var duplicateResult = DuplicateContactResult()
    var isDetecting = false
    var detectionProgress: Float = 0.0
    var selectedDuplicateTypes: Set<DuplicateType> = [.exactName, .samePhone, .sameEmail]

    var isDeleting = false
    var deleteProgress: Float = 0.0
    var currentDeletingContact = ""
    var currentDeletingIndex = 0
    var totalContactsToDelete = 0

    var showingAlert = false
    var alertMessage = ""

    private let contactService: any ContactServing
    private let detectionUseCase: DuplicateContactDetectionUseCase
    private let batchCoordinator: BatchTaskCoordinator
    private var detectionTask: Task<Void, Never>?
    private var isDeleteCancelled = false

    init(
        contactService: any ContactServing = ContactService.shared,
        detectionUseCase: DuplicateContactDetectionUseCase? = nil,
        batchCoordinator: BatchTaskCoordinator? = nil
    ) {
        self.contactService = contactService
        self.detectionUseCase = detectionUseCase ?? DuplicateContactDetectionUseCase(contactService: contactService)
        self.batchCoordinator = batchCoordinator ?? .shared
    }

    func detectDuplicates() {
        detectionTask?.cancel()
        detectionTask = Task { [weak self] in
            await self?.performDetection()
        }
    }

    func performDetection() async {
        isDetecting = true
        detectionProgress = 0.0

        let selectedTypes = selectedDuplicateTypes
        let coordinator = batchCoordinator
        let taskID = coordinator.beginTask(
            title: NSLocalizedString("Duplicate Detection", comment: ""),
            subtitle: NSLocalizedString("Scanning contacts...", comment: ""),
            totalCount: 100
        ) { [weak self] in
            self?.cancelDetection()
        }
        defer { coordinator.finishTask(id: taskID) }

        var throttler = ProgressThrottler(interval: .milliseconds(80))

        do {
            let groups = try await detectionUseCase.execute(types: selectedTypes) { [weak self] progress in
                guard let self else { return }
                let forceEmit = progress >= 1.0 || progress <= 0.0
                guard throttler.shouldEmit(force: forceEmit) else { return }
                self.detectionProgress = progress
                self.batchCoordinator.updateTask(
                    id: taskID,
                    processedCount: Int((progress * 100).rounded()),
                    totalCount: 100
                )
            }

            guard Task.isCancelled == false else {
                detectionProgress = 0.0
                isDetecting = false
                return
            }

            duplicateResult.duplicateGroups = groups
            duplicateResult.hasCompleted = true
            detectionProgress = 1.0
            isDetecting = false
        } catch is CancellationError {
            detectionProgress = 0.0
            isDetecting = false
        } catch {
            detectionProgress = 0.0
            isDetecting = false
            presentError(error)
        }
    }

    func cancelDetection() {
        detectionTask?.cancel()
        detectionTask = nil
        isDetecting = false
        detectionProgress = 0.0
    }

    func cancelDeletion() {
        isDeleteCancelled = true
    }

    @discardableResult
    func deleteSelectedDuplicates() async -> DuplicateDeletionSummary {
        let selectedContacts = duplicateResult.getSelectedContacts()
        guard selectedContacts.isEmpty == false else {
            return DuplicateDeletionSummary(deletedCount: 0, failedCount: 0)
        }

        let total = selectedContacts.count
        isDeleting = true
        isDeleteCancelled = false
        deleteProgress = 0.0
        totalContactsToDelete = total
        currentDeletingIndex = 0
        currentDeletingContact = ""

        let coordinator = batchCoordinator
        let taskID = coordinator.beginTask(
            title: NSLocalizedString("Delete Selected Duplicates", comment: ""),
            subtitle: NSLocalizedString("Preparing...", comment: ""),
            totalCount: total
        ) { [weak self] in
            self?.cancelDeletion()
        }
        defer {
            coordinator.finishTask(id: taskID)
            isDeleting = false
        }

        var throttler = ProgressThrottler(interval: .milliseconds(80))
        var pendingBatch: [(result: ContactResult, mutable: CNMutableContact)] = []
        pendingBatch.reserveCapacity(min(total, Self.deleteBatchSize))

        var succeededContacts: [ContactResult] = []
        succeededContacts.reserveCapacity(total)
        var failedCount = 0
        var firstError: Error?
        var processedCount = 0

        func emitProgress(contactName: String, force: Bool = false) {
            guard throttler.shouldEmit(force: force) else { return }
            currentDeletingContact = contactName
            currentDeletingIndex = processedCount
            deleteProgress = total > 0 ? Float(processedCount) / Float(total) : 1.0
            coordinator.updateTask(
                id: taskID,
                processedCount: processedCount,
                totalCount: total,
                subtitle: contactName
            )
        }

        func flushPendingDeletes() async {
            guard pendingBatch.isEmpty == false else { return }
            let batch = pendingBatch
            pendingBatch.removeAll(keepingCapacity: true)

            do {
                try await contactService.deleteContacts(batch.map(\.mutable))
                succeededContacts.append(contentsOf: batch.map(\.result))
                processedCount += batch.count
                if let lastContact = batch.last?.result.contact {
                    emitProgress(contactName: contactDisplayName(for: lastContact), force: processedCount == total)
                }
            } catch {
                for item in batch {
                    if isDeleteCancelled || Task.isCancelled { break }
                    let displayName = contactDisplayName(for: item.result.contact)
                    do {
                        try await contactService.deleteContact(item.mutable)
                        succeededContacts.append(item.result)
                    } catch {
                        failedCount += 1
                        if firstError == nil {
                            firstError = error
                        }
                    }
                    processedCount += 1
                    emitProgress(contactName: displayName, force: processedCount == total)
                }
            }
        }

        for contactResult in selectedContacts {
            if isDeleteCancelled || Task.isCancelled { break }
            let mutableContact = contactResult.contact.makeMutableCopy()
            pendingBatch.append((contactResult, mutableContact))

            if pendingBatch.count == Self.deleteBatchSize {
                await flushPendingDeletes()
            }
        }

        if !isDeleteCancelled && !Task.isCancelled {
            await flushPendingDeletes()
        }

        if !succeededContacts.isEmpty {
            removeDeletedContactsFromResult(deletedContacts: succeededContacts)
        }

        deleteProgress = 1.0

        if failedCount > 0 {
            let reason = errorMessage(for: firstError)
            if succeededContacts.isEmpty {
                alertMessage = reason
            } else {
                alertMessage = "已删除 \(succeededContacts.count) 位重复联系人，\(failedCount) 位删除失败：\(reason)"
            }
            showingAlert = true
        }

        return DuplicateDeletionSummary(
            deletedCount: succeededContacts.count,
            failedCount: failedCount
        )
    }

    func clearResults() {
        duplicateResult = DuplicateContactResult()
        detectionProgress = 0.0
    }

    func applyDetectedGroups(_ groups: [DuplicateGroup]) {
        duplicateResult = DuplicateContactResult(
            duplicateGroups: groups,
            hasCompleted: true
        )
        detectionProgress = 1.0
        isDetecting = false
    }

    private func presentError(_ error: Error) {
        alertMessage = errorMessage(for: error)
        showingAlert = true
    }

    private func errorMessage(for error: Error?) -> String {
        guard let error else {
            return NSLocalizedString("Unknown error", comment: "")
        }
        if let contactError = error as? ContactError {
            return contactError.localizedDescription
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func contactDisplayName(for contact: CNContact) -> String {
        let fullName = [contact.givenName, contact.familyName]
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        if fullName.isEmpty == false {
            return fullName
        }

        if contact.organizationName.isEmpty == false {
            return contact.organizationName
        }

        return NSLocalizedString("Unknown Contact", comment: "")
    }

    private func removeDeletedContactsFromResult(deletedContacts: [ContactResult]) {
        let deletedIdentifiers = Set(deletedContacts.map(\.contactIdentifier))

        for index in duplicateResult.duplicateGroups.indices {
            duplicateResult.duplicateGroups[index].contacts.removeAll { contact in
                deletedIdentifiers.contains(contact.contactIdentifier)
            }
            duplicateResult.duplicateGroups[index].selectedContacts.removeAll()
        }

        duplicateResult.duplicateGroups.removeAll { group in
            group.contacts.count <= 1
        }
    }
}
