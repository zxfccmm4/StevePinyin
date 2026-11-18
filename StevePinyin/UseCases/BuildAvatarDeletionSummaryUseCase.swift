import Foundation

struct BuildAvatarDeletionSummaryUseCase {
    func execute(result: AvatarDeletionResult) -> String {
        var alertMessage = String(
            format: NSLocalizedString("Successfully deleted %d contact avatars", comment: ""),
            result.successCount
        )

        if result.failureCount > 0 {
            alertMessage += String(
                format: NSLocalizedString("\nFailed %d", comment: ""),
                result.failureCount
            )
        }

        return alertMessage
    }
}
