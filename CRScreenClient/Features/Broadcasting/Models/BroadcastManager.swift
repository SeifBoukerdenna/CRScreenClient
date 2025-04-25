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
    
    // Add last known state to detect changes
    private var lastKnownBroadcastState = false

    // Use a local cache to avoid constant UserDefaults access
    private var cachedStartDate: Date?
    private var cachedCode: String?

    private var startDate: Date? {
        // Force check UserDefaults every time to detect external changes
        if let defaults = UserDefaults(suiteName: groupID),
           let date = defaults.object(forKey: kStartedAtKey) as? Date {
            cachedStartDate = date
            return date
        }
        
        // If not in UserDefaults, clear the cache too
        cachedStartDate = nil
        return nil
    }

    init() {
        // Setup initial state
        setupInitialState()
        
        // Use a faster timer to detect broadcast stop
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
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
                lastKnownBroadcastState = true
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
        // Get current state from storage (this will check UserDefaults)
        let currentDate = startDate
        let currentBroadcastState = currentDate != nil
        
        // If state changed from broadcasting to not broadcasting, handle it
        if lastKnownBroadcastState && !currentBroadcastState {
            if Constants.FeatureFlags.enableDebugLogging {
                print("Detected broadcast stopped externally")
            }
            resetBroadcastState()
        }
        
        // Update last known state
        lastKnownBroadcastState = currentBroadcastState
        
        // If broadcasting but no cached date, update it
        if isBroadcasting, cachedStartDate == nil, let date = currentDate {
            cachedStartDate = date
            elapsed = Date().timeIntervalSince(date)
        }
        // If broadcasting and have cached date, update elapsed time
        else if isBroadcasting, let s = cachedStartDate {
            elapsed = Date().timeIntervalSince(s)
        }
        // If not broadcasting, make sure elapsed is 0
        else if !isBroadcasting {
            elapsed = 0
        }
        
        // Check if we got out of sync
        if isBroadcasting != currentBroadcastState {
            isBroadcasting = currentBroadcastState
        }
    }

    // Method to clear state when needed
    func resetBroadcastState() {
        if Constants.FeatureFlags.enableDebugLogging {
            print("Resetting broadcast state")
        }
        
        cachedStartDate = nil
        isBroadcasting = false
        elapsed = 0
        
        // Remove from UserDefaults too
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            UserDefaults(suiteName: self.groupID)?.removeObject(forKey: self.kStartedAtKey)
        }
    }
}
