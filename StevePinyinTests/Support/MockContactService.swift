import Foundation
@preconcurrency import Contacts
@testable import StevePinyin

enum MockContactServiceError: Error {
    case missingContact
}

actor MockContactService: ContactServing {
    private let requestAccessResult: Bool
    private let fetchedContacts: [CNContact]
    private let unifiedContacts: [String: CNContact]
    private let fetchError: (any Error)?
    private let batchFetchError: (any Error)?
    private let updateError: (any Error)?
    private let batchUpdateError: (any Error)?
    private let deleteError: (any Error)?
    private let batchDeleteError: (any Error)?
    private let failingDeleteIdentifiers: Set<String>

    private var updatedContacts: [CNMutableContact] = []
    private var deletedContacts: [CNMutableContact] = []
    private var unifiedContactFetchCount = 0
    private var unifiedContactsFetchCount = 0
    private var lastFetchedKeyStrings: [String] = []
    private var lastUnifiedFetchKeyStrings: [String] = []

    init(
        requestAccessResult: Bool = true,
        fetchedContacts: [CNContact] = [],
        unifiedContacts: [String: CNContact] = [:],
        fetchError: (any Error)? = nil,
        batchFetchError: (any Error)? = nil,
        updateError: (any Error)? = nil,
        batchUpdateError: (any Error)? = nil,
        deleteError: (any Error)? = nil,
        batchDeleteError: (any Error)? = nil,
        failingDeleteIdentifiers: Set<String> = []
    ) {
        self.requestAccessResult = requestAccessResult
        self.fetchedContacts = fetchedContacts
        self.unifiedContacts = unifiedContacts.isEmpty
            ? Dictionary(
                uniqueKeysWithValues: fetchedContacts.map { contact in
                    (ContactResult(from: contact).contactIdentifier, contact)
                }
            )
            : unifiedContacts
        self.fetchError = fetchError
        self.batchFetchError = batchFetchError
        self.updateError = updateError
        self.batchUpdateError = batchUpdateError
        self.deleteError = deleteError
        self.batchDeleteError = batchDeleteError
        self.failingDeleteIdentifiers = failingDeleteIdentifiers
    }

    func requestAccess() async throws -> Bool {
        requestAccessResult
    }

    func fetchContacts(
        keys: [CNKeyDescriptor],
        sortOrder: CNContactSortOrder
    ) async throws -> [CNContact] {
        lastFetchedKeyStrings = keys.compactMap { $0 as? String }
        if let fetchError {
            throw fetchError
        }

        return fetchedContacts
    }

    func updateContact(_ contact: CNMutableContact) async throws {
        if let updateError {
            throw updateError
        }

        updatedContacts.append(contact.mutableCopy() as! CNMutableContact)
    }

    func updateContacts(_ contacts: [CNMutableContact]) async throws {
        if let batchUpdateError {
            throw batchUpdateError
        }

        if let updateError {
            throw updateError
        }

        updatedContacts.append(contentsOf: contacts.map { $0.mutableCopy() as! CNMutableContact })
    }

    func fetchUnifiedContact(identifier: String, keys: [CNKeyDescriptor]) async throws -> CNContact {
        unifiedContactFetchCount += 1

        lastUnifiedFetchKeyStrings = keys.compactMap { $0 as? String }
        if let fetchError {
            throw fetchError
        }

        guard let contact = unifiedContacts[identifier] else {
            throw MockContactServiceError.missingContact
        }

        return contact
    }

    func fetchUnifiedContacts(identifiers: [String], keys: [CNKeyDescriptor]) async throws -> [String: CNContact] {
        unifiedContactsFetchCount += 1

        if let batchFetchError {
            throw batchFetchError
        }

        if let fetchError {
            throw fetchError
        }

        return try identifiers.reduce(into: [String: CNContact]()) { partialResult, identifier in
            guard let contact = unifiedContacts[identifier] else {
                throw MockContactServiceError.missingContact
            }

            partialResult[identifier] = contact
        }
    }

    func deleteContact(_ contact: CNMutableContact) async throws {
        if failingDeleteIdentifiers.contains((contact as CNContact).stableIdentifier) {
            throw ContactError.updateFailed(MockContactServiceError.missingContact)
        }
        if let deleteError {
            throw deleteError
        }

        deletedContacts.append(contact.mutableCopy() as! CNMutableContact)
    }

    func deleteContacts(_ contacts: [CNMutableContact]) async throws {
        if let batchDeleteError {
            throw batchDeleteError
        }

        if let deleteError {
            throw deleteError
        }

        deletedContacts.append(contentsOf: contacts.map { $0.mutableCopy() as! CNMutableContact })
    }

    func updatedContactsSnapshot() -> [CNMutableContact] {
        updatedContacts
    }

    func deletedContactsSnapshot() -> [CNMutableContact] {
        deletedContacts
    }

    func unifiedContactFetchCountSnapshot() -> Int {
        unifiedContactFetchCount
    }

    func unifiedContactsFetchCountSnapshot() -> Int {
        unifiedContactsFetchCount
    }

    func lastFetchedKeyStringsSnapshot() -> [String] {
        lastFetchedKeyStrings
    }

    func lastUnifiedFetchKeyStringsSnapshot() -> [String] {
        lastUnifiedFetchKeyStrings
    }
}
