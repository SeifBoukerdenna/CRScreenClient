import Foundation
import Combine

/// Manages ReplayKit broadcast state & 4‑digit code
final class BroadcastManager: ObservableObject {
    @Published private(set) var isBroadcasting = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var code: String = "— — — —"

    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    private let kCodeKey = "sessionCode"
    private var timer: AnyCancellable?

    // Use a local cache to avoid constant UserDefaults access
    private var cachedStartDate: Date?
    private var cachedCode: String?

    private var startDate: Date? {
        if let cached = cachedStartDate {
            return cached
        }
        
        // Only read from UserDefaults when needed
        if let defaults = UserDefaults(suiteName: groupID),
           let date = defaults.object(forKey: kStartedAtKey) as? Date {
            cachedStartDate = date
            return date
        }
        return nil
    }

    init() {
        // Setup initial state
        setupInitialState()
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }
    
    private func setupInitialState() {
        // Initialize cached values from UserDefaults
        if let defaults = UserDefaults(suiteName: groupID) {
            cachedCode = defaults.string(forKey: kCodeKey) ?? code
            code = cachedCode ?? code
            
            if let date = defaults.object(forKey: kStartedAtKey) as? Date {
                cachedStartDate = date
                isBroadcasting = true
                elapsed = Date().timeIntervalSince(date)
            }
        }
    }

    func stopIfNeeded() { /* no-op until Apple exposes stop API */ }

    /// Generate & persist a new 4‑digit code
    func prepareNewCode() {
        let newCode = String(format: "%04d", Int.random(in: 0...9999))
        code = newCode
        cachedCode = newCode
        
        // Write to UserDefaults on a background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            UserDefaults(suiteName: self.groupID)?.set(newCode, forKey: self.kCodeKey)
        }
    }

    private func tick() {
        refreshState()
        if isBroadcasting, startDate == nil {
            let now = Date()
            cachedStartDate = now
            
            // Write to UserDefaults on a background thread
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                UserDefaults(suiteName: self.groupID)?.set(now, forKey: self.kStartedAtKey)
            }
            
            elapsed = 0
        }
        else if let s = startDate {
            elapsed = Date().timeIntervalSince(s)
        }
    }

    private func refreshState() {
        isBroadcasting = (startDate != nil)
        if !isBroadcasting { elapsed = 0 }
    }
    
    // Method to clear state when needed
    func resetBroadcastState() {
        cachedStartDate = nil
        
        // Write to UserDefaults on a background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            UserDefaults(suiteName: self.groupID)?.removeObject(forKey: self.kStartedAtKey)
        }
        
        refreshState()
    }
}
