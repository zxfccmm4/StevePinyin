import Foundation
@preconcurrency import Contacts

struct DuplicateContactDetectionUseCase {
    private let contactService: any ContactServing

    init(contactService: any ContactServing = ContactService.shared) {
        self.contactService = contactService
    }

    func execute(
        types: Set<DuplicateType>,
        progressHandler: @escaping @MainActor (Float) -> Void
    ) async throws -> [DuplicateGroup] {
        try await PerformanceMonitor.shared.trackDuplicateDetection(typeCount: types.count) {
            try await performExecute(types: types, progressHandler: progressHandler)
        }
    }

    private func performExecute(
        types: Set<DuplicateType>,
        progressHandler: @escaping @MainActor (Float) -> Void
    ) async throws -> [DuplicateGroup] {
        let orderedTypes = DuplicateType.allCases.filter(types.contains)
        guard !orderedTypes.isEmpty else {
            await progressHandler(0.0)
            return []
        }

        let contacts = try await loadContacts()
        guard !contacts.isEmpty else {
            await progressHandler(1.0)
            return []
        }

        var allGroups: [DuplicateGroup] = []

        for (typeIndex, type) in orderedTypes.enumerated() {
            try Task.checkCancellation()

            let groups = try await detectGroups(of: type, in: contacts) { processedCount, totalCount in
                let typeProgress = totalCount == 0 ? 1.0 : Float(processedCount) / Float(totalCount)
                let overallProgress = (Float(typeIndex) + typeProgress) / Float(orderedTypes.count)
                await progressHandler(min(overallProgress, 0.99))
            }

            allGroups.append(contentsOf: groups)
        }

        await progressHandler(1.0)
        return allGroups
    }

    private func loadContacts() async throws -> [ContactResult] {
        let keysToFetch = [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneticGivenNameKey,
            CNContactPhoneticFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneticOrganizationNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactImageDataAvailableKey,
            CNContactThumbnailImageDataKey,
        ] as [CNKeyDescriptor]

        let contacts = try await contactService.fetchContacts(
            keys: keysToFetch,
            sortOrder: .givenName
        )
        return contacts.map(ContactResult.init(from:))
    }

    private func detectGroups(
        of type: DuplicateType,
        in contacts: [ContactResult],
        progressHandler: @escaping @Sendable (_ processedCount: Int, _ totalCount: Int) async -> Void
    ) async throws -> [DuplicateGroup] {
        switch type {
        case .exactName:
            return try await detectSharedValueGroups(
                of: type,
                in: contacts,
                progressHandler: progressHandler
            ) { contact in
                let normalizedName = normalizeText(contact.name)
                guard !normalizedName.isEmpty else { return [] }
                return [MatchValue(normalized: normalizedName, display: contact.name)]
            }

        case .samePhone:
            return try await detectSharedValueGroups(
                of: type,
                in: contacts,
                progressHandler: progressHandler
            ) { contact in
                contact.contact.phoneNumbers.compactMap { phoneNumber in
                    let display = phoneNumber.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalized = normalizePhoneNumber(display)
                    guard !normalized.isEmpty else { return nil }
                    return MatchValue(normalized: normalized, display: display)
                }
            }

        case .sameEmail:
            return try await detectSharedValueGroups(
                of: type,
                in: contacts,
                progressHandler: progressHandler
            ) { contact in
                contact.contact.emailAddresses.compactMap { emailAddress in
                    let display = (emailAddress.value as String).trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalized = normalizeText(display)
                    guard !normalized.isEmpty else { return nil }
                    return MatchValue(normalized: normalized, display: display)
                }
            }

        case .samePinyin:
            return try await detectSharedValueGroups(
                of: type,
                in: contacts,
                progressHandler: progressHandler
            ) { contact in
                let normalizedPinyin = normalizeText(contact.pinyin)
                guard !normalizedPinyin.isEmpty else { return [] }
                return [MatchValue(normalized: normalizedPinyin, display: contact.pinyin)]
            }

        case .similarName:
            return try await detectSimilarNameGroups(
                in: contacts,
                progressHandler: progressHandler
            )
        }
    }

    private func detectSharedValueGroups(
        of type: DuplicateType,
        in contacts: [ContactResult],
        progressHandler: @escaping @Sendable (_ processedCount: Int, _ totalCount: Int) async -> Void,
        valueProvider: (ContactResult) -> [MatchValue]
    ) async throws -> [DuplicateGroup] {
        var buckets: [String: [ContactResult]] = [:]
        var displayValues: [String: String] = [:]
        let totalCount = contacts.count

        for (index, contact) in contacts.enumerated() {
            try Task.checkCancellation()

            for value in uniqueValues(from: valueProvider(contact)) {
                buckets[value.normalized, default: []].append(contact)
                displayValues[value.normalized] = displayValues[value.normalized] ?? value.display
            }

            if shouldReportProgress(for: index, total: totalCount) {
                await progressHandler(index + 1, totalCount)
            }
        }

        let duplicateBuckets = buckets.filter { $0.value.count > 1 }
        return buildConnectedGroups(
            of: type,
            duplicateBuckets: duplicateBuckets,
            displayValues: displayValues,
            orderLookup: contactOrderLookup(from: contacts)
        )
    }

    private func detectSimilarNameGroups(
        in contacts: [ContactResult],
        progressHandler: @escaping @Sendable (_ processedCount: Int, _ totalCount: Int) async -> Void
    ) async throws -> [DuplicateGroup] {
        let candidates = contacts.compactMap { contact -> SimilarNameCandidate? in
            let normalizedName = normalizeText(contact.name)
            guard !normalizedName.isEmpty else { return nil }
            return SimilarNameCandidate(contact: contact, normalizedName: normalizedName)
        }

        let buckets = Dictionary(grouping: candidates, by: \.leadingCharacter)
        let totalCount = candidates.count
        var processedCount = 0
        var processedIdentifiers: Set<String> = []
        var groups: [DuplicateGroup] = []

        for bucket in buckets.values {
            for index in bucket.indices {
                try Task.checkCancellation()

                let candidate = bucket[index]
                defer {
                    processedCount += 1
                }

                guard processedIdentifiers.contains(candidate.contact.contactIdentifier) == false else {
                    if shouldReportProgress(for: processedCount, total: totalCount) {
                        await progressHandler(processedCount + 1, totalCount)
                    }
                    continue
                }

                var matchingContacts = [candidate.contact]

                for otherIndex in bucket.indices where otherIndex > index {
                    let otherCandidate = bucket[otherIndex]
                    guard processedIdentifiers.contains(otherCandidate.contact.contactIdentifier) == false else {
                        continue
                    }

                    guard isCandidateLengthClose(candidate.normalizedName, otherCandidate.normalizedName) else {
                        continue
                    }

                    if isSimilarName(candidate.normalizedName, otherCandidate.normalizedName) {
                        matchingContacts.append(otherCandidate.contact)
                    }
                }

                if matchingContacts.count > 1 {
                    matchingContacts.sort { lhs, rhs in
                        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    }

                    groups.append(
                        DuplicateGroup(
                            duplicateType: .similarName,
                            contacts: matchingContacts,
                            matchingValue: candidate.contact.name
                        )
                    )

                    for contact in matchingContacts {
                        processedIdentifiers.insert(contact.contactIdentifier)
                    }
                }

                if shouldReportProgress(for: processedCount, total: totalCount) {
                    await progressHandler(processedCount + 1, totalCount)
                }
            }
        }

        return groups.sorted(by: duplicateGroupSorter)
    }

    private func buildConnectedGroups(
        of type: DuplicateType,
        duplicateBuckets: [String: [ContactResult]],
        displayValues: [String: String],
        orderLookup: [String: Int]
    ) -> [DuplicateGroup] {
        var unionFind = UnionFind()
        var contactLookup: [String: ContactResult] = [:]

        for contacts in duplicateBuckets.values {
            let uniqueContacts = uniqueContacts(from: contacts)
            guard uniqueContacts.count > 1 else { continue }

            let identifiers = uniqueContacts.map(\.contactIdentifier)
            unionFind.add(identifiers)

            if let firstIdentifier = identifiers.first {
                for identifier in identifiers.dropFirst() {
                    unionFind.union(firstIdentifier, identifier)
                }
            }

            for contact in uniqueContacts {
                contactLookup[contact.contactIdentifier] = contact
            }
        }

        var componentIdentifiers: [String: [String]] = [:]

        for identifier in contactLookup.keys {
            let rootIdentifier = unionFind.find(identifier)
            componentIdentifiers[rootIdentifier, default: []].append(identifier)
        }

        let groups = componentIdentifiers.values.compactMap { identifiers -> DuplicateGroup? in
            guard identifiers.count > 1 else { return nil }

            let contacts = identifiers
                .sorted { lhs, rhs in
                    (orderLookup[lhs] ?? .max) < (orderLookup[rhs] ?? .max)
                }
                .compactMap { contactLookup[$0] }

            guard contacts.count > 1 else { return nil }

            let matchingValue = representativeValue(
                for: Set(identifiers),
                duplicateBuckets: duplicateBuckets,
                displayValues: displayValues
            )

            return DuplicateGroup(
                duplicateType: type,
                contacts: contacts,
                matchingValue: matchingValue
            )
        }

        return groups.sorted(by: duplicateGroupSorter)
    }

    private func representativeValue(
        for identifiers: Set<String>,
        duplicateBuckets: [String: [ContactResult]],
        displayValues: [String: String]
    ) -> String {
        let candidates = duplicateBuckets.compactMap { normalizedValue, contacts -> (String, Int)? in
            let contactIdentifiers = Set(contacts.map(\.contactIdentifier))
            guard contactIdentifiers.isSubset(of: identifiers) else { return nil }
            let displayValue = displayValues[normalizedValue] ?? normalizedValue
            return (displayValue, contactIdentifiers.count)
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }

            return lhs.0.localizedStandardCompare(rhs.0) == .orderedAscending
        }

        return sortedCandidates.first?.0 ?? ""
    }

    private func uniqueValues(from values: [MatchValue]) -> [MatchValue] {
        var seen: Set<String> = []

        return values.filter { value in
            seen.insert(value.normalized).inserted
        }
    }

    private func uniqueContacts(from contacts: [ContactResult]) -> [ContactResult] {
        var seenIdentifiers: Set<String> = []

        return contacts.filter { contact in
            seenIdentifiers.insert(contact.contactIdentifier).inserted
        }
    }

    private func contactOrderLookup(from contacts: [ContactResult]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: contacts.enumerated().map { index, contact in
            (contact.contactIdentifier, index)
        })
    }

    private func shouldReportProgress(for index: Int, total: Int) -> Bool {
        index == total - 1 || index.isMultiple(of: 50)
    }

    private func normalizeText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    private func isCandidateLengthClose(_ lhs: String, _ rhs: String) -> Bool {
        let maxLength = max(lhs.count, rhs.count)
        let minimumAllowedGap = max(1, Int(floor(Double(maxLength) * 0.2)))
        return abs(lhs.count - rhs.count) <= minimumAllowedGap
    }

    private func isSimilarName(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs != rhs, lhs.isEmpty == false, rhs.isEmpty == false else { return false }

        let maxLength = max(lhs.count, rhs.count)
        guard maxLength <= 100 else { return false }

        let distance = levenshteinDistance(lhs, rhs)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        return similarity >= 0.8
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        let lhsCount = lhsCharacters.count
        let rhsCount = rhsCharacters.count

        if lhsCount == 0 { return rhsCount }
        if rhsCount == 0 { return lhsCount }

        var matrix = Array(
            repeating: Array(repeating: 0, count: rhsCount + 1),
            count: lhsCount + 1
        )

        for index in 0...lhsCount {
            matrix[index][0] = index
        }

        for index in 0...rhsCount {
            matrix[0][index] = index
        }

        for lhsIndex in 1...lhsCount {
            for rhsIndex in 1...rhsCount {
                if lhsCharacters[lhsIndex - 1] == rhsCharacters[rhsIndex - 1] {
                    matrix[lhsIndex][rhsIndex] = matrix[lhsIndex - 1][rhsIndex - 1]
                } else {
                    matrix[lhsIndex][rhsIndex] = Swift.min(
                        matrix[lhsIndex - 1][rhsIndex] + 1,
                        matrix[lhsIndex][rhsIndex - 1] + 1,
                        matrix[lhsIndex - 1][rhsIndex - 1] + 1
                    )
                }
            }
        }

        return matrix[lhsCount][rhsCount]
    }

    private let duplicateGroupSorter: (DuplicateGroup, DuplicateGroup) -> Bool = { lhs, rhs in
        if lhs.duplicateType != rhs.duplicateType {
            return lhs.duplicateType.rawValue < rhs.duplicateType.rawValue
        }

        if lhs.contacts.count != rhs.contacts.count {
            return lhs.contacts.count > rhs.contacts.count
        }

        return lhs.matchingValue.localizedStandardCompare(rhs.matchingValue) == .orderedAscending
    }
}

private struct MatchValue {
    let normalized: String
    let display: String
}

private struct SimilarNameCandidate {
    let contact: ContactResult
    let normalizedName: String

    var leadingCharacter: Character {
        normalizedName.first ?? "#"
    }
}

private struct UnionFind {
    private var parent: [String: String] = [:]

    mutating func add(_ identifiers: [String]) {
        for identifier in identifiers where parent[identifier] == nil {
            parent[identifier] = identifier
        }
    }

    mutating func find(_ identifier: String) -> String {
        guard let parentIdentifier = parent[identifier] else {
            parent[identifier] = identifier
            return identifier
        }

        guard parentIdentifier != identifier else { return identifier }

        let rootIdentifier = find(parentIdentifier)
        parent[identifier] = rootIdentifier
        return rootIdentifier
    }

    mutating func union(_ lhs: String, _ rhs: String) {
        let lhsRoot = find(lhs)
        let rhsRoot = find(rhs)

        guard lhsRoot != rhsRoot else { return }
        parent[rhsRoot] = lhsRoot
    }
}
