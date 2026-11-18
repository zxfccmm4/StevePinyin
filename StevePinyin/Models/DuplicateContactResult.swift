import Foundation
import Contacts

enum SelectionMode {
    case selectFirstToDelete  // 选择第一项进行删除（保留其他）
    case selectOthersToDelete // 选择除第一项外的其他项进行删除（保留第一项）
}

enum DuplicateType: String, CaseIterable {
    case exactName = "exactName"
    case similarName = "similarName"
    case samePhone = "samePhone"
    case sameEmail = "sameEmail"
    case samePinyin = "samePinyin"
    
    var displayName: String {
        switch self {
        case .exactName:
            return NSLocalizedString("Exact Name", comment: "")
        case .similarName:
            return NSLocalizedString("Similar Name", comment: "")
        case .samePhone:
            return NSLocalizedString("Same Phone", comment: "")
        case .sameEmail:
            return NSLocalizedString("Same Email", comment: "")
        case .samePinyin:
            return NSLocalizedString("Same Pinyin", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .exactName:
            return "person.2.fill"
        case .similarName:
            return "person.2"
        case .samePhone:
            return "phone.fill"
        case .sameEmail:
            return "envelope.fill"
        case .samePinyin:
            return "textformat.abc"
        }
    }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let duplicateType: DuplicateType
    var contacts: [ContactResult]
    let matchingValue: String
    var selectedContacts: Set<String> = []
    
    var isAllSelected: Bool {
        selectedContacts.count == contacts.count && contacts.count > 0
    }

    var isSomeSelected: Bool {
        !selectedContacts.isEmpty && selectedContacts.count < contacts.count
    }

    mutating func toggleSelectAll() {
        if isAllSelected {
            selectedContacts.removeAll()
        } else {
            selectedContacts = Set(contacts.map { $0.id })
        }
    }

    mutating func selectWithMode(_ mode: SelectionMode) {
        selectedContacts.removeAll()
        switch mode {
        case .selectFirstToDelete:
            // 选择第一项进行删除
            if let firstContact = contacts.first {
                selectedContacts.insert(firstContact.id)
            }
        case .selectOthersToDelete:
            // 选择除第一项外的其他项进行删除（保留第一项）
            for contact in contacts.dropFirst() {
                selectedContacts.insert(contact.id)
            }
        }
    }
    
    mutating func toggleContact(_ contactId: String) {
        if selectedContacts.contains(contactId) {
            selectedContacts.remove(contactId)
        } else {
            selectedContacts.insert(contactId)
        }
    }
}

struct DuplicateContactResult: Identifiable {
    let id = UUID()
    var duplicateGroups: [DuplicateGroup] = []
    var hasCompleted: Bool = false

    var totalDuplicates: Int {
        uniqueContactIdentifiers(
            from: duplicateGroups.flatMap(\.contacts)
        ).count
    }
    
    var selectedCount: Int {
        uniqueContactIdentifiers(from: getSelectedContacts()).count
    }
    
    var isAllSelected: Bool {
        duplicateGroups.allSatisfy { group in
            group.isAllSelected
        }
    }

    var isSomeSelected: Bool {
        duplicateGroups.contains { !$0.selectedContacts.isEmpty }
    }

    mutating func toggleSelectAll() {
        let shouldSelectAll = !isAllSelected
        for i in 0..<duplicateGroups.count {
            if shouldSelectAll {
                duplicateGroups[i].selectedContacts = Set(duplicateGroups[i].contacts.map { $0.id })
            } else {
                duplicateGroups[i].selectedContacts.removeAll()
            }
        }
    }

    mutating func selectAllWithMode(_ mode: SelectionMode) {
        for i in 0..<duplicateGroups.count {
            duplicateGroups[i].selectWithMode(mode)
        }
    }
    
    func getSelectedContacts() -> [ContactResult] {
        var selectedContacts: [ContactResult] = []
        var seenIdentifiers: Set<String> = []

        for group in duplicateGroups {
            for contact in group.contacts {
                if group.selectedContacts.contains(contact.id),
                   seenIdentifiers.insert(contact.contactIdentifier).inserted {
                    selectedContacts.append(contact)
                }
            }
        }

        return selectedContacts
    }

    private func uniqueContactIdentifiers(from contacts: [ContactResult]) -> Set<String> {
        Set(contacts.map(\.contactIdentifier))
    }
}
