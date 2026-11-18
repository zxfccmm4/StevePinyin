import Contacts
import Observation
import SwiftUI

@Observable
@MainActor
final class ImportAvatarsViewModel {
    var showingAlert = false
    var alertMessage = ""
    var isLoading = false
    var downloadProgress = 0.0
    var downloadedAvatars: [String: Image] = [:]
    var matchedContacts: [(CNContact, Icon)] = []
    var matchPreviewIcons: [Icon] = []
    var showingMatchPreview = false
    var isMatching = false
    var importMode: AvatarImportMode = .sequential
    var selectedUniformIcon: Icon?
    var selectedManualIcon: Icon?
    var showingPackageSelector = false
    var showingPackageDetail = false
    var contacts: [CNContact] = []
    var importErrors: [String] = []
    var currentProcessingContact = ""
    var currentProcessingIndex = 0
    var totalContactsToProcess = 0
    var isLoadingContacts = false
    var manualSelections: [String: AvatarIcon] = [:]
    var contactsNeedingSelection: [CNContact] = []
    var deleteSelections: Set<String> = []
    var contactsWithAvatars: [CNContact] = []
    var error: Error?
    var importConfirmationState: AvatarImportConfirmationState?
    var avatarRecommendationsByContactID: [String: [AvatarRecommendation]] = [:]

    private var hasLoadedContacts = false
    private var pendingPackageSelectionID: String?
    var activeImportTask: Task<Void, Never>?
    let contactsFetchKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactIdentifierKey,
        CNContactThumbnailImageDataKey,
        CNContactImageDataAvailableKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactOrganizationNameKey,
    ] as [CNKeyDescriptor]
    let avatarManagementContactKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactImageDataKey,
        CNContactThumbnailImageDataKey,
        CNContactImageDataAvailableKey,
        CNContactIdentifierKey,
        CNContactOrganizationNameKey,
    ] as [CNKeyDescriptor]

    // 可选的外部告警回调；未注入时回退到当前页面 alert 状态
    var alertHandler: ((String) -> Void)?

    let packageManager: AvatarPackageManagementViewModel
    let contactLoadingUseCase: LoadContactsUseCase
    let validationUseCase: ValidateAvatarImportConfigurationUseCase
    let matchingUseCase: PrepareAvatarMatchesUseCase
    let matchPreviewStateUseCase: BuildAvatarMatchPreviewStateUseCase
    let avatarImportUseCase: ContactAvatarImportUseCase
    let summaryUseCase: BuildAvatarImportSummaryUseCase
    let flowCompletionUseCase: AvatarFlowCompletionStateUseCase
    let deletionSelectionUseCase: AvatarDeletionSelectionUseCase
    let deleteAvatarFlowUseCase: DeleteAvatarFlowUseCase
    let avatarRecommendationsUseCase: BuildAvatarRecommendationsUseCase
    let batchCoordinator: BatchTaskCoordinator

    var urlString: String {
        get { packageManager.urlString }
        set { packageManager.urlString = newValue }
    }

    var selectedPackage: IconPackage? {
        packageManager.selectedPackage
    }

    var selectedPackages: [AvatarPackage] {
        packageManager.selectedPackages
    }

    var savedPackages: [AvatarPackage] {
        packageManager.savedPackages
    }

    var currentPackage: AvatarPackage? {
        packageManager.currentPackage
    }

    var currentPackageDisplayName: String? {
        selectedPackage?.name ?? currentPackage?.name
    }

    var selectedIcons: [Icon] {
        packageManager.selectedIcons
    }

    var sequentialIcons: [Icon] {
        packageManager.sequentialIcons
    }

    init(
        packageManager: AvatarPackageManagementViewModel? = nil,
        contactLoadingUseCase: LoadContactsUseCase = LoadContactsUseCase(),
        validationUseCase: ValidateAvatarImportConfigurationUseCase = ValidateAvatarImportConfigurationUseCase(),
        matchingUseCase: PrepareAvatarMatchesUseCase = PrepareAvatarMatchesUseCase(),
        matchPreviewStateUseCase: BuildAvatarMatchPreviewStateUseCase = BuildAvatarMatchPreviewStateUseCase(),
        avatarImportUseCase: ContactAvatarImportUseCase = ContactAvatarImportUseCase(),
        summaryUseCase: BuildAvatarImportSummaryUseCase = BuildAvatarImportSummaryUseCase(),
        flowCompletionUseCase: AvatarFlowCompletionStateUseCase = AvatarFlowCompletionStateUseCase(),
        deletionSelectionUseCase: AvatarDeletionSelectionUseCase = AvatarDeletionSelectionUseCase(),
        deleteAvatarFlowUseCase: DeleteAvatarFlowUseCase = DeleteAvatarFlowUseCase(),
        avatarRecommendationsUseCase: BuildAvatarRecommendationsUseCase = BuildAvatarRecommendationsUseCase(),
        batchCoordinator: BatchTaskCoordinator? = nil
    ) {
        self.packageManager = packageManager ?? AvatarPackageManagementViewModel()
        self.contactLoadingUseCase = contactLoadingUseCase
        self.validationUseCase = validationUseCase
        self.matchingUseCase = matchingUseCase
        self.matchPreviewStateUseCase = matchPreviewStateUseCase
        self.avatarImportUseCase = avatarImportUseCase
        self.summaryUseCase = summaryUseCase
        self.flowCompletionUseCase = flowCompletionUseCase
        self.deletionSelectionUseCase = deletionSelectionUseCase
        self.deleteAvatarFlowUseCase = deleteAvatarFlowUseCase
        self.avatarRecommendationsUseCase = avatarRecommendationsUseCase
        self.batchCoordinator = batchCoordinator ?? .shared
        loadSavedPackages()
    }

    // MARK: - Contact Management
    func requestContactAccess() async -> Bool {
        await contactLoadingUseCase.requestAccess()
    }

    func loadContacts(forceReload: Bool = false) async throws {
        guard forceReload || hasLoadedContacts == false || contacts.isEmpty else {
            return
        }

        isLoadingContacts = true
        defer { isLoadingContacts = false }

        contacts = try await contactLoadingUseCase.loadContacts(keysToFetch: contactsFetchKeys)
        hasLoadedContacts = true
    }

    func showError(_ message: String) {
        isLoading = false
        downloadProgress = 0
        alertMessage = message
        showingAlert = true
    }

    func invalidateLoadedContactsCache() {
        hasLoadedContacts = false
    }

    func configureFromIntent(packageID: String?, importMode: AvatarImportMode) {
        self.importMode = importMode
        pendingPackageSelectionID = packageID
        applyPendingPackageSelectionIfPossible()
    }

    func applyPendingPackageSelectionIfPossible() {
        guard let pendingPackageSelectionID else { return }
        guard let package = savedPackages.first(where: { $0.id == pendingPackageSelectionID }) else { return }

        selectPackage(package)
        self.pendingPackageSelectionID = nil
    }
}
