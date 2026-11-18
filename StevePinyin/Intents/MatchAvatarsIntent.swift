//
//  MatchAvatarsIntent.swift
//  StevePinyin
//
//  App Intent - 匹配头像
//

import AppIntents
import Foundation

// MARK: - 匹配头像 Intent
struct MatchAvatarsIntent: AppIntent {
    static let title: LocalizedStringResource = "匹配联系人头像"
    static let description = IntentDescription("在后台根据已保存头像包进行联系人头像匹配预检。")
    static let openAppWhenRun = false

    @Parameter(title: "头像包")
    var package: AvatarPackageEntity?

    init() {}

    init(package: AvatarPackageEntity? = nil) {
        self.package = package
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try await StevePinyinIntentExecutionService()
            .prepareAvatarMatches(
                packageID: package?.id,
                mode: .sequential
            )

        await MainActor.run {
            IntentRouter.shared.handleMatchResult(
                matchedCount: summary.matchedCount,
                totalContacts: summary.totalContacts
            )
        }

        return .result(dialog: IntentDialog(stringLiteral: summary.dialog))
    }
}
