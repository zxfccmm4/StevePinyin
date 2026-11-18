@preconcurrency import Contacts
import ImageIO
import Observation
import SwiftUI
import UIKit

enum AvatarNetworkConfiguration {
    static let urlCache: URLCache = {
        URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "StevePinyinAvatarURLCache", directoryHint: .isDirectory)
        )
    }()

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()
}

enum AvatarImageDownsampler {
    nonisolated static func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        guard data.isEmpty == false else { return nil }
        let targetMaxPixel = max(maxPixelSize, 32)

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxPixel
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}

@Observable
@MainActor
final class AvatarThumbnailStore {
    static let shared = AvatarThumbnailStore()

    private(set) var contactAvatarRevision: Int = 0
    private let decodedCache = NSCache<NSString, UIImage>()
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        decodedCache.countLimit = 400
        decodedCache.totalCostLimit = 64 * 1024 * 1024
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clearDecodedCache()
            }
        }
    }

    func bumpContactAvatarRevision() {
        contactAvatarRevision &+= 1
        decodedCache.removeAllObjects()
    }

    func clearDecodedCache() {
        decodedCache.removeAllObjects()
    }

    func cachedRemoteImage(urlString: String, maxPixelSize: Int) -> UIImage? {
        decodedCache.object(forKey: remoteCacheKey(urlString: urlString, maxPixelSize: maxPixelSize) as NSString)
    }

    func loadRemoteImage(urlString: String, maxPixelSize: Int) async -> UIImage? {
        let bucketedPixelSize = bucketPixelSize(maxPixelSize)
        let key = remoteCacheKey(urlString: urlString, maxPixelSize: bucketedPixelSize)

        if let cached = decodedCache.object(forKey: key as NSString) {
            return cached
        }

        if let existingTask = inFlightTasks[key] {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            do {
                let (data, response) = try await AvatarNetworkConfiguration.session.data(from: url)
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) == false {
                    return nil
                }
                return await Task.detached(priority: .utility) {
                    AvatarImageDownsampler.downsample(data: data, maxPixelSize: bucketedPixelSize)
                }.value
            } catch {
                return nil
            }
        }

        inFlightTasks[key] = task
        let image = await task.value
        inFlightTasks[key] = nil

        if let image {
            decodedCache.setObject(image, forKey: key as NSString, cost: imageCost(image))
        }
        return image
    }

    func cachedContactImage(for contact: CNContact, maxPixelSize: Int) -> UIImage? {
        let key = contactCacheKey(for: contact, maxPixelSize: bucketPixelSize(maxPixelSize))
        return decodedCache.object(forKey: key as NSString)
    }

    func loadContactImage(for contact: CNContact, maxPixelSize: Int) async -> UIImage? {
        let bucketedPixelSize = bucketPixelSize(maxPixelSize)
        let key = contactCacheKey(for: contact, maxPixelSize: bucketedPixelSize)

        if let cached = decodedCache.object(forKey: key as NSString) {
            return cached
        }

        let thumbnailData = contact.isKeyAvailable(CNContactThumbnailImageDataKey) ? contact.thumbnailImageData : nil
        let fullData = contact.isKeyAvailable(CNContactImageDataKey) ? contact.imageData : nil
        let preferredData = (bucketedPixelSize <= 180 ? (thumbnailData ?? fullData) : (fullData ?? thumbnailData))

        guard let preferredData, preferredData.isEmpty == false else {
            return nil
        }

        if let existingTask = inFlightTasks[key] {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> {
            await Task.detached(priority: .utility) {
                AvatarImageDownsampler.downsample(data: preferredData, maxPixelSize: bucketedPixelSize)
            }.value
        }

        inFlightTasks[key] = task
        let decoded = await task.value
        inFlightTasks[key] = nil

        if let decoded {
            decodedCache.setObject(decoded, forKey: key as NSString, cost: imageCost(decoded))
        }
        return decoded
    }

    private func bucketPixelSize(_ pixelSize: Int) -> Int {
        switch pixelSize {
        case ..<96: return 96
        case ..<180: return 180
        case ..<320: return 320
        default: return 512
        }
    }

    private func remoteCacheKey(urlString: String, maxPixelSize: Int) -> String {
        "remote|\(maxPixelSize)|\(urlString)"
    }

    private func contactCacheKey(for contact: CNContact, maxPixelSize: Int) -> String {
        let thumbCount = contact.isKeyAvailable(CNContactThumbnailImageDataKey) ? (contact.thumbnailImageData?.count ?? 0) : -1
        let fullCount = contact.isKeyAvailable(CNContactImageDataKey) ? (contact.imageData?.count ?? 0) : -1
        return "contact|\(contactAvatarRevision)|\(maxPixelSize)|\(contact.stableIdentifier)|\(thumbCount)|\(fullCount)"
    }

    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 4096 }
        return max(cgImage.bytesPerRow * cgImage.height, 1024)
    }
}

struct AvatarThumbnailView: View {
    enum Source: Equatable {
        case icon(AvatarIcon)
        case remoteURL(String)
        case contact(CNContact, fallbackText: String)

        static func == (lhs: Source, rhs: Source) -> Bool {
            switch (lhs, rhs) {
            case let (.icon(a), .icon(b)):
                return a == b
            case let (.remoteURL(a), .remoteURL(b)):
                return a == b
            case let (.contact(a, textA), .contact(b, textB)):
                let aThumb = a.isKeyAvailable(CNContactThumbnailImageDataKey) ? (a.thumbnailImageData?.count ?? 0) : -1
                let bThumb = b.isKeyAvailable(CNContactThumbnailImageDataKey) ? (b.thumbnailImageData?.count ?? 0) : -1
                let aFull = a.isKeyAvailable(CNContactImageDataKey) ? (a.imageData?.count ?? 0) : -1
                let bFull = b.isKeyAvailable(CNContactImageDataKey) ? (b.imageData?.count ?? 0) : -1
                return a.stableIdentifier == b.stableIdentifier &&
                    aThumb == bThumb &&
                    aFull == bFull &&
                    textA == textB
            default:
                return false
            }
        }
    }

    let source: Source
    var size: CGFloat = 48
    var cornerRadius: CGFloat? = nil
    var tint: Color = .accentColor

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private var targetPixelSize: Int {
        Int((size * max(displayScale, 2.0)).rounded(.up))
    }

    private var clipShape: AnyShape {
        if let cornerRadius {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            AnyShape(Circle())
        }
    }

    var body: some View {
        let revision = AvatarThumbnailStore.shared.contactAvatarRevision
        content
            .frame(width: size, height: size)
            .clipShape(clipShape)
            .task(id: taskIdentity(revision: revision)) {
                await loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch source {
        case .icon(let icon) where icon.type == .system:
            ZStack {
                Color(.secondarySystemFill)
                Image(systemName: icon.resolvedSystemSymbolName)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }

        case .icon, .remoteURL:
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ZStack {
                    Color(.secondarySystemFill)
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                ZStack {
                    Color(.secondarySystemFill)
                    Image(systemName: "photo")
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(.secondary)
                }
            }

        case .contact(_, let fallbackText):
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if fallbackInitial(from: fallbackText).isEmpty {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(tint)
                    } else {
                        Text(fallbackInitial(from: fallbackText))
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }

    private func taskIdentity(revision: Int) -> String {
        switch source {
        case .icon(let icon):
            return "icon|\(icon.id)|\(targetPixelSize)"
        case .remoteURL(let url):
            return "url|\(url)|\(targetPixelSize)"
        case .contact(let contact, _):
            let thumbCount = contact.isKeyAvailable(CNContactThumbnailImageDataKey) ? (contact.thumbnailImageData?.count ?? 0) : -1
            let fullCount = contact.isKeyAvailable(CNContactImageDataKey) ? (contact.imageData?.count ?? 0) : -1
            return "contact|\(revision)|\(contact.stableIdentifier)|\(thumbCount)|\(fullCount)|\(targetPixelSize)"
        }
    }

    private func loadIfNeeded() async {
        let store = AvatarThumbnailStore.shared
        switch source {
        case .icon(let icon):
            guard icon.type != .system else {
                loadedImage = nil
                isLoading = false
                return
            }
            if let cached = store.cachedRemoteImage(urlString: icon.url, maxPixelSize: targetPixelSize) {
                loadedImage = cached
                isLoading = false
                return
            }
            isLoading = true
            loadedImage = await store.loadRemoteImage(urlString: icon.url, maxPixelSize: targetPixelSize)
            isLoading = false

        case .remoteURL(let urlString):
            if let cached = store.cachedRemoteImage(urlString: urlString, maxPixelSize: targetPixelSize) {
                loadedImage = cached
                isLoading = false
                return
            }
            isLoading = true
            loadedImage = await store.loadRemoteImage(urlString: urlString, maxPixelSize: targetPixelSize)
            isLoading = false

        case .contact(let contact, _):
            if let cached = store.cachedContactImage(for: contact, maxPixelSize: targetPixelSize) {
                loadedImage = cached
                return
            }
            loadedImage = await store.loadContactImage(for: contact, maxPixelSize: targetPixelSize)
        }
    }

    private func fallbackInitial(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased()
    }
}
