import Foundation
import SwiftUI

enum Constants {
    enum URLs {
        static let demoVideo = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        static let broadcastServer = "http://192.168.2.12:8080/upload/"
//        static let broadcastServer = "http://172.20.10.3:8080/upload/"
        static let webApp = "royaltrainer.com"
    }
    
    enum AppGroup {
        static let identifier = "group.com.elmelz.crcoach"
    }
        
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonBorderWidth: CGFloat = 3
        static let animationDuration: Double = 0.3
        static let defaultPadding: CGFloat = 16
    }
    
    enum Broadcast {
        static let extensionID = "com.elmelz.CRScreenClient.Broadcast"
        static let groupID = "group.com.elmelz.crcoach"
        static let recordingKey = "lastRecordingPath"
    }
    
    enum FeatureFlags {
            static let enablePictureInPicture = true
            static let enableDebugLogging = true
            static let useLocalVideoOnly = false
        }
}

public enum StreamQuality: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Ultra-low latency, minimal bandwidth"
        case .medium: return "Balanced quality and responsiveness"
        case .high: return "Maximum clarity, best visuals"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "bolt.fill"
        case .medium: return "align.horizontal.center"
        case .high: return "4k.tv"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .crGold
        case .high: return .crPurple
        }
    }
    
    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.85
        }
    }
    
    var frameSkip: Int {
        switch self {
        case .low: return 2
        case .medium: return 1
        case .high: return 0
        }
    }
    
    var downsizeFactor: CGFloat {
        switch self {
        case .low: return 0.6
        case .medium: return 0.8
        case .high: return 1.0
        }
    }
}
