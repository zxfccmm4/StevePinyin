import SwiftUI

struct ImportAvatarsLoadingOverlay: View {
    var viewModel: ImportAvatarsViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)

                VStack(spacing: 12) {
                    Text(NSLocalizedString("Processing...", comment: ""))
                        .font(.headline)
                        .foregroundStyle(.white)

                    if viewModel.currentProcessingContact.isEmpty == false {
                        VStack(spacing: 6) {
                            Text(NSLocalizedString("Currently processing:", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))

                            Text(viewModel.currentProcessingContact)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if viewModel.totalContactsToProcess > 0 {
                                Text(
                                    String.localizedStringWithFormat(
                                        NSLocalizedString("Contact %d of %d", comment: ""),
                                        viewModel.currentProcessingIndex,
                                        viewModel.totalContactsToProcess
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        Text(NSLocalizedString("This may take a moment", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                if viewModel.downloadProgress > 0 {
                    VStack(spacing: 8) {
                        ImportProgressBar(value: viewModel.downloadProgress)
                            .frame(width: 240)

                        Text("\(Int(viewModel.downloadProgress * 100))%")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(32)
            .glassCard(cornerRadius: 20)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}
