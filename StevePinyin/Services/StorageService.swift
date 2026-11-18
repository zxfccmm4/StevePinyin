import Foundation

enum StorageError: Error {
    case saveFailed(Error)
    case loadFailed(Error)
    case decodingFailed(Error)
    case encodingFailed(Error)
}

actor StorageService {
    static let shared = StorageService()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        do {
            let data = try JSONEncoder().encode(object)
            defaults.set(data, forKey: key)
        } catch {
            throw StorageError.encodingFailed(error)
        }
    }
    
    func load<T: Codable>(forKey key: String) throws -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw StorageError.decodingFailed(error)
        }
    }
    
    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
    
    func bool(forKey key: String) -> Bool {
        return defaults.bool(forKey: key)
    }
    
    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        return defaults.string(forKey: key)
    }
    
    func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
