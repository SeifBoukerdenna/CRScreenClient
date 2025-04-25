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
            
            // Set the quality level before starting broadcast
            setQualityLevel(manager.qualityLevel.rawValue)
        }
        button?.sendActions(for: .touchUpInside)
    }
    
    /// Sets the quality level for the upcoming broadcast
    private func setQualityLevel(_ quality: String) {
        // Pass quality level to broadcast extension via setup info dictionary
        let setupInfo: [String: Any] = ["qualityLevel": quality]
        
        // Save to UserDefaults with App Group as well for redundancy
        let groupID = "group.com.elmelz.crcoach"
        let defaults = UserDefaults(suiteName: groupID)
        defaults?.set(quality, forKey: "streamQuality")
        
        if Constants.FeatureFlags.enableDebugLogging {
            print("Set broadcast quality to: \(quality)")
        }
    }

    /// Formats time interval into readable string
    func formatTimeString(_ t: TimeInterval) -> String {
        return String(format: "%02d:%02d:%02d",
                     Int(t) / 3600, Int(t) / 60 % 60, Int(t) % 60)
    }
}
