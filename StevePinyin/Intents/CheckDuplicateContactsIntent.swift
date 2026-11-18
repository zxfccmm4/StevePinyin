//
//  CheckDuplicateContactsIntent.swift
//  StevePinyin
//
//  App Intent - 检查重复联系人
//

import AppIntents
import Foundation

// MARK: - 检查重复联系人 Intent
struct CheckDuplicateContactsIntent: AppIntent {
    static let title: LocalizedStringResource = "检查重复联系人"
    static let description = IntentDescription("检查通讯录中的重复联系人，并打开 App 查看结果。")
    static let openAppWhenRun = true

    @Parameter(title: "检测范围")
    var scope: DuplicateDetectionScopeIntentValue

    init() {}

    init(scope: DuplicateDetectionScopeIntentValue) {
        self.scope = scope
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try await StevePinyinIntentExecutionService()
            .detectDuplicates(scope: scope)

        await MainActor.run {
            IntentRouter.shared.handleDuplicateCheckResult(groups: summary.groups)
        }

        return .result(dialog: IntentDialog(stringLiteral: summary.dialog))
    }
}
