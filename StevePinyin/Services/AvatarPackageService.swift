import AppIntents
import CoreSpotlight
import Foundation
enum AvatarPackageServiceError: LocalizedError {
    case emptyURL
    case invalidURL
    case invalidServerResponse
    case serverStatusCode(Int)
    case packageExists
    case invalidPackageFormat
    case noInternet
    case timeout
    case cannotFindHost
    case cannotConnectToHost
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return NSLocalizedString("URL cannot be empty", comment: "")
        case .invalidURL:
            return NSLocalizedString("Invalid URL format", comment: "")
        case .invalidServerResponse:
            return NSLocalizedString("Invalid server response", comment: "")
        case .serverStatusCode(let code):
            return String(format: NSLocalizedString("Server error: status code %d", comment: ""), code)
        case .packageExists:
            return NSLocalizedString("Avatar package with same name exists", comment: "")
        case .invalidPackageFormat:
            return NSLocalizedString("Invalid avatar package format", comment: "")
        case .noInternet:
            return NSLocalizedString("No internet connection", comment: "")
        case .timeout:
            return NSLocalizedString("Download timed out, please check your connection", comment: "")
        case .cannotFindHost:
            return NSLocalizedString("Server host not found", comment: "")
        case .cannotConnectToHost:
            return NSLocalizedString("Cannot connect to server", comment: "")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

actor AvatarPackageService {
    private let storageService: StorageService
    private let storageKey = "savedAvatarPackages"
    private var hasSyncedInitialSpotlightIndex = false

    init(storageService: StorageService = .shared) {
        self.storageService = storageService
    }

    func loadSavedPackages() async -> [AvatarPackage] {
        await PerformanceMonitor.shared.trackAvatarPackageLoading(source: "local saved packages") {
            do {
                if let packages: [AvatarPackage] = try await storageService.load(forKey: storageKey) {
                    let filtered = packages.filter { $0.id != "sf-symbols" }
                    if !hasSyncedInitialSpotlightIndex {
                        hasSyncedInitialSpotlightIndex = true
                        await syncSpotlightIndex(for: filtered)
                    }
                    return filtered
                }
                return []
            } catch {
                return []
            }
        }
    }

    func upsertPackage(_ package: AvatarPackage, existingPackages: [AvatarPackage]) async throws -> [AvatarPackage] {
        var updated = existingPackages

        if let index = updated.firstIndex(where: { $0.name == package.name }) {
            updated[index] = package
        } else {
            updated.append(package)
        }

        try await persistPackages(updated)
        await syncSpotlightIndex(for: updated)
        return updated
    }

    func deletePackage(_ package: AvatarPackage, existingPackages: [AvatarPackage]) async throws -> [AvatarPackage] {
        let updated = existingPackages.filter { $0.id != package.id }
        try await persistPackages(updated)
        try? await CSSearchableIndex(name: "StevePinyinPackages")
            .deleteAppEntities(identifiedBy: [package.id], ofType: AvatarPackageEntity.self)
        return updated
    }

    func importPackage(from rawURLString: String, existingPackages: [AvatarPackage]) async throws -> AvatarPackage {
        let package = try await downloadPackage(from: rawURLString)

        if existingPackages.contains(where: { $0.name == package.name }) {
            throw AvatarPackageServiceError.packageExists
        }

        return package
    }

    func downloadPackage(from rawURLString: String) async throws -> AvatarPackage {
        try await PerformanceMonitor.shared.trackAvatarPackageLoading(source: "remote package") {
            let trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AvatarPackageServiceError.emptyURL
            }

            let normalizedURLString: String
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                normalizedURLString = trimmed
            } else {
                normalizedURLString = "https://" + trimmed
            }

            guard let url = URL(string: normalizedURLString) else {
                throw AvatarPackageServiceError.invalidURL
            }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AvatarPackageServiceError.invalidServerResponse
                }

                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    throw AvatarPackageServiceError.serverStatusCode(httpResponse.statusCode)
                }

                do {
                    let remotePackage = try JSONDecoder().decode(RemoteAvatarPackage.self, from: data)

                    return AvatarPackage(
                        id: UUID().uuidString,
                        name: remotePackage.name,
                        description: remotePackage.description,
                        icons: remotePackage.icons.map { icon in
                            Icon(
                                name: icon.name.replacingOccurrences(of: ".png", with: ""),
                                url: icon.url
                            )
                        },
                        isDefault: false,
                        createdAt: Date()
                    )
                } catch {
                    throw AvatarPackageServiceError.invalidPackageFormat
                }
            } catch let error as AvatarPackageServiceError {
                throw error
            } catch let error as URLError {
                switch error.code {
                case .timedOut:
                    throw AvatarPackageServiceError.timeout
                case .notConnectedToInternet:
                    throw AvatarPackageServiceError.noInternet
                case .cannotFindHost:
                    throw AvatarPackageServiceError.cannotFindHost
                case .cannotConnectToHost:
                    throw AvatarPackageServiceError.cannotConnectToHost
                default:
                    throw AvatarPackageServiceError.unknown(error)
                }
            } catch {
                throw AvatarPackageServiceError.unknown(error)
            }
        }
    }

    private func persistPackages(_ packages: [AvatarPackage]) async throws {
        try await storageService.save(packages.filter { !$0.isDefault }, forKey: storageKey)
    }

    private func syncSpotlightIndex(for packages: [AvatarPackage]) async {
        let entities = packages.map(AvatarPackageEntity.init(package:))
        guard entities.isEmpty == false else { return }
        try? await CSSearchableIndex(name: "StevePinyinPackages").indexAppEntities(entities)
    }
}

private struct RemoteAvatarPackage: Decodable {
    let name: String
    let icons: [RemoteIcon]
    let description: String

    struct RemoteIcon: Decodable {
        let name: String
        let url: String
    }
}
