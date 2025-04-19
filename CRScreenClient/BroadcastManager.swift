import Foundation
import Combine

/// Manages ReplayKit broadcast state & 4‑digit code
final class BroadcastManager: ObservableObject {
    @Published private(set) var isBroadcasting = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var code: String = "— — — —"

    private let groupID       = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    private let kCodeKey      = "sessionCode"
    private var timer: AnyCancellable?

    private var startDate: Date? {
        UserDefaults(suiteName: groupID)?
            .object(forKey: kStartedAtKey) as? Date
    }

    init() {
        // recover code if already live
        code = UserDefaults(suiteName: groupID)?
            .string(forKey: kCodeKey) ?? code

        refreshState()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stopIfNeeded() { /* no-op until Apple exposes stop API */ }

    /// Generate & persist a new 4‑digit code
    func prepareNewCode() {
        let newCode = String(format: "%04d", Int.random(in: 0...9999))
        code = newCode
        UserDefaults(suiteName: groupID)?
            .set(newCode, forKey: kCodeKey)
    }

    private func tick() {
        refreshState()
        if isBroadcasting, startDate == nil {
            UserDefaults(suiteName: groupID)?
                .set(Date(), forKey: kStartedAtKey)
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
}
