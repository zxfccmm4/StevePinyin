import Foundation
@preconcurrency import Contacts

struct AvatarMatchIntentSummary {
    let matchedCount: Int
    let totalContacts: Int
    let packageName: String
    let mode: AvatarImportMode

    var dialog: String {
        String(
            format: NSLocalizedString("已完成匹配预检：%d/%d 位联系人可应用“%@”。", comment: ""),
            matchedCount,
            totalContacts,
            packageName
        )
    }
}

struct DuplicateDetectionIntentSummary {
    let groups: [DuplicateGroup]

    var duplicateGroupCount: Int {
        groups.count
    }

    var duplicateContactCount: Int {
        DuplicateContactResult(duplicateGroups: groups, hasCompleted: true).totalDuplicates
    }

    var dialog: String {
        if groups.isEmpty {
            return NSLocalizedString("未发现重复联系人。", comment: "")
        }

        return String(
            format: NSLocalizedString("发现 %d 组重复，涉及 %d 位联系人。", comment: ""),
            duplicateGroupCount,
            duplicateContactCount
        )
    }
}

struct StevePinyinIntentExecutionService {
    private let packageService: AvatarPackageService
    private let contactLoadingUseCase: LoadContactsUseCase
    private let matchingUseCase: PrepareAvatarMatchesUseCase
    private let duplicateDetectionUseCase: DuplicateContactDetectionUseCase
    private let pinyinMaintenanceUseCase: ContactsPinyinMaintenanceUseCase

    private let contactKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
    ]

    init(
        packageService: AvatarPackageService = AvatarPackageService(),
        contactLoadingUseCase: LoadContactsUseCase = LoadContactsUseCase(),
        matchingUseCase: PrepareAvatarMatchesUseCase = PrepareAvatarMatchesUseCase(),
        duplicateDetectionUseCase: DuplicateContactDetectionUseCase = DuplicateContactDetectionUseCase(),
        pinyinMaintenanceUseCase: ContactsPinyinMaintenanceUseCase = ContactsPinyinMaintenanceUseCase()
    ) {
        self.packageService = packageService
        self.contactLoadingUseCase = contactLoadingUseCase
        self.matchingUseCase = matchingUseCase
        self.duplicateDetectionUseCase = duplicateDetectionUseCase
        self.pinyinMaintenanceUseCase = pinyinMaintenanceUseCase
    }

    func addContactsPinyin(format: PinyinFormat) async throws -> String {
        guard await contactLoadingUseCase.requestAccess() else {
            throw StevePinyinIntentError.contactAccessDenied
        }
        let result = try await pinyinMaintenanceUseCase.addPinyin(format: format) { _ in }
        if result.skippedEnglishCount > 0 {
            return "已为 \(result.successCount) 位联系人生成拼音（跳过 \(result.skippedEnglishCount) 位纯英文联系人）。"
        }
        return "已成功为 \(result.successCount) 位联系人生成拼音。"
    }

    func enableT9Search(format: PinyinFormat) async throws -> String {
        guard await contactLoadingUseCase.requestAccess() else {
            throw StevePinyinIntentError.contactAccessDenied
        }
        let result = try await pinyinMaintenanceUseCase.enableT9(format: format) { _ in }
        return "已为 \(result.successCount) 位联系人开启 T9 拨号搜索。"
    }
    func prepareAvatarMatches(
        packageID: String?,
        mode: AvatarImportMode
    ) async throws -> AvatarMatchIntentSummary {
        guard mode != .single, mode != .manual else {
            throw StevePinyinIntentError.modeRequiresInAppReview
        }

        guard await contactLoadingUseCase.requestAccess() else {
            throw StevePinyinIntentError.contactAccessDenied
        }

        let contacts = try await contactLoadingUseCase.loadContacts(keysToFetch: contactKeys)
        let package = try await resolvePackage(packageID: packageID)
        let iconPackage = IconPackage(
            name: package.name,
            description: package.description,
            icons: package.icons
        )
        let result = try matchingUseCase.execute(
            contacts: contacts,
            importMode: mode,
            selectedPackage: iconPackage,
            selectedUniformIcon: nil,
            manualSelections: [:]
        )

        return AvatarMatchIntentSummary(
            matchedCount: result.matches.count,
            totalContacts: contacts.count,
            packageName: package.name,
            mode: mode
        )
    }

    func detectDuplicates(scope: DuplicateDetectionScopeIntentValue) async throws -> DuplicateDetectionIntentSummary {
        guard await contactLoadingUseCase.requestAccess() else {
            throw StevePinyinIntentError.contactAccessDenied
        }

        let groups = try await duplicateDetectionUseCase.execute(types: scope.duplicateTypes) { _ in }
        return DuplicateDetectionIntentSummary(groups: groups)
    }

    private func resolvePackage(packageID: String?) async throws -> AvatarPackage {
        let packages = await packageService.loadSavedPackages()
            .filter { $0.icons.isEmpty == false }

        guard packages.isEmpty == false else {
            throw StevePinyinIntentError.noAvatarPackageAvailable
        }

        if let packageID {
            guard let package = packages.first(where: { $0.id == packageID }) else {
                throw StevePinyinIntentError.selectedPackageMissing
            }

            return package
        }

        return packages[0]
    }
}
