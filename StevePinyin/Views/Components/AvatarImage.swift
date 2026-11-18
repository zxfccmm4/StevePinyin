import SwiftUI

struct ImportAvatarImage: View {
    let icon: AvatarIcon
    let size: CGFloat

    var body: some View {
        AvatarThumbnailView(source: .icon(icon), size: size)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}
