import Foundation
@preconcurrency import Contacts

struct ContactsPinyinMaintenanceUseCase {
    struct Progress {
        let processedCount: Int
        let totalCount: Int
        let processedContact: ContactResult?
    }

    struct AddPinyinResult {
        let successCount: Int
        let failureCount: Int
        let skippedEnglishCount: Int
        let failureReasons: [String: Int]
        let processedContacts: [ContactResult]
    }

    struct RemovePinyinResult {
        let removedCount: Int
        let processedContacts: [ContactResult]

        init(removedCount: Int, processedContacts: [ContactResult] = []) {
            self.removedCount = removedCount
            self.processedContacts = processedContacts
        }
    }

    struct EnableT9Result {
        let successCount: Int
        let failureCount: Int
        let failureReasons: [String: Int]
    }

    struct CleanupNoPhoneContactsResult {
        let foundCount: Int
        let successCount: Int
        let failureCount: Int
        let failureReasons: [String: Int]
    }

    private static let writeBatchSize = 200

    private struct ContactWriteBatchItem<Payload> {
        let payload: Payload
        let contact: CNMutableContact
    }

    private struct BatchOutcome<Payload> {
        let payload: Payload
        let error: Error?
    }

    private let contactService: any ContactServing
    private let transformer: ContactPinyinTransformer

    init(
        contactService: any ContactServing = ContactService.shared,
        transformer: ContactPinyinTransformer = .shared
    ) {
        self.contactService = contactService
        self.transformer = transformer
    }

    func addPinyin(
        format: PinyinFormat,
        progressHandler: @escaping @MainActor (Progress) -> Void
    ) async throws -> AddPinyinResult {
        try await PerformanceMonitor.shared.trackPinyinMaintenance(
            actionName: "批量添加拼音",
            format: format.rawValue
        ) {
            let keysToFetch = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneticGivenNameKey,
                CNContactPhoneticFamilyNameKey,
                CNContactOrganizationNameKey,
                CNContactPhoneticOrganizationNameKey,
                CNContactThumbnailImageDataKey,
            ] as [CNKeyDescriptor]

            let contacts = try await contactService.fetchContacts(
                keys: keysToFetch,
                sortOrder: .givenName
            )
            let totalCount = contacts.count
            var throttler = ProgressThrottler(interval: .milliseconds(80))
            await progressHandler(.init(processedCount: 0, totalCount: totalCount, processedContact: nil))

            var successCount = 0
            var failureCount = 0
            var skippedEnglishCount = 0
            var failureReasons: [String: Int] = [:]
            var processedCount = 0
            var collectedContacts: [ContactResult] = []
            collectedContacts.reserveCapacity(totalCount)
            var pendingUpdates: [ContactWriteBatchItem<ContactResult>] = []

            func flushPendingUpdates() async throws {
                try Task.checkCancellation()
                let outcomes = await executeBestEffortUpdateBatch(&pendingUpdates)

                for outcome in outcomes {
                    processedCount += 1
                    if let error = outcome.error {
                        failureCount += 1
                        failureReasons[error.localizedDescription, default: 0] += 1
                    } else {
                        successCount += 1
                        collectedContacts.append(outcome.payload)
                    }
                }

                if outcomes.isEmpty == false,
                   throttler.shouldEmit(force: processedCount == totalCount) {
                    await progressHandler(.init(
                        processedCount: processedCount,
                        totalCount: totalCount,
                        processedContact: nil
                    ))
                }
            }

            for contact in contacts {
                try Task.checkCancellation()

                if transformer.shouldSkipEnglishOnlyContact(contact) {
                    skippedEnglishCount += 1
                    processedCount += 1
                    if throttler.shouldEmit(force: processedCount == totalCount) {
                        await progressHandler(.init(
                            processedCount: processedCount,
                            totalCount: totalCount,
                            processedContact: nil
                        ))
                    }
                    continue
                }

                let converted = transformer.convert(contact, format: format)
                let mutableContact = contact.makeMutableCopy()
                mutableContact.phoneticFamilyName = converted.familyNamePinyin
                mutableContact.phoneticGivenName = converted.givenNamePinyin
                mutableContact.phoneticOrganizationName = converted.companyPinyin

                var resultContact = ContactResult(from: contact)
                resultContact.pinyin = converted.displayPinyin
                resultContact.companyPinyin = converted.companyPinyin.trimmingCharacters(in: .whitespaces)

                pendingUpdates.append(.init(payload: resultContact, contact: mutableContact))

                if pendingUpdates.count == Self.writeBatchSize {
                    try await flushPendingUpdates()
                }
            }

            try await flushPendingUpdates()

            if processedCount == totalCount {
                await progressHandler(.init(processedCount: totalCount, totalCount: totalCount, processedContact: nil))
            }

            return AddPinyinResult(
                successCount: successCount,
                failureCount: failureCount,
                skippedEnglishCount: skippedEnglishCount,
                failureReasons: failureReasons,
                processedContacts: collectedContacts
            )
        }
    }

    func removePinyin(
        progressHandler: @escaping @MainActor (Progress) -> Void
    ) async throws -> RemovePinyinResult {
        try await PerformanceMonitor.shared.trackPinyinMaintenance(actionName: "清除拼音与T9") {
            let keysToFetch = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneticGivenNameKey,
                CNContactPhoneticFamilyNameKey,
                CNContactOrganizationNameKey,
                CNContactPhoneticOrganizationNameKey,
                CNContactNicknameKey,
                CNContactThumbnailImageDataKey,
            ] as [CNKeyDescriptor]

            let contacts = try await contactService.fetchContacts(
                keys: keysToFetch,
                sortOrder: .givenName
            )
            let totalCount = contacts.count
            var throttler = ProgressThrottler(interval: .milliseconds(80))
            await progressHandler(.init(processedCount: 0, totalCount: totalCount, processedContact: nil))

            var removedCount = 0
            var processedCount = 0
            var collectedContacts: [ContactResult] = []
            collectedContacts.reserveCapacity(totalCount)
            var pendingUpdates: [ContactWriteBatchItem<ContactResult>] = []

            func flushPendingUpdates() async throws {
                try Task.checkCancellation()
                let processedContacts = try await executeStrictUpdateBatch(&pendingUpdates)
                guard processedContacts.isEmpty == false else { return }

                removedCount += processedContacts.count
                processedCount += processedContacts.count
                collectedContacts.append(contentsOf: processedContacts)

                if throttler.shouldEmit(force: processedCount == totalCount) {
                    await progressHandler(.init(
                        processedCount: processedCount,
                        totalCount: totalCount,
                        processedContact: nil
                    ))
                }
            }

            for contact in contacts {
                try Task.checkCancellation()
                let mutableContact = contact.makeMutableCopy()
                mutableContact.phoneticFamilyName = ""
                mutableContact.phoneticGivenName = ""
                mutableContact.phoneticOrganizationName = ""
                mutableContact.nickname = ""

                var resultContact = ContactResult(from: contact)
                resultContact.pinyin = ""
                resultContact.companyPinyin = ""

                pendingUpdates.append(.init(payload: resultContact, contact: mutableContact))

                if pendingUpdates.count == Self.writeBatchSize {
                    try await flushPendingUpdates()
                }
            }

            try await flushPendingUpdates()
            return RemovePinyinResult(removedCount: removedCount, processedContacts: collectedContacts)
        }
    }

    func enableT9(
        format: PinyinFormat,
        progressHandler: @escaping @MainActor (Progress) -> Void
    ) async throws -> EnableT9Result {
        try await PerformanceMonitor.shared.trackPinyinMaintenance(
            actionName: "开启T9拨号搜索",
            format: format.rawValue
        ) {
            let keysToFetch = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactNicknameKey,
                CNContactOrganizationNameKey,
            ] as [CNKeyDescriptor]

            let contacts = try await contactService.fetchContacts(
                keys: keysToFetch,
                sortOrder: .givenName
            )
            let totalCount = contacts.count
            var throttler = ProgressThrottler(interval: .milliseconds(80))
            await progressHandler(.init(processedCount: 0, totalCount: totalCount, processedContact: nil))

            var successCount = 0
            var failureCount = 0
            var failureReasons: [String: Int] = [:]
            var processedCount = 0
            var pendingUpdates: [ContactWriteBatchItem<Void>] = []

            func flushPendingUpdates() async throws {
                try Task.checkCancellation()
                let outcomes = await executeBestEffortUpdateBatch(&pendingUpdates)

                for outcome in outcomes {
                    processedCount += 1
                    if let error = outcome.error {
                        failureCount += 1
                        failureReasons[error.localizedDescription, default: 0] += 1
                    } else {
                        successCount += 1
                    }
                }

                if outcomes.isEmpty == false,
                   throttler.shouldEmit(force: processedCount == totalCount) {
                    await progressHandler(.init(
                        processedCount: processedCount,
                        totalCount: totalCount,
                        processedContact: nil
                    ))
                }
            }
            for contact in contacts {
                try Task.checkCancellation()
                let mutableContact = contact.makeMutableCopy()
                mutableContact.nickname = transformer.buildNickname(for: contact, format: format)
                pendingUpdates.append(.init(payload: (), contact: mutableContact))

                if pendingUpdates.count == Self.writeBatchSize {
                    try await flushPendingUpdates()
                }
            }

            try await flushPendingUpdates()

            return EnableT9Result(
                successCount: successCount,
                failureCount: failureCount,
                failureReasons: failureReasons
            )
        }
    }

    func removePinyinOnly(
        progressHandler: @escaping @MainActor (Progress) -> Void
    ) async throws -> RemovePinyinResult {
        try await PerformanceMonitor.shared.trackPinyinMaintenance(actionName: "仅清除拼音") {
            let keysToFetch = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneticGivenNameKey,
                CNContactPhoneticFamilyNameKey,
                CNContactOrganizationNameKey,
                CNContactPhoneticOrganizationNameKey,
            ] as [CNKeyDescriptor]

            let contacts = try await contactService.fetchContacts(
                keys: keysToFetch,
                sortOrder: .givenName
            )
            let totalCount = contacts.count
            var throttler = ProgressThrottler(interval: .milliseconds(80))
            await progressHandler(.init(processedCount: 0, totalCount: totalCount, processedContact: nil))

            var removedCount = 0
            var processedCount = 0
            var pendingUpdates: [ContactWriteBatchItem<Void>] = []

            func flushPendingUpdates() async throws {
                try Task.checkCancellation()
                let processedItemCount = try await executeStrictUpdateBatch(&pendingUpdates).count
                guard processedItemCount > 0 else { return }
                removedCount += processedItemCount
                processedCount += processedItemCount
                if throttler.shouldEmit(force: processedCount == totalCount) {
                    await progressHandler(.init(
                        processedCount: processedCount,
                        totalCount: totalCount,
                        processedContact: nil
                    ))
                }
            }

            for contact in contacts {
                try Task.checkCancellation()
                let mutableContact = contact.makeMutableCopy()
                mutableContact.phoneticFamilyName = ""
                mutableContact.phoneticGivenName = ""
                mutableContact.phoneticOrganizationName = ""
                pendingUpdates.append(.init(payload: (), contact: mutableContact))

                if pendingUpdates.count == Self.writeBatchSize {
                    try await flushPendingUpdates()
                }
            }

            try await flushPendingUpdates()
            return RemovePinyinResult(removedCount: removedCount)
        }
    }

    func removeT9Only(
        progressHandler: @escaping @MainActor (Progress) -> Void
    ) async throws -> RemovePinyinResult {
        try await PerformanceMonitor.shared.trackPinyinMaintenance(actionName: "仅清除T9搜索") {
            let keysToFetch = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactNicknameKey,
            ] as [CNKeyDescriptor]

            let contacts = try await contactService.fetchContacts(
                keys: keysToFetch,
                sortOrder: .givenName
            )
            let totalCount = contacts.count
            var throttler = ProgressThrottler(interval: .milliseconds(80))
            await progressHandler(.init(processedCount: 0, totalCount: totalCount, processedContact: nil))

            var removedCount = 0
            var processedCount = 0
            var pendingUpdates: [ContactWriteBatchItem<Void>] = []

            func flushPendingUpdates() async throws {
                try Task.checkCancellation()
                let processedItemCount = try await executeStrictUpdateBatch(&pendingUpdates).count
                guard processedItemCount > 0 else { return }
                removedCount += processedItemCount
                processedCount += processedItemCount
                if throttler.shouldEmit(force: processedCount == totalCount) {
                    await progressHandler(.init(
                        processedCount: processedCount,
                        totalCount: totalCount,
                        processedContact: nil
                    ))
                }
            }

            for contact in contacts {
                try Task.checkCancellation()
                let mutableContact = contact.makeMutableCopy()
                mutableContact.nickname = ""
                pendingUpdates.append(.init(payload: (), contact: mutableContact))

                if pendingUpdates.count == Self.writeBatchSize {
                    try await flushPendingUpdates()
                }
            }

            try await flushPendingUpdates()
            return RemovePinyinResult(removedCount: removedCount)
        }
    }

    func cleanupContactsWithoutPhoneNumbers(
        progressHandler: @escaping @MainActor (Progress) -> Void
    ) async throws -> CleanupNoPhoneContactsResult {
        try await PerformanceMonitor.shared.trackPinyinMaintenance(actionName: "清理无电话联系人") {
            let keysToFetch = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactOrganizationNameKey,
                CNContactPhoneNumbersKey,
            ] as [CNKeyDescriptor]

            let contacts = try await contactService.fetchContacts(
                keys: keysToFetch,
                sortOrder: .givenName
            )
            let contactsToDelete = contacts.filter { $0.phoneNumbers.isEmpty }
            let totalCount = contactsToDelete.count
            var throttler = ProgressThrottler(interval: .milliseconds(80))
            await progressHandler(.init(processedCount: 0, totalCount: totalCount, processedContact: nil))

            var successCount = 0
            var failureCount = 0
            var failureReasons: [String: Int] = [:]
            var processedCount = 0
            var pendingDeletes: [ContactWriteBatchItem<Void>] = []

            func flushPendingDeletes() async throws {
                try Task.checkCancellation()
                let outcomes = await executeBestEffortDeleteBatch(&pendingDeletes)

                for outcome in outcomes {
                    processedCount += 1
                    if let error = outcome.error {
                        failureCount += 1
                        failureReasons[error.localizedDescription, default: 0] += 1
                    } else {
                        successCount += 1
                    }
                }

                if outcomes.isEmpty == false,
                   throttler.shouldEmit(force: processedCount == totalCount) {
                    await progressHandler(.init(
                        processedCount: processedCount,
                        totalCount: totalCount,
                        processedContact: nil
                    ))
                }
            }

            for contact in contactsToDelete {
                try Task.checkCancellation()
                pendingDeletes.append(.init(payload: (), contact: contact.makeMutableCopy()))

                if pendingDeletes.count == Self.writeBatchSize {
                    try await flushPendingDeletes()
                }
            }

            try await flushPendingDeletes()

            return CleanupNoPhoneContactsResult(
                foundCount: totalCount,
                successCount: successCount,
                failureCount: failureCount,
                failureReasons: failureReasons
            )
        }
    }

    private func executeBestEffortUpdateBatch<Payload>(
        _ pendingBatch: inout [ContactWriteBatchItem<Payload>]
    ) async -> [BatchOutcome<Payload>] {
        guard pendingBatch.isEmpty == false else { return [] }

        let batch = pendingBatch
        pendingBatch.removeAll(keepingCapacity: true)

        do {
            try await contactService.updateContacts(batch.map(\.contact))
            return batch.map { BatchOutcome(payload: $0.payload, error: nil) }
        } catch {
            var outcomes: [BatchOutcome<Payload>] = []
            outcomes.reserveCapacity(batch.count)

            for item in batch {
                do {
                    try await contactService.updateContact(item.contact)
                    outcomes.append(BatchOutcome(payload: item.payload, error: nil))
                } catch {
                    outcomes.append(BatchOutcome(payload: item.payload, error: error))
                }
            }

            return outcomes
        }
    }

    private func executeStrictUpdateBatch<Payload>(
        _ pendingBatch: inout [ContactWriteBatchItem<Payload>]
    ) async throws -> [Payload] {
        guard pendingBatch.isEmpty == false else { return [] }

        let batch = pendingBatch
        pendingBatch.removeAll(keepingCapacity: true)

        try await contactService.updateContacts(batch.map(\.contact))
        return batch.map(\.payload)
    }

    private func executeBestEffortDeleteBatch<Payload>(
        _ pendingBatch: inout [ContactWriteBatchItem<Payload>]
    ) async -> [BatchOutcome<Payload>] {
        guard pendingBatch.isEmpty == false else { return [] }

        let batch = pendingBatch
        pendingBatch.removeAll(keepingCapacity: true)

        do {
            try await contactService.deleteContacts(batch.map(\.contact))
            return batch.map { BatchOutcome(payload: $0.payload, error: nil) }
        } catch {
            var outcomes: [BatchOutcome<Payload>] = []
            outcomes.reserveCapacity(batch.count)

            for item in batch {
                do {
                    try await contactService.deleteContact(item.contact)
                    outcomes.append(BatchOutcome(payload: item.payload, error: nil))
                } catch {
                    outcomes.append(BatchOutcome(payload: item.payload, error: error))
                }
            }

            return outcomes
        }
    }
}
