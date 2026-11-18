import Foundation

struct AvatarImportConfirmationState: Identifiable, Equatable {
    let id = UUID()
    let importMode: AvatarImportMode
    let contactCount: Int
    let uniqueAvatarCount: Int
    let packageName: String?
    let previewNames: [String]

    var title: String {
        NSLocalizedString("Confirm Import", comment: "")
    }

    var modeTitle: String {
        importMode.title
    }

    var primarySummary: String {
        String(
            format: NSLocalizedString("Ready to update %d contacts with %d avatars.", comment: ""),
            contactCount,
            uniqueAvatarCount
        )
    }

    var packageSummary: String {
        packageName ?? NSLocalizedString("Current avatar selection", comment: "")
    }
}
