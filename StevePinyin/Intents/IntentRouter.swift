import Contacts
import Observation
import SwiftUI

enum NavigationTarget: Hashable {
    case importAvatars(packageID: String?, mode: AvatarImportMode)
    case matchResults
    case duplicateContacts(duplicates: [[String]])
    case searchContacts(query: String)
    case settings
}

@Observable
@MainActor
final class IntentRouter {
    static let shared = IntentRouter()

    var navigationTarget: NavigationTarget?
    var isHandlingIntent = false
    var lastIntentMessage: String?
    var pendingDuplicateGroups: [DuplicateGroup]?
    var pendingAvatarPackageID: String?
    var pendingAvatarImportMode: AvatarImportMode?
    var pendingContactSearchQuery: String?

    private init() {
        if let launchTarget = UserDefaults.standard.string(forKey: "initialNavigationTarget") {
            switch launchTarget {
            case "duplicateDetection":
                navigationTarget = .duplicateContacts(duplicates: [])
            case "settings":
                navigationTarget = .settings
            case "importAvatars":
                handleImportIntent(packageID: nil, matchMode: .sequential)
            case "packageSelector":
                handleImportIntent(packageID: "browse", matchMode: .sequential)
            default:
                break
            }
        }
    }

    func handleImportIntent(packageID: String?, matchMode: AvatarImportMode) {
        isHandlingIntent = true
        lastIntentMessage = "准备导入头像..."
        pendingAvatarPackageID = packageID
        pendingAvatarImportMode = matchMode
        navigationTarget = .importAvatars(packageID: packageID, mode: matchMode)
    }

    func consumePendingAvatarImportConfiguration() -> (packageID: String?, mode: AvatarImportMode)? {
        guard let mode = pendingAvatarImportMode else { return nil }
        let packageID = pendingAvatarPackageID
        pendingAvatarPackageID = nil
        pendingAvatarImportMode = nil
        return (packageID, mode)
    }

    func handleMatchResult(matchedCount: Int, totalContacts: Int) {
        isHandlingIntent = true
        lastIntentMessage = "匹配完成：\(matchedCount)/\(totalContacts)"
        navigationTarget = .matchResults
    }

    func handleDuplicateCheckResult(duplicates: [[CNContact]]) {
        isHandlingIntent = true
        let duplicateCount = duplicates.count
        lastIntentMessage = duplicateCount == 0 ? "未发现重复" : "发现 \(duplicateCount) 组重复"
        let contactIDs = duplicates.map { group in
            group.map(\.identifier)
        }
        navigationTarget = .duplicateContacts(duplicates: contactIDs)
    }

    func handleDuplicateCheckResult(groups: [DuplicateGroup]) {
        isHandlingIntent = true
        pendingDuplicateGroups = groups
        lastIntentMessage = groups.isEmpty ? "未发现重复" : "发现 \(groups.count) 组重复"
        navigationTarget = .duplicateContacts(
            duplicates: groups.map { group in
                group.contacts.map(\.contactIdentifier)
            }
        )
    }

    func consumePendingDuplicateGroups() -> [DuplicateGroup]? {
        let groups = pendingDuplicateGroups
        pendingDuplicateGroups = nil
        return groups
    }

    func handleSearchInApp(query: String) {
        isHandlingIntent = true
        pendingContactSearchQuery = query
        navigationTarget = .searchContacts(query: query)
    }

    func consumePendingSearchQuery() -> String? {
        let query = pendingContactSearchQuery
        pendingContactSearchQuery = nil
        return query
    }

    func clearNavigation() {
        navigationTarget = nil
        isHandlingIntent = false
        lastIntentMessage = nil
    }
}
