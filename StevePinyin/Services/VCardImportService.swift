import Contacts
import Foundation

enum VCardImportError: Error {
    case permissionDenied
    case invalidServerResponse
    case serverStatusCode(Int)
    case emptyData
    case emptyFile
    case noContacts
}

actor VCardImportService {
    static let groupName = "StevePinyin vCards"

    private let store = CNContactStore()

    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    func downloadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VCardImportError.invalidServerResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw VCardImportError.serverStatusCode(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw VCardImportError.emptyData
        }

        return data
    }

    func importContacts(from data: Data) async throws -> [CNContact] {
        try await PerformanceMonitor.shared.trackVCardImport(source: "vCard Data (\(data.count) bytes)") {
            try importContactsSynchronously(from: data)
        }
    }

    private func importContactsSynchronously(from data: Data) throws -> [CNContact] {
        guard !data.isEmpty else {
            throw VCardImportError.emptyData
        }

        try ensureAuthorized()

        let contacts = try CNContactVCardSerialization.contacts(with: data)
        guard !contacts.isEmpty else {
            throw VCardImportError.noContacts
        }

        let group = try ensureVCardGroup()
        let saveRequest = CNSaveRequest()

        for contact in contacts {
            let mutableContact = contact.makeMutableCopy()
            saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
            saveRequest.addMember(mutableContact, to: group)
        }

        try store.execute(saveRequest)
        return contacts
    }

    func importContactsWithProgress(
        from data: Data,
        progressHandler: @escaping @MainActor (Int, Int) -> Void
    ) async throws -> [CNContact] {
        try await PerformanceMonitor.shared.trackVCardImport(source: "vCard Batch (\(data.count) bytes)") {
            guard !data.isEmpty else {
                throw VCardImportError.emptyData
            }

            try ensureAuthorized()

            let contacts = try CNContactVCardSerialization.contacts(with: data)
            guard !contacts.isEmpty else {
                throw VCardImportError.noContacts
            }

            let group = try ensureVCardGroup()
            let totalCount = contacts.count
            let batchSize = 50
            var importedContacts: [CNContact] = []
            importedContacts.reserveCapacity(totalCount)
            var throttler = ProgressThrottler(interval: .milliseconds(80))

            await progressHandler(0, totalCount)

            for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
                try Task.checkCancellation()
                let batchEnd = min(batchStart + batchSize, totalCount)
                let batch = contacts[batchStart ..< batchEnd]

                let saveRequest = CNSaveRequest()
                for contact in batch {
                    let mutableContact = contact.makeMutableCopy()
                    saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
                    saveRequest.addMember(mutableContact, to: group)
                }
                try store.execute(saveRequest)

                importedContacts.append(contentsOf: batch)

                if throttler.shouldEmit(force: batchEnd == totalCount) {
                    await progressHandler(batchEnd, totalCount)
                }
            }

            return importedContacts
        }
    }

    func importContacts(fromFileURL fileURL: URL) async throws -> [CNContact] {
        let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            throw VCardImportError.emptyFile
        }
        return try await importContacts(from: data)
    }

    func deleteEmptyNameContacts() throws -> Int {
        try ensureAuthorized()

        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneNumbersKey,
            CNContactUrlAddressesKey,
        ] as [CNKeyDescriptor]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contactsToDelete: [CNContact] = []

        try store.enumerateContacts(with: request) { contact, _ in
            let hasEmptyName = contact.givenName.isEmpty && contact.familyName.isEmpty
            var conditionCount = 0

            if !contact.organizationName.isEmpty { conditionCount += 1 }
            if !contact.phoneNumbers.isEmpty { conditionCount += 1 }
            if !contact.urlAddresses.isEmpty { conditionCount += 1 }

            if hasEmptyName && conditionCount >= 2 {
                contactsToDelete.append(contact)
            }
        }

        guard !contactsToDelete.isEmpty else {
            return 0
        }

        let saveRequest = CNSaveRequest()
        for contact in contactsToDelete {
            saveRequest.delete(contact.makeMutableCopy())
        }
        try store.execute(saveRequest)

        return contactsToDelete.count
    }

    func deleteVCardGroup() throws -> (groupDeleted: Bool, contactsDeleted: Int) {
        try ensureAuthorized()

        guard let group = try findVCardGroup() else {
            return (false, 0)
        }

        // Fetch all contacts in the group
        let memberPredicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        let keysToFetch = [CNContactIdentifierKey] as [CNKeyDescriptor]
        let members = try store.unifiedContacts(matching: memberPredicate, keysToFetch: keysToFetch)

        let saveRequest = CNSaveRequest()

        // Delete all contacts in the group
        for contact in members {
            saveRequest.delete(contact.makeMutableCopy())
        }

        // Delete the group itself
        saveRequest.delete(group.makeMutableCopy())

        try store.execute(saveRequest)
        return (true, members.count)
    }

    private func ensureAuthorized() throws {
        guard CNContactStore.authorizationStatus(for: .contacts).allowsContactDataAccess else {
            throw VCardImportError.permissionDenied
        }
    }

    private func findVCardGroup() throws -> CNGroup? {
        let containers = try store.containers(matching: nil)
        for container in containers {
            let groupPredicate = CNGroup.predicateForGroupsInContainer(withIdentifier: container.identifier)
            let groups = try store.groups(matching: groupPredicate)
            if let found = groups.first(where: { $0.name == Self.groupName }) {
                return found
            }
        }
        return nil
    }

    private func ensureVCardGroup() throws -> CNGroup {
        if let existing = try findVCardGroup() {
            return existing
        }

        let newGroup = CNMutableGroup()
        newGroup.name = Self.groupName
        let createRequest = CNSaveRequest()
        createRequest.add(newGroup, toContainerWithIdentifier: nil)
        try store.execute(createRequest)

        if let created = try findVCardGroup() {
            return created
        }

        return newGroup
    }
}
