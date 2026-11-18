import Contacts
import Foundation

struct AvatarDeletionResult {
    let successCount: Int
    let failureCount: Int
}

protocol ContactAvatarDeleting {
    func deleteAllContactAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> AvatarDeletionResult
    func loadContactsWithAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> [CNContact]
    func deleteSelectedAvatars(
        identifiers: [String],
        keysToFetch: [CNKeyDescriptor],
        progressHandler: @escaping @MainActor (Int) -> Void
    ) async throws -> AvatarDeletionResult
}

final class ContactAvatarDeletionUseCase: ContactAvatarDeleting {
    private static let writeBatchSize = 200

    private let contactService: any ContactServing

    init(contactService: any ContactServing = ContactService.shared) {
        self.contactService = contactService
    }

    func deleteAllContactAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> AvatarDeletionResult {
        let contacts = try await contactService.fetchContacts(keys: keysToFetch, sortOrder: .givenName)
        var successCount = 0
        var failureCount = 0
        var pendingUpdates: [CNMutableContact] = []

        func flushPendingUpdates() async {
            let results = await executeBestEffortUpdateBatch(&pendingUpdates)

            for result in results {
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    failureCount += 1
                }
            }
        }

        for contact in contacts where contact.hasAvatarImage {
            let mutableContact = contact.makeMutableCopy()
            mutableContact.imageData = nil
            pendingUpdates.append(mutableContact)

            if pendingUpdates.count == Self.writeBatchSize {
                await flushPendingUpdates()
            }
        }

        await flushPendingUpdates()

        return AvatarDeletionResult(successCount: successCount, failureCount: failureCount)
    }

    func loadContactsWithAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> [CNContact] {
        let contacts = try await contactService.fetchContacts(keys: keysToFetch, sortOrder: .givenName)
        return contacts.filter(\.hasAvatarImage)
    }

    func deleteSelectedAvatars(
        identifiers: [String],
        keysToFetch: [CNKeyDescriptor],
        progressHandler: @escaping @MainActor (Int) -> Void
    ) async throws -> AvatarDeletionResult {
        guard identifiers.isEmpty == false else {
            return AvatarDeletionResult(successCount: 0, failureCount: 0)
        }

        let resolvedContacts = await resolveContacts(identifiers: identifiers, keysToFetch: keysToFetch)
        var successCount = 0
        var failureCount = 0
        var pendingUpdates: [CNMutableContact] = []
        var throttler = ProgressThrottler(interval: .milliseconds(80))
        let totalCount = identifiers.count

        func flushPendingUpdates() async {
            let results = await executeBestEffortUpdateBatch(&pendingUpdates)

            for result in results {
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    failureCount += 1
                }
            }
        }

        for (index, identifier) in identifiers.enumerated() {
            try Task.checkCancellation()
            let completedCount = index + 1
            if throttler.shouldEmit(force: completedCount == totalCount) {
                await progressHandler(completedCount)
            }

            switch resolvedContacts[identifier] {
            case .success(let contact):
                let mutableContact = contact.makeMutableCopy()
                mutableContact.imageData = nil
                pendingUpdates.append(mutableContact)

                if pendingUpdates.count == Self.writeBatchSize {
                    await flushPendingUpdates()
                }
            case .failure, .none:
                failureCount += 1
            }
        }

        await flushPendingUpdates()

        return AvatarDeletionResult(successCount: successCount, failureCount: failureCount)
    }

    private func resolveContacts(
        identifiers: [String],
        keysToFetch: [CNKeyDescriptor]
    ) async -> [String: Result<CNContact, Error>] {
        let uniqueIdentifiers = Array(Set(identifiers))
        guard uniqueIdentifiers.isEmpty == false else { return [:] }

        do {
            let fetched = try await contactService.fetchUnifiedContacts(
                identifiers: uniqueIdentifiers,
                keys: keysToFetch
            )
            var results: [String: Result<CNContact, Error>] = [:]
            results.reserveCapacity(uniqueIdentifiers.count)

            for identifier in uniqueIdentifiers {
                if let contact = fetched[identifier] {
                    results[identifier] = .success(contact)
                } else {
                    do {
                        let fallback = try await contactService.fetchUnifiedContact(
                            identifier: identifier,
                            keys: keysToFetch
                        )
                        results[identifier] = .success(fallback)
                    } catch {
                        results[identifier] = .failure(error)
                    }
                }
            }
            return results
        } catch {
            var results: [String: Result<CNContact, Error>] = [:]
            results.reserveCapacity(uniqueIdentifiers.count)

            for identifier in uniqueIdentifiers {
                do {
                    let fallback = try await contactService.fetchUnifiedContact(
                        identifier: identifier,
                        keys: keysToFetch
                    )
                    results[identifier] = .success(fallback)
                } catch {
                    results[identifier] = .failure(error)
                }
            }
            return results
        }
    }

    private func executeBestEffortUpdateBatch(
        _ pendingBatch: inout [CNMutableContact]
    ) async -> [Result<Void, Error>] {
        guard pendingBatch.isEmpty == false else { return [] }

        let batch = pendingBatch
        pendingBatch.removeAll(keepingCapacity: true)

        do {
            try await contactService.updateContacts(batch)
            return Array(repeating: .success(()), count: batch.count)
        } catch {
            return await executeIndividually(batch, using: contactService.updateContact)
        }
    }

    private func executeIndividually(
        _ contacts: [CNMutableContact],
        using operation: (CNMutableContact) async throws -> Void
    ) async -> [Result<Void, Error>] {
        var results: [Result<Void, Error>] = []
        results.reserveCapacity(contacts.count)

        for contact in contacts {
            do {
                try await operation(contact)
                results.append(.success(()))
            } catch {
                results.append(.failure(error))
            }
        }

        return results
    }
}
