import Foundation

/// Application-wide storage service that handles data persistence
class AppStorage {
    static let shared = AppStorage()
    
    private let groupID = "group.com.elmelz.crcoach"
    private let broadcastStartedKey = "broadcastStartedAt"
    private let sessionCodeKey = "sessionCode"
    
    private var cache: [String: Any] = [:]
    
    private init() {
        loadInitialCache()
    }
    
    private func loadInitialCache() {
        if let defaults = UserDefaults(suiteName: groupID) {
            if let code = defaults.string(forKey: sessionCodeKey) {
                cache[sessionCodeKey] = code
            }
            if let date = defaults.object(forKey: broadcastStartedKey) as? Date {
                cache[broadcastStartedKey] = date
            }
        }
    }
    
    func getValue<T>(for key: String) -> T? {
        return cache[key] as? T
    }
    
    func setValue<T>(_ value: T?, for key: String) {
        // Update cache
        if let value = value {
            cache[key] = value
        } else {
            cache.removeValue(forKey: key)
        }
        
        // Update UserDefaults on background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let defaults = UserDefaults(suiteName: self.groupID)
            
            if let value = value {
                defaults?.set(value, forKey: key)
            } else {
                defaults?.removeObject(forKey: key)
            }
        }
    }
    
    // Helper methods for commonly used values
    var broadcastStartDate: Date? {
        get { getValue(for: broadcastStartedKey) }
        set { setValue(newValue, for: broadcastStartedKey) }
    }
    
    var sessionCode: String {
        get { getValue(for: sessionCodeKey) ?? "— — — —" }
        set { setValue(newValue, for: sessionCodeKey) }
    }
    
    func generateNewSessionCode() -> String {
        let newCode = String(format: "%04d", Int.random(in: 0...9999))
        sessionCode = newCode
        return newCode
    }
}
