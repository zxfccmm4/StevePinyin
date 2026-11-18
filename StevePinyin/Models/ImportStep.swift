import SwiftUI

/// 导入步骤枚举
/// 定义导入流程的各个步骤
enum ImportStep: Int, CaseIterable, Identifiable {
    case selectPackage = 0
    case selectMode = 1
    case configureSelection = 2
    case reviewAndImport = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .selectPackage:
            return ImportStepStrings.selectPackage
        case .selectMode:
            return ImportStepStrings.chooseMode
        case .configureSelection:
            return ImportStepStrings.configure
        case .reviewAndImport:
            return ImportStepStrings.reviewAndImport
        }
    }
    
    var icon: String {
        switch self {
        case .selectPackage:
            return "square.stack.3d.up.fill"
        case .selectMode:
            return "arrow.triangle.branch"
        case .configureSelection:
            return "slider.horizontal.3"
        case .reviewAndImport:
            return "checkmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .selectPackage:
            return ImportStepStrings.selectPackageDescription
        case .selectMode:
            return ImportStepStrings.selectModeDescription
        case .configureSelection:
            return ImportStepStrings.configureSelectionDescription
        case .reviewAndImport:
            return ImportStepStrings.reviewAndImportDescription
        }
    }
    
    var nextStep: ImportStep? {
        guard rawValue < ImportStep.allCases.count - 1 else { return nil }
        return ImportStep(rawValue: rawValue + 1)
    }
    
    var previousStep: ImportStep? {
        guard rawValue > 0 else { return nil }
        return ImportStep(rawValue: rawValue - 1)
    }
}

private enum ImportStepStrings {
    static let selectPackage = String(localized: "Select Package")
    static let chooseMode = String(localized: "Choose Mode")
    static let configure = String(localized: "Configure")
    static let reviewAndImport = String(localized: "Review & Import")
    static let selectPackageDescription = String(localized: "Choose or download an avatar package")
    static let selectModeDescription = String(localized: "Select how to assign avatars")
    static let configureSelectionDescription = String(localized: "Configure your selection")
    static let reviewAndImportDescription = String(localized: "Review and start importing")
}
