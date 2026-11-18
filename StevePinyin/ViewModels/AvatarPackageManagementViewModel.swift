import Foundation
import Observation

@Observable
@MainActor
final class AvatarPackageManagementViewModel {
    var urlString = ""
    var isLoading = false
    var downloadProgress = 0.0
    var selectedPackage: IconPackage?
    var selectedPackages: [AvatarPackage] = []
    var savedPackages: [AvatarPackage] = []
    var currentPackage: AvatarPackage?
    var selectedIcons: [Icon] = []
    var sequentialIcons: [Icon] = []

    private let service: AvatarPackageService

    init(service: AvatarPackageService = AvatarPackageService()) {
        self.service = service
    }

    func loadSavedPackages() async {
        savedPackages = await service.loadSavedPackages()
    }

    func downloadPackage() async throws -> AvatarPackage {
        isLoading = true
        downloadProgress = 0

        defer {
            isLoading = false
        }

        let package = try await service.downloadPackage(from: urlString)
        savedPackages = try await service.upsertPackage(package, existingPackages: savedPackages)
        selectPackage(package)
        downloadProgress = 1.0
        return package
    }

    @discardableResult
    func importPackage(from urlString: String) async throws -> String {
        let package = try await service.importPackage(from: urlString, existingPackages: savedPackages)
        savedPackages = try await service.upsertPackage(package, existingPackages: savedPackages)
        return package.id
    }

    func togglePackageSelection(_ package: AvatarPackage) {
        if let index = selectedPackages.firstIndex(where: { $0.id == package.id }) {
            selectedPackages.remove(at: index)
        } else {
            selectedPackages.append(package)
        }

        updateCombinedIcons()
    }

    func isPackageSelected(_ package: AvatarPackage) -> Bool {
        selectedPackages.contains(where: { $0.id == package.id })
    }

    func clearPackageSelection() {
        selectedPackages.removeAll()
        selectedPackage = nil
        currentPackage = nil
        selectedIcons = []
        sequentialIcons = []
    }

    func selectPackage(_ package: AvatarPackage) {
        currentPackage = package
        selectedPackage = IconPackage(
            name: package.name,
            description: package.description,
            icons: package.icons
        )

        selectedIcons = package.icons
        sequentialIcons = Array(package.icons.prefix(10))
    }

    func deletePackage(_ package: AvatarPackage) async throws {
        guard !package.isDefault else { return }

        savedPackages = try await service.deletePackage(package, existingPackages: savedPackages)

        if currentPackage?.id == package.id {
            currentPackage = nil
            selectedPackage = nil
            selectedIcons = []
            sequentialIcons = []
        }

        selectedPackages.removeAll(where: { $0.id == package.id })
    }

    func loadIcons() {
        guard let package = selectedPackage else { return }
        selectedIcons = package.icons
        sequentialIcons = Array(package.icons.prefix(10))
    }

    private func updateCombinedIcons() {
        let allIcons = selectedPackages.flatMap { $0.icons }
        selectedIcons = allIcons
        sequentialIcons = Array(allIcons.prefix(10))

        if !selectedPackages.isEmpty {
            selectedPackage = IconPackage(
                name: selectedPackages.map { $0.name }.joined(separator: ", "),
                description: String(
                    format: NSLocalizedString("Selected %d avatar packages", comment: ""),
                    selectedPackages.count
                ),
                icons: allIcons
            )
            currentPackage = selectedPackages.first
        } else {
            selectedPackage = nil
            currentPackage = nil
        }
    }
}
