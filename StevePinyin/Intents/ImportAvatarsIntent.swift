//
//  ImportAvatarsIntent.swift
//  StevePinyin
//
//  App Intent - 导入头像
//

import AppIntents
import Foundation

// MARK: - 导入头像 Intent
struct ImportAvatarsIntent: AppIntent {
    static let title: LocalizedStringResource = "导入联系人头像"
    static let description = IntentDescription("打开头像导入流程，并按指定模式和头像包预填参数。")
    static let openAppWhenRun = true

    @Parameter(title: "导入模式")
    var mode: AvatarImportModeIntentValue

    @Parameter(title: "头像包")
    var package: AvatarPackageEntity?

    init() {}

    init(mode: AvatarImportModeIntentValue, package: AvatarPackageEntity? = nil) {
        self.mode = mode
        self.package = package
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentRouter.shared.handleImportIntent(
                packageID: package?.id,
                matchMode: mode.importMode
            )
        }

        return .result(dialog: "已打开头像导入流程。")
    }
}
