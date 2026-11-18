import Contacts
import Observation
import SwiftUI

@Observable
@MainActor
final class ImportVCardViewModel {
    var urlString = ""
    var isLoading = false
    var showAlert = false
    var alertMessage = ""
    var alertTone: ModernAlertTone = .info
    var importedContacts: [CNContact] = []
    var isFilePickerPresented = false
    var showDeleteConfirmation = false
    var showURLInputAlert = false
    var showChinaYellowPagesConfirmation = false
    var isImporting = false
    var importProgress = 0
    var importTotal = 0
    var importPhase: String = ""

    private let service: VCardImportService
    private let batchCoordinator: BatchTaskCoordinator
    private var activeImportTask: Task<Void, Never>?
    private let chinaYellowPagesURL = "https://raw.githubusercontent.com/zxfccmm4/StevePinyin/refs/heads/main/全部.vcf"

    init(
        service: VCardImportService = VCardImportService(),
        batchCoordinator: BatchTaskCoordinator? = nil
    ) {
        self.service = service
        self.batchCoordinator = batchCoordinator ?? .shared
    }

    func presentFilePicker() {
        isFilePickerPresented = true
    }

    func presentDeleteConfirmation() {
        showDeleteConfirmation = true
    }

    func presentURLInput() {
        showURLInputAlert = true
    }

    func presentChinaYellowPagesConfirmation() {
        showChinaYellowPagesConfirmation = true
    }

    func importChinaYellowPages() async {
        guard let url = URL(string: chinaYellowPagesURL) else {
            presentAlert(String(localized: "invalid_china_url"))
            return
        }

        isImporting = true
        importProgress = 0
        importTotal = 0
        importPhase = NSLocalizedString("Downloading...", comment: "")

        let taskID = batchCoordinator.beginTask(
            title: NSLocalizedString("China Yellow Pages", comment: ""),
            subtitle: importPhase,
            totalCount: 0
        )
        defer {
            isImporting = false
            batchCoordinator.finishTask(id: taskID)
        }

        guard await ensureContactAccess() else { return }

        do {
            let data = try await service.downloadData(from: url)

            importPhase = NSLocalizedString("Importing contacts...", comment: "")
            batchCoordinator.updateTask(id: taskID, processedCount: 0, totalCount: 0, subtitle: importPhase)

            let contacts = try await service.importContactsWithProgress(from: data) { [weak self] current, total in
                self?.importProgress = current
                self?.importTotal = total
                self?.batchCoordinator.updateTask(
                    id: taskID,
                    processedCount: current,
                    totalCount: total,
                    subtitle: self?.importPhase
                )
            }

            showImportSuccess(contacts)
        } catch is CancellationError {
            return
        } catch VCardImportError.emptyData {
            presentAlert(String(localized: "no_data_received"), tone: .info)
        } catch VCardImportError.noContacts {
            presentAlert(localized("No Contacts Found"), tone: .info)
        } catch VCardImportError.permissionDenied {
            presentAlert(localized("Permission Denied"), tone: .permission)
        } catch {
            presentAlert(String(format: String(localized: "china_download_failed"), error.localizedDescription))
        }
    }

    func importFromEnteredURL() async {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), !trimmedURL.isEmpty else {
            presentAlert(localized("Invalid URL"))
            return
        }

        await importFromRemoteURL(
            url,
            emptyDataMessage: localized("No Data"),
            downloadFailureMessage: { error in
                localizedFormat("Download Failed", error.localizedDescription)
            }
        )
    }

    func importVCardFile(from fileURL: URL) async {
        isLoading = true
        defer { isLoading = false }

        guard await ensureContactAccess() else { return }

        do {
            let contacts = try await service.importContacts(fromFileURL: fileURL)
            showImportSuccess(contacts)
        } catch VCardImportError.emptyFile {
            presentAlert(localized("Empty File"), tone: .info)
        } catch VCardImportError.noContacts {
            presentAlert(localized("No Contacts Found"), tone: .info)
        } catch VCardImportError.permissionDenied {
            presentAlert(localized("Permission Denied"), tone: .permission)
        } catch {
            presentAlert(localizedFormat("Import Failed", error.localizedDescription))
        }
    }

    func deleteEmptyNameContacts() async {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
            importedContacts.removeAll()
        }

        isLoading = true
        defer { isLoading = false }

        guard await ensureContactAccess() else { return }

        do {
            let deletedCount = try await service.deleteEmptyNameContacts()
            if deletedCount > 0 {
                presentAlert(
                    localizedFormat("Successfully deleted %d contacts", deletedCount),
                    tone: .success
                )
            } else {
                presentAlert(localized("No matching contacts found"), tone: .info)
            }
        } catch {
            presentAlert(
                localizedFormat("Delete failed: %@", error.localizedDescription),
                tone: .error
            )
        }
    }

    private func importFromRemoteURL(
        _ url: URL,
        emptyDataMessage: String,
        downloadFailureMessage: (Error) -> String
    ) async {
        isLoading = true
        defer { isLoading = false }

        guard await ensureContactAccess() else { return }

        do {
            let data = try await service.downloadData(from: url)
            let contacts = try await service.importContacts(from: data)
            showImportSuccess(contacts)
        } catch VCardImportError.emptyData {
            presentAlert(emptyDataMessage, tone: .info)
        } catch VCardImportError.noContacts {
            presentAlert(localized("No Contacts Found"), tone: .info)
        } catch VCardImportError.permissionDenied {
            presentAlert(localized("Permission Denied"), tone: .permission)
        } catch {
            presentAlert(downloadFailureMessage(error))
        }
    }

    private func ensureContactAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            do {
                let granted = try await service.requestAccess()
                if !granted {
                    presentAlert(localized("Permission Denied"), tone: .permission)
                }
                return granted
            } catch {
                presentAlert(localizedFormat("Access Error", error.localizedDescription), tone: .error)
                return false
            }
        case .denied, .restricted:
            presentAlert(localized("Permission Denied"), tone: .permission)
            return false
        @unknown default:
            presentAlert(localized("Permission Denied"), tone: .permission)
            return false
        }
    }

    private func showImportSuccess(_ contacts: [CNContact]) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            importedContacts = contacts
        }
        presentAlert(localizedFormat("Import Success", contacts.count), tone: .success)
    }

    private func presentAlert(_ message: String, tone: ModernAlertTone = .error) {
        alertMessage = message
        alertTone = tone
        showAlert = true
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments)
    }
}
