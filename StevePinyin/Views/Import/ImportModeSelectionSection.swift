import SwiftUI

struct ImportModeSelectionSection: View {
    let selectedMode: AvatarImportMode
    let onSelectMode: (AvatarImportMode) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(AvatarImportMode.allCases, id: \.self) { mode in
                ImportModeButton(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    action: { onSelectMode(mode) }
                )
            }
        }
    }
}
