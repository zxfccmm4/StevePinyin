import Foundation
@preconcurrency import Contacts

extension CNAuthorizationStatus {
    var allowsContactDataAccess: Bool {
        if self == .authorized {
            return true
        }

        if #available(iOS 18.0, *), self == .limited {
            return true
        }

        return false
    }
}

enum ContactError: Error {
    case accessDenied
    case fetchFailed(Error)
    case updateFailed(Error)
    case invalidContact
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .accessDenied:
            return NSLocalizedString("Access to contacts was denied", comment: "Error message when access to contacts is denied")
        case .fetchFailed(let error):
            return String(format: NSLocalizedString("Failed to fetch contacts: %@", comment: "Error message when fetching contacts fails"), error.localizedDescription)
        case .updateFailed(let error):
            return String(format: NSLocalizedString("Failed to update contact: %@", comment: "Error message when updating contact fails"), error.localizedDescription)
        case .invalidContact:
            return NSLocalizedString("Invalid contact data", comment: "Error message for invalid contact")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

protocol ContactServing {
    func requestAccess() async throws -> Bool
    func fetchContacts(
        keys: [CNKeyDescriptor],
        sortOrder: CNContactSortOrder
    ) async throws -> [CNContact]
    func updateContact(_ contact: CNMutableContact) async throws
    func updateContacts(_ contacts: [CNMutableContact]) async throws
    func fetchUnifiedContact(identifier: String, keys: [CNKeyDescriptor]) async throws -> CNContact
    func fetchUnifiedContacts(identifiers: [String], keys: [CNKeyDescriptor]) async throws -> [String: CNContact]
    func deleteContact(_ contact: CNMutableContact) async throws
    func deleteContacts(_ contacts: [CNMutableContact]) async throws
}

actor ContactService: ContactServing {
    static let shared = ContactService()
    private static let writeBatchSize = 200
    private let store = CNContactStore()
    
    private init() {}
    
    func requestAccess() async throws -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            throw ContactError.accessDenied
        }
    }
    
    func fetchContacts(
        keys: [CNKeyDescriptor],
        sortOrder: CNContactSortOrder = .givenName
    ) async throws -> [CNContact] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status.allowsContactDataAccess else {
            throw ContactError.accessDenied
        }
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = sortOrder
        var contacts: [CNContact] = []
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            return contacts
        } catch {
            throw ContactError.fetchFailed(error)
        }
    }
    
    func updateContact(_ contact: CNMutableContact) async throws {
        let saveRequest = CNSaveRequest()
        saveRequest.update(contact)
        
        do {
            try store.execute(saveRequest)
        } catch {
            throw ContactError.updateFailed(error)
        }
    }

    func updateContacts(_ contacts: [CNMutableContact]) async throws {
        try executeBatchedSave(
            contacts,
            errorTransform: ContactError.updateFailed
        ) { saveRequest, contact in
            saveRequest.update(contact)
        }
    }

    func fetchUnifiedContact(identifier: String, keys: [CNKeyDescriptor]) async throws -> CNContact {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status.allowsContactDataAccess else {
            throw ContactError.accessDenied
        }

        do {
            return try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
        } catch {
            throw ContactError.fetchFailed(error)
        }
    }

    func fetchUnifiedContacts(identifiers: [String], keys: [CNKeyDescriptor]) async throws -> [String: CNContact] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status.allowsContactDataAccess else {
            throw ContactError.accessDenied
        }

        guard identifiers.isEmpty == false else {
            return [:]
        }

        do {
            let requestedIdentifierSet = Set(identifiers)
            let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

            var contactsByIdentifier = Dictionary(
                uniqueKeysWithValues: contacts.compactMap { contact -> (String, CNContact)? in
                    guard requestedIdentifierSet.contains(contact.identifier) else {
                        return nil
                    }
                    return (contact.identifier, contact)
                }
            )

            let missingIdentifiers = identifiers.filter { contactsByIdentifier[$0] == nil }
            for identifier in missingIdentifiers {
                contactsByIdentifier[identifier] = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
            }

            return contactsByIdentifier
        } catch {
            throw ContactError.fetchFailed(error)
        }
    }

    func deleteContact(_ contact: CNMutableContact) async throws {
        let saveRequest = CNSaveRequest()
        saveRequest.delete(contact)

        do {
            try store.execute(saveRequest)
        } catch {
            throw ContactError.updateFailed(error)
        }
    }

    func deleteContacts(_ contacts: [CNMutableContact]) async throws {
        try executeBatchedSave(
            contacts,
            errorTransform: ContactError.updateFailed
        ) { saveRequest, contact in
            saveRequest.delete(contact)
        }
    }
    
    func authorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }

    private func executeBatchedSave(
        _ contacts: [CNMutableContact],
        errorTransform: (Error) -> ContactError,
        mutation: (CNSaveRequest, CNMutableContact) -> Void
    ) throws {
        guard contacts.isEmpty == false else { return }

        for batch in contacts.chunked(into: Self.writeBatchSize) {
            let saveRequest = CNSaveRequest()

            for contact in batch {
                mutation(saveRequest, contact)
            }

            do {
                try store.execute(saveRequest)
            } catch {
                throw errorTransform(error)
            }
        }
    }
}
