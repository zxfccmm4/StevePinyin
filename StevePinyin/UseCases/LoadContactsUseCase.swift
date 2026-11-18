@preconcurrency import Contacts
import Foundation

struct LoadContactsUseCase {
    private let contactService: any ContactServing

    init(contactService: any ContactServing = ContactService.shared) {
        self.contactService = contactService
    }

    func requestAccess() async -> Bool {
        do {
            return try await contactService.requestAccess()
        } catch {
            return false
        }
    }

    func loadContacts(
        keysToFetch: [CNKeyDescriptor],
        sortOrder: CNContactSortOrder = .givenName
    ) async throws -> [CNContact] {
        try await contactService.fetchContacts(keys: keysToFetch, sortOrder: sortOrder)
    }
}
