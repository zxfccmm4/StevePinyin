import SwiftUI

struct DetectionProgressView: View {
    let progress: Float
    @State private var isPulsing = false

    var body: some View {
        GlassSectionCard(cornerRadius: 28, padding: 32, tint: .orange) {
            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.22), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                        )
                        .frame(width: 190, height: 190)
                        .scaleEffect(isPulsing ? 1.15 : 0.92)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isPulsing)

                    Circle()
                        .stroke(Color.orange.opacity(0.16), lineWidth: 12)
                        .frame(width: 136, height: 136)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 136, height: 136)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.45), value: progress)

                    VStack(spacing: 4) {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(NSLocalizedString("Detecting", comment: ""))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    Text(NSLocalizedString("Detecting Duplicate Contacts", comment: ""))
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text(NSLocalizedString("Please wait while we scan your contacts for duplicates", comment: ""))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                isPulsing = true
            }
        }
    }
}

struct DuplicateDeletingOverlay: View {
    var duplicateManager: DuplicateContactManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.red)

                VStack(spacing: 8) {
                    Text(NSLocalizedString("Deleting...", comment: ""))
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    if !duplicateManager.currentDeletingContact.isEmpty {
                        Text(duplicateManager.currentDeletingContact)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        if duplicateManager.totalContactsToDelete > 0 {
                            Text(String.localizedStringWithFormat(
                                NSLocalizedString("Contact %d of %d", comment: ""),
                                duplicateManager.currentDeletingIndex,
                                duplicateManager.totalContactsToDelete
                            ))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(NSLocalizedString("This may take a moment", comment: ""))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if duplicateManager.deleteProgress > 0 {
                    ProgressView(value: Double(duplicateManager.deleteProgress), total: 1.0)
                        .tint(.red)
                        .frame(width: 220)
                }

                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                    duplicateManager.cancelDeletion()
                }
                .buttonStyle(.glass)
            }
            .padding(28)
            .frame(maxWidth: 300)
            .glassCard(cornerRadius: 24, tint: .red)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}
