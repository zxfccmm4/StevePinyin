import Contacts

struct AvatarImportProgress {
    let contactName: String
    let currentIndex: Int
    let totalCount: Int
    let progress: Double
}

struct AvatarImportResult {
    let successCount: Int
    let failureCount: Int
    let errors: [String]
}

final class ContactAvatarImportUseCase {
    private static let writeBatchSize = 200

    private struct PendingImportUpdate {
        let contactName: String
        let contact: CNMutableContact
    }

    private struct ImportBatchOutcome {
        let contactName: String
        let error: Error?
    }

    private let contactService: any ContactServing
    private let imageDataResolver: any AvatarImageDataResolving
    private let delayNanoseconds: UInt64
    private let contactKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
    ]

    init(
        contactService: any ContactServing = ContactService.shared,
        imageDataResolver: any AvatarImageDataResolving = AvatarImageDataResolverUseCase(),
        delayNanoseconds: UInt64 = 0
    ) {
        self.contactService = contactService
        self.imageDataResolver = imageDataResolver
        self.delayNanoseconds = delayNanoseconds
    }

    func importAvatars(
        matches: [(CNContact, Icon)],
        progressHandler: @escaping @MainActor (AvatarImportProgress) -> Void
    ) async -> AvatarImportResult {
        guard !matches.isEmpty else {
            return AvatarImportResult(successCount: 0, failureCount: 0, errors: [])
        }

        return await PerformanceMonitor.shared.trackBatchImport(contactCount: matches.count) {
            await performImportAvatars(
                matches: matches,
                progressHandler: progressHandler
            )
        }
    }

    private func performImportAvatars(
        matches: [(CNContact, Icon)],
        progressHandler: @escaping @MainActor (AvatarImportProgress) -> Void
    ) async -> AvatarImportResult {

        let totalMatches = matches.count
        let resolvedImageData = await resolveImageData(for: matches.map(\.1))
        let contactResultsByIdentifier = await resolveContacts(for: matches.map(\.0))
        var successCount = 0
        var failureCount = 0
        var errors: [String] = []
        var pendingUpdates: [PendingImportUpdate] = []

        func flushPendingUpdates() async {
            let outcomes = await executeBestEffortUpdateBatch(&pendingUpdates)

            for outcome in outcomes {
                if let error = outcome.error {
                    failureCount += 1
                    errors.append(String(
                        format: NSLocalizedString("Failed to process contact %@: %@", comment: ""),
                        outcome.contactName,
                        error.localizedDescription
                    ))
                } else {
                    successCount += 1
                    if delayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: delayNanoseconds)
                    }
                }
            }
        }

        var throttler = ProgressThrottler(interval: .milliseconds(80))

        for (index, (contact, icon)) in matches.enumerated() {
            if Task.isCancelled { break }
            let contactName = Self.getContactDisplayName(contact)
            let isLast = (index + 1 == totalMatches)
            if throttler.shouldEmit(force: isLast) {
                let progress = AvatarImportProgress(
                    contactName: contactName,
                    currentIndex: index + 1,
                    totalCount: totalMatches,
                    progress: Double(index + 1) / Double(totalMatches)
                )
                await progressHandler(progress)
            }
            do {
                let fullContact = try contactResultsByIdentifier[contact.stableIdentifier]?.get()
                    ?? {
                        throw NSError(
                            domain: "AvatarError",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Contact data could not be loaded", comment: "")]
                        )
                    }()

                let mutableContact = fullContact.makeMutableCopy()
                guard let resolvedResult = resolvedImageData[icon] else {
                    throw NSError(
                        domain: "AvatarError",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Image data was not prepared", comment: "")]
                    )
                }
                let imageData = try resolvedResult.get()

                guard !imageData.isEmpty else {
                    failureCount += 1
                    errors.append(String(format: NSLocalizedString("Could not get valid image data: %@", comment: ""), contactName))
                    continue
                }

                mutableContact.imageData = imageData
                pendingUpdates.append(.init(contactName: contactName, contact: mutableContact))

                if pendingUpdates.count == Self.writeBatchSize {
                    await flushPendingUpdates()
                }
            } catch {
                failureCount += 1
                errors.append(String(format: NSLocalizedString("Failed to process contact %@: %@", comment: ""), contactName, error.localizedDescription))
            }
        }

        await flushPendingUpdates()

        return AvatarImportResult(
            successCount: successCount,
            failureCount: failureCount,
            errors: errors
        )
    }

    static func getContactDisplayName(_ contact: CNContact) -> String {
        let name = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let hasOrganization = contact.isKeyAvailable(CNContactOrganizationNameKey) && !contact.organizationName.isEmpty

        if hasOrganization {
            return contact.organizationName
        } else if !name.isEmpty {
            return name
        } else {
            return NSLocalizedString("Unknown Contact", comment: "")
        }
    }

    private func resolveContacts(for contacts: [CNContact]) async -> [String: Result<CNContact, Error>] {
        let identifiers = Array(Set(contacts.map(\.stableIdentifier)))
        guard identifiers.isEmpty == false else { return [:] }

        do {
            let fetchedContacts = try await contactService.fetchUnifiedContacts(
                identifiers: identifiers,
                keys: contactKeys
            )
            var results = identifiers.reduce(into: [String: Result<CNContact, Error>]()) { partialResult, identifier in
                if let contact = fetchedContacts[identifier] {
                    partialResult[identifier] = .success(contact)
                }
            }

            let missingIdentifiers = identifiers.filter { results[$0] == nil }
            if missingIdentifiers.isEmpty {
                return results
            }

            for identifier in missingIdentifiers {
                do {
                    let contact = try await contactService.fetchUnifiedContact(
                        identifier: identifier,
                        keys: contactKeys
                    )
                    results[identifier] = .success(contact)
                } catch {
                    results[identifier] = .failure(error)
                }
            }

            return results
        } catch {
            var results: [String: Result<CNContact, Error>] = [:]

            for identifier in identifiers {
                do {
                    let contact = try await contactService.fetchUnifiedContact(
                        identifier: identifier,
                        keys: contactKeys
                    )
                    results[identifier] = .success(contact)
                } catch {
                    results[identifier] = .failure(error)
                }
            }

            return results
        }
    }

    private func executeBestEffortUpdateBatch(
        _ pendingBatch: inout [PendingImportUpdate]
    ) async -> [ImportBatchOutcome] {
        guard pendingBatch.isEmpty == false else { return [] }

        let batch = pendingBatch
        pendingBatch.removeAll(keepingCapacity: true)

        do {
            try await contactService.updateContacts(batch.map(\.contact))
            return batch.map { ImportBatchOutcome(contactName: $0.contactName, error: nil) }
        } catch {
            var outcomes: [ImportBatchOutcome] = []
            outcomes.reserveCapacity(batch.count)

            for item in batch {
                do {
                    try await contactService.updateContact(item.contact)
                    outcomes.append(ImportBatchOutcome(contactName: item.contactName, error: nil))
                } catch {
                    outcomes.append(ImportBatchOutcome(contactName: item.contactName, error: error))
                }
            }

            return outcomes
        }
    }

    private func resolveImageData(for icons: [Icon]) async -> [Icon: Result<Data, Error>] {
        let uniqueIcons = Array(Set(icons))
        guard uniqueIcons.isEmpty == false else { return [:] }

        return await withTaskGroup(of: (Icon, Result<Data, Error>).self) { group in
            for icon in uniqueIcons {
                group.addTask { [imageDataResolver] in
                    do {
                        return (icon, .success(try await imageDataResolver.imageData(for: icon)))
                    } catch {
                        return (icon, .failure(error))
                    }
                }
            }

            var resolvedData: [Icon: Result<Data, Error>] = [:]
            for await (icon, result) in group {
                resolvedData[icon] = result
            }
            return resolvedData
        }
    }
}
