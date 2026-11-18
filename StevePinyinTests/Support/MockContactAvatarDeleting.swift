import Foundation
@preconcurrency import Contacts
@testable import StevePinyin

actor MockContactAvatarDeleting: ContactAvatarDeleting {
    private let deleteAllResult: Result<AvatarDeletionResult, any Error>
    private let deleteSelectedResult: Result<AvatarDeletionResult, any Error>
    private let contactsWithAvatarsResult: Result<[CNContact], any Error>

    private var lastDeleteSelectedIdentifiers: [String] = []
    private var progressEvents: [Int] = []

    init(
        deleteAllResult: Result<AvatarDeletionResult, any Error> = .success(.init(successCount: 0, failureCount: 0)),
        deleteSelectedResult: Result<AvatarDeletionResult, any Error> = .success(.init(successCount: 0, failureCount: 0)),
        contactsWithAvatarsResult: Result<[CNContact], any Error> = .success([])
    ) {
        self.deleteAllResult = deleteAllResult
        self.deleteSelectedResult = deleteSelectedResult
        self.contactsWithAvatarsResult = contactsWithAvatarsResult
    }

    func deleteAllContactAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> AvatarDeletionResult {
        try deleteAllResult.get()
    }

    func loadContactsWithAvatars(keysToFetch: [CNKeyDescriptor]) async throws -> [CNContact] {
        try contactsWithAvatarsResult.get()
    }

    func deleteSelectedAvatars(
        identifiers: [String],
        keysToFetch: [CNKeyDescriptor],
        progressHandler: @escaping @MainActor (Int) -> Void
    ) async throws -> AvatarDeletionResult {
        lastDeleteSelectedIdentifiers = identifiers

        for index in identifiers.indices {
            let progress = index + 1
            progressEvents.append(progress)
            await progressHandler(progress)
        }

        return try deleteSelectedResult.get()
    }

    func lastDeleteSelectedIdentifiersSnapshot() -> [String] {
        lastDeleteSelectedIdentifiers
    }

    func progressEventsSnapshot() -> [Int] {
        progressEvents
    }
}
