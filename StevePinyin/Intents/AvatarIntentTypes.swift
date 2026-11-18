import AppIntents
import Foundation

enum AvatarImportModeIntentValue: String, AppEnum {
    case single
    case sequential
    case manual

    static var typeDisplayName: LocalizedStringResource { "头像导入模式" }
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "头像导入模式")

    static var caseDisplayRepresentations: [AvatarImportModeIntentValue: DisplayRepresentation] {
        [
            .single: DisplayRepresentation(title: "统一头像", subtitle: "为联系人应用同一个头像"),
            .sequential: DisplayRepresentation(title: "顺序匹配", subtitle: "按头像包顺序分配头像"),
            .manual: DisplayRepresentation(title: "手动选择", subtitle: "打开 App 后逐个确认头像"),
        ]
    }

    var importMode: AvatarImportMode {
        switch self {
        case .single:
            .single
        case .sequential:
            .sequential
        case .manual:
            .manual
        }
    }

    init(importMode: AvatarImportMode) {
        switch importMode {
        case .single:
            self = .single
        case .sequential:
            self = .sequential
        case .manual:
            self = .manual
        }
    }
}

enum PinyinFormatIntentValue: String, AppEnum {
    case withTone
    case plainLetter
    case plainNoSpace
    case firstLetter
    case firstNoSpace

    static var typeDisplayName: LocalizedStringResource { "拼音格式" }
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "拼音格式")

    static var caseDisplayRepresentations: [PinyinFormatIntentValue: DisplayRepresentation] {
        [
            .withTone: DisplayRepresentation(title: "带声调全拼", subtitle: "如 Zhāng Sān"),
            .plainLetter: DisplayRepresentation(title: "无声调空格全拼", subtitle: "如 Zhang San"),
            .plainNoSpace: DisplayRepresentation(title: "紧凑全拼", subtitle: "如 ZhangSan"),
            .firstLetter: DisplayRepresentation(title: "首字母带空格", subtitle: "如 Z S"),
            .firstNoSpace: DisplayRepresentation(title: "紧凑首字母", subtitle: "如 ZS"),
        ]
    }

    var pinyinFormat: PinyinFormat {
        switch self {
        case .withTone: .withTone
        case .plainLetter: .plainLetter
        case .plainNoSpace: .plainNoSpace
        case .firstLetter: .firstLetter
        case .firstNoSpace: .firstNoSpace
        }
    }
}

enum T9FormatIntentValue: String, AppEnum {
    case plainNoSpace
    case firstNoSpace

    static var typeDisplayName: LocalizedStringResource { "T9 编码格式" }
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "T9 编码格式")

    static var caseDisplayRepresentations: [T9FormatIntentValue: DisplayRepresentation] {
        [
            .plainNoSpace: DisplayRepresentation(title: "全拼 T9 索引", subtitle: "完整姓名与公司全拼检索"),
            .firstNoSpace: DisplayRepresentation(title: "首字母 T9 索引", subtitle: "极简首字母拨号缩写"),
        ]
    }

    var pinyinFormat: PinyinFormat {
        switch self {
        case .plainNoSpace: .plainNoSpace
        case .firstNoSpace: .firstNoSpace
        }
    }
}

enum DuplicateDetectionScopeIntentValue: String, AppEnum {
    case balanced
    case names
    case contactMethods
    case all

    static var typeDisplayName: LocalizedStringResource { "重复检测范围" }
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "重复检测范围")

    static var caseDisplayRepresentations: [DuplicateDetectionScopeIntentValue: DisplayRepresentation] {
        [
            .balanced: DisplayRepresentation(title: "常用检测", subtitle: "姓名、电话和邮箱"),
            .names: DisplayRepresentation(title: "姓名检测", subtitle: "精确姓名和相似姓名"),
            .contactMethods: DisplayRepresentation(title: "联系方式检测", subtitle: "电话和邮箱"),
            .all: DisplayRepresentation(title: "完整检测", subtitle: "包含拼音和相似姓名"),
        ]
    }

    var duplicateTypes: Set<DuplicateType> {
        switch self {
        case .balanced:
            [.exactName, .samePhone, .sameEmail]
        case .names:
            [.exactName, .similarName]
        case .contactMethods:
            [.samePhone, .sameEmail]
        case .all:
            Set(DuplicateType.allCases)
        }
    }
}

enum StevePinyinIntentError: LocalizedError {
    case contactAccessDenied
    case noAvatarPackageAvailable
    case selectedPackageMissing
    case modeRequiresInAppReview

    var errorDescription: String? {
        switch self {
        case .contactAccessDenied:
            return NSLocalizedString("Contacts permission is required before this shortcut can run.", comment: "")
        case .noAvatarPackageAvailable:
            return NSLocalizedString("Please add an avatar package in StevePinyin first.", comment: "")
        case .selectedPackageMissing:
            return NSLocalizedString("The selected avatar package could not be found.", comment: "")
        case .modeRequiresInAppReview:
            return NSLocalizedString("This mode needs in-app review before matching can run.", comment: "")
        }
    }
}
