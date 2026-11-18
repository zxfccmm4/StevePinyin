import Foundation
import SwiftUI

protocol AvatarImageDataResolving {
    func imageData(for icon: Icon) async throws -> Data
}

final class AvatarImageDataResolverUseCase: AvatarImageDataResolving {
    private let cache = AvatarImageDataCache()

    func imageData(for icon: Icon) async throws -> Data {
        if let cachedData = await cache.data(for: icon) {
            return cachedData
        }

        if icon.isSystemIcon {
            guard let symbolName = icon.systemSymbolName else {
                throw NSError(
                    domain: "AvatarError",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid system icon name"]
                )
            }
            let data = try await generateSystemIconData(symbolName: symbolName)
            await cache.store(data, for: icon)
            return data
        }

        guard let url = icon.remoteURL else {
            throw NSError(
                domain: "AvatarError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid URL format", comment: "")]
            )
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else
        {
            throw NSError(
                domain: "AvatarError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid server response", comment: "")]
            )
        }

        await cache.store(data, for: icon)
        return data
    }

    private func generateSystemIconData(symbolName: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let image = Image(systemName: symbolName)
                    .font(.system(size: 100, weight: .medium))
                    .foregroundColor(.black)

                let renderer = ImageRenderer(content: image)
                renderer.scale = 3.0

                if let uiImage = renderer.uiImage {
                    if let data = uiImage.pngData() {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "AvatarError",
                                code: 4,
                                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Could not convert system icon to PNG data", comment: "")]
                            )
                        )
                    }
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "AvatarError",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Could not create system icon", comment: "")]
                        )
                    )
                }
            }
        }
    }
}

private actor AvatarImageDataCache {
    private var storage: [Icon: Data] = [:]

    func data(for icon: Icon) -> Data? {
        storage[icon]
    }

    func store(_ data: Data, for icon: Icon) {
        storage[icon] = data
    }
}
