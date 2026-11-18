import AppIntents
import CoreSpotlight
import Foundation

struct AvatarPackageEntity: AppEntity, IndexedEntity, OwnershipProvidingEntity, Identifiable {
    let id: String
    let name: String
    let packageDescription: String
    let iconCount: Int

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "头像包")
    static var defaultQuery = AvatarPackageEntityQuery()

    var ownership: EntityOwnership {
        .unknown
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(iconCount) 个头像"
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = packageDescription.isEmpty
            ? "\(iconCount) 个联系人头像"
            : "\(packageDescription)（\(iconCount) 个头像）"
        attributes.keywords = ["头像", "通讯录", "StevePinyin", name]
        return attributes
    }

    init(package: AvatarPackage) {
        id = package.id
        name = package.name
        packageDescription = package.description
        iconCount = package.icons.count
    }
}

struct AvatarPackageEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    private let service = AvatarPackageService()

    func allEntities() async throws -> [AvatarPackageEntity] {
        await service.loadSavedPackages()
            .map(AvatarPackageEntity.init(package:))
    }

    func entities(for identifiers: [AvatarPackageEntity.ID]) async throws -> [AvatarPackageEntity] {
        let identifierSet = Set(identifiers)
        return await service.loadSavedPackages()
            .filter { identifierSet.contains($0.id) }
            .map(AvatarPackageEntity.init(package:))
    }

    func entities(matching string: String) async throws -> [AvatarPackageEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let packages = await service.loadSavedPackages()

        guard query.isEmpty == false else {
            return packages.map(AvatarPackageEntity.init(package:))
        }

        return packages
            .filter { package in
                package.name.localizedStandardContains(query) ||
                    package.description.localizedStandardContains(query)
            }
            .map(AvatarPackageEntity.init(package:))
    }

    func suggestedEntities() async throws -> [AvatarPackageEntity] {
        await service.loadSavedPackages()
            .prefix(12)
            .map(AvatarPackageEntity.init(package:))
    }

    func defaultResult() async -> AvatarPackageEntity? {
        await service.loadSavedPackages()
            .first(where: { $0.icons.isEmpty == false })
            .map(AvatarPackageEntity.init(package:))
    }
}
