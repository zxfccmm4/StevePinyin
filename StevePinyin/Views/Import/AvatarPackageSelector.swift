import AppIntents
import SwiftUI

struct AvatarPackageSelector: View {
    @Bindable var viewModel: ImportAvatarsViewModel
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory: PackageCategory = .all
    @State private var showingImportSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedSortOption: SortOption = .newest
    @State private var newlyImportedPackageId: String?
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var highlightResetTask: Task<Void, Never>?
    #if DEBUG
    @State private var debugDetailPackage: AvatarPackage?
    #endif
    @Environment(\.dismiss) private var dismiss

    var isMultiSelectMode: Bool = true

    private let gridColumns = [
        GridItem(.flexible(), spacing: AvatarPackageGridConstants.spacing),
        GridItem(.flexible(), spacing: AvatarPackageGridConstants.spacing),
    ]

    private var selectedPackageIDs: Set<String> {
        Set(viewModel.selectedPackages.map(\.id))
    }

    private var normalizedSearchText: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var packageCategoryCounts: [PackageCategory: Int] {
        let packages = viewModel.savedPackages
        let systemCount = packages.reduce(into: 0) { partialResult, package in
            if package.isDefault {
                partialResult += 1
            }
        }

        return [
            .all: packages.count,
            .system: systemCount,
            .custom: packages.count - systemCount,
        ]
    }

    private var filteredPackages: [AvatarPackage] {
        let query = normalizedSearchText
        let filteredBySearch = viewModel.savedPackages.filter { package in
            query.isEmpty ||
                package.name.localizedStandardContains(query) ||
                package.description.localizedStandardContains(query)
        }

        let filteredByCategory = filteredBySearch.filter { package in
            switch selectedCategory {
            case .all:
                return true
            case .system:
                return package.isDefault
            case .custom:
                return !package.isDefault
            }
        }

        return filteredByCategory.sorted { lhs, rhs in
            switch selectedSortOption {
            case .newest:
                return lhs.createdAt > rhs.createdAt
            case .oldest:
                return lhs.createdAt < rhs.createdAt
            case .name:
                return lhs.name < rhs.name
            case .iconCount:
                return lhs.icons.count > rhs.icons.count
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedPackages.isEmpty {
                    ScrollView {
                        GlassEffectContainer(spacing: 18) {
                            emptyStateView
                                .padding(.horizontal, 16)
                                .padding(.top, 28)
                        }
                    }
                } else {
                    ScrollView {
                        GlassEffectContainer(spacing: 16) {
                            VStack(spacing: 16) {
                                categoryPickerSection

                                if filteredPackages.isEmpty {
                                    ContentUnavailableView.search(text: searchText)
                                        .padding(.top, 28)
                                } else {
                                    LazyVGrid(columns: gridColumns, spacing: AvatarPackageGridConstants.spacing) {
                                        ForEach(filteredPackages) { package in
                                            let isNewlyImported = package.id == newlyImportedPackageId

                                            if isMultiSelectMode {
                                                GridMultiSelectCard(
                                                    package: package,
                                                    isSelected: selectedPackageIDs.contains(package.id),
                                                    isNewlyImported: isNewlyImported,
                                                    onToggle: {
                                                        HapticManager.light()
                                                        viewModel.togglePackageSelection(package)
                                                    },
                                                    onDelete: {
                                                        viewModel.deletePackage(package)
                                                    }
                                                )
                                                .appEntityIdentifier(
                                                    EntityIdentifier(for: AvatarPackageEntity.self, identifier: package.id)
                                                )
                                            } else {
                                                GridPackageCard(
                                                    package: package,
                                                    isNewlyImported: isNewlyImported,
                                                    onSelect: {
                                                        HapticManager.light()
                                                        viewModel.selectPackage(package)
                                                        dismiss()
                                                    },
                                                    onDelete: {
                                                        viewModel.deletePackage(package)
                                                    }
                                                )
                                                .appEntityIdentifier(
                                                    EntityIdentifier(for: AvatarPackageEntity.self, identifier: package.id)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(
                isMultiSelectMode
                    ? NSLocalizedString("Select Avatar Packages", comment: "")
                    : NSLocalizedString("Select Avatar Package", comment: "")
            )
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: Text(NSLocalizedString("Search packages", comment: ""))
            )
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    HapticManager.selection()
                                    selectedSortOption = option
                                } label: {
                                    Label(option.title, systemImage: option.icon)
                                    if selectedSortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .symbolRenderingMode(.hierarchical)
                        }

                        Button {
                            HapticManager.light()
                            showingImportSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }

                if isMultiSelectMode {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("Done", comment: "")) {
                            HapticManager.medium()
                            dismiss()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.selectedPackages.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportPackageView(
                viewModel: viewModel,
                isPresented: $showingImportSheet,
                onImportSuccess: { packageId in
                    highlightNewlyImportedPackage(packageId)
                }
            )
        }
        .alert(NSLocalizedString("Error", comment: ""), isPresented: $showingError) {
            Button(NSLocalizedString("OK", comment: "")) {}
        } message: {
            Text(errorMessage)
        }
        #if DEBUG
        .sheet(item: $debugDetailPackage) { package in
            PackageDetailView(package: package, selectedIcons: .constant([:]))
        }
        #endif
        .task {
            viewModel.loadSavedPackages()
            #if DEBUG
            if let sheet = UserDefaults.standard.string(forKey: "initialPackageSheet") {
                try? await Task.sleep(for: .milliseconds(250))
                switch sheet {
                case "import":
                    showingImportSheet = true
                case "detail":
                    debugDetailPackage = viewModel.savedPackages.first
                default:
                    break
                }
            }
            #endif
        }
        .onAppear {
            debouncedSearchText = searchText
        }
        .onDisappear {
            searchDebounceTask?.cancel()
            highlightResetTask?.cancel()
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(180))
                guard Task.isCancelled == false else { return }
                debouncedSearchText = newValue
            }
        }
    }

    private var categoryPickerSection: some View {
        Picker(NSLocalizedString("Category", comment: ""), selection: $selectedCategory) {
            ForEach(PackageCategory.allCases, id: \.self) { category in
                Text("\(category.title) (\(packageCountForCategory(category)))")
                    .tag(category)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyStateView: some View {
        GlassSectionCard(cornerRadius: 26, padding: 28, tint: .blue) {
            VStack(spacing: 20) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 84, height: 84)
                    .glassCapsule(tint: .blue)

                VStack(spacing: 8) {
                    Text(NSLocalizedString("No packages yet", comment: ""))
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text(NSLocalizedString("Import your first avatar package to get started", comment: ""))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    HapticManager.medium()
                    showingImportSheet = true
                } label: {
                    Label(NSLocalizedString("Import Package", comment: ""), systemImage: "plus.circle.fill")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func highlightNewlyImportedPackage(_ packageId: String) {
        highlightResetTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            newlyImportedPackageId = packageId
        }
        highlightResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                newlyImportedPackageId = nil
            }
        }
    }

    private func packageCountForCategory(_ category: PackageCategory) -> Int {
        packageCategoryCounts[category, default: 0]
    }
}

#Preview {
    AvatarPackageSelector(viewModel: ImportAvatarsViewModel())
}
