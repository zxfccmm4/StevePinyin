import SwiftUI

/// 步骤进度条 — iOS 26 Liquid Glass 风格
/// 显示 4 个步骤圆点 + 连线，高亮当前步骤
struct StepProgressBar: View {
    let currentStep: ImportStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ImportStep.allCases) { step in
                stepDot(step)

                if step != ImportStep.allCases.last {
                    connectingLine(after: step)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 20)
    }

    private func stepDot(_ step: ImportStep) -> some View {
        let isCompleted = step.rawValue < currentStep.rawValue
        let isCurrent = step.rawValue == currentStep.rawValue

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        isCompleted || isCurrent
                            ? Color.blue
                            : Color(.systemGray4)
                    )
                    .frame(width: 30, height: 30)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }

            Text(step.shortTitle)
                .font(.system(size: 10, weight: isCurrent ? .bold : .medium, design: .rounded))
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: 56)
    }

    private func connectingLine(after step: ImportStep) -> some View {
        let isCompleted = step.rawValue < currentStep.rawValue

        return Capsule()
            .fill(isCompleted ? Color.blue : Color(.systemGray4))
            .frame(height: 2)
            .padding(.bottom, 20)
    }
}

// MARK: - ImportStep short title extension

extension ImportStep {
    var shortTitle: String {
        switch self {
        case .selectPackage:
            return StepProgressBarStrings.package
        case .selectMode:
            return StepProgressBarStrings.mode
        case .configureSelection:
            return StepProgressBarStrings.config
        case .reviewAndImport:
            return StepProgressBarStrings.import
        }
    }
}

private enum StepProgressBarStrings {
    static let package = String(localized: "Package")
    static let mode = String(localized: "Mode")
    static let config = String(localized: "Config")
    static let `import` = String(localized: "Import")
}

#Preview {
    VStack(spacing: 20) {
        StepProgressBar(currentStep: .selectPackage)
        StepProgressBar(currentStep: .selectMode)
        StepProgressBar(currentStep: .configureSelection)
        StepProgressBar(currentStep: .reviewAndImport)
    }
    .padding()
}
