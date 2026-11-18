import Contacts
import Foundation

extension ImportAvatarsViewModel {
    // MARK: - Package Management
    func loadSavedPackages() {
        Task { [weak self] in
            guard let self else { return }
            await packageManager.loadSavedPackages()
            applyPendingPackageSelectionIfPossible()
        }
    }

    func downloadPackage() async {
        isLoading = true
        downloadProgress = 0

        do {
            let package = try await packageManager.downloadPackage()
            alertMessage = String(
                format: NSLocalizedString("Avatar package '%@' downloaded and saved", comment: ""),
                package.name
            )
            showingAlert = true
            isLoading = false
            downloadProgress = 1.0
        } catch {
            showError(error.localizedDescription)
        }
    }

    func togglePackageSelection(_ package: AvatarPackage) {
        packageManager.togglePackageSelection(package)
    }

    func isPackageSelected(_ package: AvatarPackage) -> Bool {
        packageManager.isPackageSelected(package)
    }

    func clearPackageSelection() {
        packageManager.clearPackageSelection()
    }

    func selectPackage(_ package: AvatarPackage) {
        packageManager.selectPackage(package)
    }

    func deletePackage(_ package: AvatarPackage) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await packageManager.deletePackage(package)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func loadIcons() {
        packageManager.loadIcons()
    }

    @discardableResult
    func importPackage(from urlString: String) async throws -> String {
        try await packageManager.importPackage(from: urlString)
    }
}
