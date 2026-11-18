import SwiftUI

struct ImportAvatarsView: View {
    @State private var viewModel: ImportAvatarsViewModel
    @State private var intentRouter = IntentRouter.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("lastActiveView") private var lastActiveView = ""
    private let runsLiveTasks: Bool

    @State private var currentStep: ImportStep = .selectPackage
    @State private var expandedContactIds: Set<String> = []
    @State private var showingAllContactsSheet = false
    @State private var showManualSelectionSheet = false
    @State private var showDeleteAvatarsSheet = false
    @State private var showDeleteAllConfirmation = false
    @State private var downloadURLFieldVisible = false
    private let initialPackageID: String?
    private let initialImportMode: AvatarImportMode?

    @MainActor
    init(
        currentStep: ImportStep = .selectPackage,
        runsLiveTasks: Bool = true,
        initialPackageID: String? = nil,
        initialImportMode: AvatarImportMode? = nil
    ) {
        _viewModel = State(initialValue: ImportAvatarsViewModel())
        _currentStep = State(initialValue: currentStep)
        self.runsLiveTasks = runsLiveTasks
        self.initialPackageID = initialPackageID
        self.initialImportMode = initialImportMode
    }

    init(
        viewModel: ImportAvatarsViewModel,
        currentStep: ImportStep = .selectPackage,
        runsLiveTasks: Bool = true,
        initialPackageID: String? = nil,
        initialImportMode: AvatarImportMode? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _currentStep = State(initialValue: currentStep)
        self.runsLiveTasks = runsLiveTasks
        self.initialPackageID = initialPackageID
        self.initialImportMode = initialImportMode
    }

    var body: some View {
        NavigationStack {
            stepScaffold
                .toolbar { toolbarContent }
        }
        .confirmationDialog(
            "确认清空全部联系人头像？",
            isPresented: $showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空全部头像", role: .destructive) {
                Task { await viewModel.deleteAllContactAvatars() }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        }
        .alert(String(localized: "Import Result"), isPresented: $viewModel.showingAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(combinedAlertMessage)
        }
        .importAvatarSheets(viewModel: viewModel)
        .sheet(isPresented: $showManualSelectionSheet) {
            ManualSelectionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showDeleteAvatarsSheet) {
            DeleteAvatarsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAllContactsSheet) {
            ImportAllContactsSheet(contacts: viewModel.contacts)
        }
        .task {
            guard runsLiveTasks else { return }
            applyInitialIntentConfigurationIfNeeded()
            consumeRouterIntentConfigurationIfNeeded()

            if await viewModel.requestContactAccess() {
                try? await viewModel.loadContacts()
            }
        }
        .onChange(of: intentRouter.pendingAvatarImportMode) { _, _ in
            consumeRouterIntentConfigurationIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
    }

    private var stepScaffold: some View {
        VStack(spacing: 0) {
            StepProgressBar(currentStep: currentStep)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    stepContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .id(currentStep)
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle(currentStep.title)
        .overlay {
            if viewModel.isLoading {
                ImportAvatarsLoadingOverlay(viewModel: viewModel)
            }
        }
        .safeAreaBar(edge: .bottom) {
            StepNavigationBar(
                currentStep: $currentStep,
                canProceed: isNextEnabled,
                importMode: viewModel.importMode,
                onComplete: { viewModel.startMatching() },
                onCancel: { dismiss() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showDeleteAvatarsSheet = true
                } label: {
                    Label(NSLocalizedString("Delete Avatars", comment: ""), systemImage: "person.crop.circle.badge.minus")
                }

                Button(role: .destructive) {
                    showDeleteAllConfirmation = true
                } label: {
                    Label("清空全部联系人头像", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard runsLiveTasks, phase == .active else { return }
        lastActiveView = "ImportAvatarsView"
        Task {
            try? await viewModel.loadContacts(forceReload: true)
        }
    }
    private var combinedAlertMessage: String {
        guard !viewModel.importErrors.isEmpty else { return viewModel.alertMessage }
        let details = viewModel.importErrors.prefix(5).map { "• \($0)" }.joined(separator: "\n")
        return "\(viewModel.alertMessage)\n\n\(details)"
    }

    private func applyInitialIntentConfigurationIfNeeded() {
        guard initialPackageID != nil || initialImportMode != nil else { return }
        viewModel.configureFromIntent(
            packageID: initialPackageID,
            importMode: initialImportMode ?? viewModel.importMode
        )
        if initialImportMode != nil {
            currentStep = .configureSelection
        }
    }

    private func consumeRouterIntentConfigurationIfNeeded() {
        guard let config = intentRouter.consumePendingAvatarImportConfiguration() else { return }
        if config.packageID == "browse" {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                viewModel.showingPackageSelector = true
            }
            return
        }
        viewModel.configureFromIntent(packageID: config.packageID, importMode: config.mode)
        currentStep = .configureSelection
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .selectPackage:
            ImportAvatarPackageSection(viewModel: viewModel)
        case .selectMode:
            ImportModeSelectionSection(
                selectedMode: viewModel.importMode,
                onSelectMode: { viewModel.importMode = $0 }
            )
        case .configureSelection:
            ImportAvatarSelectionSection(
                state: ImportAvatarSelectionSectionState(
                    importMode: viewModel.importMode,
                    selectedPackage: viewModel.currentPackage,
                    selectedUniformIcon: viewModel.selectedUniformIcon,
                    urlString: viewModel.urlString,
                    contactsCount: viewModel.contacts.count,
                    contactsNeedingSelectionCount: viewModel.contactsNeedingSelection.count,
                    manualSelectionsCount: viewModel.manualSelections.count,
                    isMatching: viewModel.isMatching
                ),
                downloadURLFieldVisible: $downloadURLFieldVisible,
                showManualSelectionSheet: $showManualSelectionSheet,
                setURLString: { viewModel.urlString = $0 },
                showPackageSelector: { viewModel.showingPackageSelector = true },
                selectUniformIcon: { viewModel.selectedUniformIcon = $0 },
                startMatching: { viewModel.startMatching() },
                downloadPackageAction: { await viewModel.downloadPackage() }
            )
        case .reviewAndImport:
            ImportContactsPreviewSection(
                viewModel: viewModel,
                expandedContactIds: $expandedContactIds,
                showingAllContactsSheet: $showingAllContactsSheet
            )
        }
    }

    private var isNextEnabled: Bool {
        switch currentStep {
        case .selectPackage:
            !viewModel.selectedPackages.isEmpty || viewModel.currentPackage != nil
        case .selectMode:
            true
        case .configureSelection:
            switch viewModel.importMode {
            case .single:
                viewModel.selectedUniformIcon != nil
            case .sequential:
                viewModel.selectedPackage != nil
            case .manual:
                true
            }
        case .reviewAndImport:
            !viewModel.contacts.isEmpty
        }
    }
}
