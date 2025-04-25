import Foundation
import ReplayKit

/// Service handling broadcast setup and management
class BroadcastService {
    static let shared = BroadcastService()
    
    private init() {}
    
    /// Triggers the system broadcast picker UI
    func toggleBroadcast(using button: UIButton?, manager: BroadcastManager) {
        if !manager.isBroadcasting {
            manager.prepareNewCode()
        }
        button?.sendActions(for: .touchUpInside)
    }
    
    /// Formats time interval into readable string
    func formatTimeString(_ t: TimeInterval) -> String {
        return String(format: "%02d:%02d:%02d",
                     Int(t) / 3600, Int(t) / 60 % 60, Int(t) % 60)
    }
}
