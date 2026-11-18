import AppIntents
import Foundation

struct AddContactsPinyinIntent: AppIntent {
    static let title: LocalizedStringResource = "批量添加通讯录拼音"
    static let description = IntentDescription("自动为通讯录中的中文联系人生成姓名和公司拼音，支持多音字姓氏识别。")
    static let openAppWhenRun = false

    @Parameter(title: "拼音格式", default: .withTone)
    var format: PinyinFormatIntentValue

    init() {}

    init(format: PinyinFormatIntentValue = .withTone) {
        self.format = format
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try await StevePinyinIntentExecutionService()
            .addContactsPinyin(format: format.pinyinFormat)
        _ = try? await IntentDonationManager.shared.donate(intent: self)
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

struct EnableT9SearchIntent: AppIntent {
    static let title: LocalizedStringResource = "开启通讯录 T9 拨号搜索"
    static let description = IntentDescription("为通讯录联系人生成拨号键盘拼音缩写，强化电话 App T9 快速拨号检索。")
    static let openAppWhenRun = false

    @Parameter(title: "T9 编码格式", default: .plainNoSpace)
    var format: T9FormatIntentValue

    init() {}

    init(format: T9FormatIntentValue = .plainNoSpace) {
        self.format = format
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try await StevePinyinIntentExecutionService()
            .enableT9Search(format: format.pinyinFormat)
        _ = try? await IntentDonationManager.shared.donate(intent: self)
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

@AppIntent(schema: .system.searchInApp)
struct SearchContactsInAppIntent: ShowInAppSearchResultsIntent {
    static let title: LocalizedStringResource = "在 StevePinyin 中搜索联系人"
    static let description = IntentDescription("打开 StevePinyin 并检索已处理联系人的姓名、拼音或公司。")
    static let openAppWhenRun = true
    static let searchScopes: [StringSearchScope] = [.general]

    @Parameter(title: "搜索词")
    var criteria: StringSearchCriteria

    init() {}

    init(criteria: StringSearchCriteria) {
        self.criteria = criteria
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.handleSearchInApp(query: criteria.term)
        return .result()
    }
}
