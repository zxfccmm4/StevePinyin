import Foundation
@testable import StevePinyin

actor MockAvatarImageDataResolver: AvatarImageDataResolving {
    private let result: Result<Data, Error>
    private var requestedIcons: [Icon] = []

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func imageData(for icon: Icon) async throws -> Data {
        requestedIcons.append(icon)
        return try result.get()
    }

    func requestedIconsSnapshot() -> [Icon] {
        requestedIcons
    }
}
