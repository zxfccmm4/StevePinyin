import SwiftUI

struct StepNavigationBar: View {
    @Binding var currentStep: ImportStep
    let canProceed: Bool
    let importMode: AvatarImportMode
    let onComplete: () -> Void
    let onCancel: () -> Void

    private var stepAccent: Color {
        switch currentStep {
        case .selectPackage: .blue
        case .selectMode: .green
        case .configureSelection: .orange
        case .reviewAndImport: importMode == .manual ? .purple : .blue
        }
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            GlassSectionCard(cornerRadius: 24, padding: 14, tint: stepAccent) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: currentStep.icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(stepAccent.gradient, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                String(
                                    format: NSLocalizedString("Step %d of %d", comment: ""),
                                    currentStep.rawValue + 1,
                                    ImportStep.allCases.count
                                )
                            )
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                            Text(currentStep.description)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 12) {
                        if currentStep != .selectPackage {
                            Button {
                                withAnimation(.snappy) {
                                    currentStep = currentStep.previousStep ?? currentStep
                                }
                            } label: {
                                Label(NSLocalizedString("Back", comment: ""), systemImage: "chevron.left")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.glass)
                        }

                        Button {
                            if currentStep == .reviewAndImport {
                                onComplete()
                            } else {
                                withAnimation(.snappy) {
                                    currentStep = currentStep.nextStep ?? currentStep
                                }
                            }
                        } label: {
                            Label(
                                currentStep == .reviewAndImport
                                    ? NSLocalizedString("Start Import", comment: "")
                                    : NSLocalizedString("Continue", comment: ""),
                                systemImage: currentStep == .reviewAndImport ? "sparkles" : "arrow.right"
                            )
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(stepAccent)
                        .disabled(!canProceed)
                    }
                }
            }
        }
    }
}
