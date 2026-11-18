import Foundation

struct BuildAvatarImportSummaryUseCase {
    func execute(result: AvatarImportResult) -> String {
        String(
            format: NSLocalizedString("Import complete\nSuccess: %d\nFailed: %d", comment: ""),
            result.successCount,
            result.failureCount
        )
    }
}
