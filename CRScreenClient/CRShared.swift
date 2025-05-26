import Foundation
import SwiftUI

enum Constants {
    enum URLs {
        static let demoVideo = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        
//        // Legacy HTTP endpoints (deprecated)
//        static let broadcastServer = "http://192.168.2.12:8080/upload/"
//        
//        // WebRTC signaling server endpoints
//        static let webRTCSignalingServer = "ws://192.168.2.12:8080/ws"
//        static let webRTCSignalingServerSecure = "wss://192.168.2.12:8080/ws"
        
        // Legacy HTTP endpoints (deprecated)
        static let broadcastServer = "http://10.20.5.212:8080/upload/"
        
        // WebRTC signaling server endpoints
        static let webRTCSignalingServer = "ws://10.20.5.212:8080/ws"
        static let webRTCSignalingServerSecure = "wss://10.20.5.212:8080/ws"
        
        // STUN/TURN servers for WebRTC
        static let stunServers = [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302"
        ]
        
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
    
    enum WebRTC {
        // WebRTC configuration constants
        static let maxReconnectAttempts = 5
        static let reconnectDelay: TimeInterval = 3.0
        static let connectionTimeout: TimeInterval = 10.0
        static let signalingTimeout: TimeInterval = 30.0
        
        // Video encoding parameters
        enum VideoEncoding {
            static let maxBitrate = 2_000_000 // 2 Mbps
            static let minBitrate = 300_000   // 300 Kbps
            static let startBitrate = 1_000_000 // 1 Mbps
            static let maxFramerate = 30
            static let keyFrameInterval = 30 // seconds
        }
        
        // Quality presets for WebRTC
        enum QualityPresets {
            static let lowBitrate = 500_000    // 500 Kbps
            static let mediumBitrate = 1_000_000 // 1 Mbps
            static let highBitrate = 2_000_000   // 2 Mbps
        }
    }
    
    enum FeatureFlags {
        static let enablePictureInPicture = true
        static let enableDebugLogging = true
        static let useLocalVideoOnly = false
        static let enableWebRTC = true
        static let enableLegacyHTTP = false // For fallback compatibility
        static let enableWebRTCStats = true
        static let enableAutoReconnect = true
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
    
    // Legacy compression settings (for local recording)
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
    
    // WebRTC-specific settings
    var webRTCBitrate: Int {
        switch self {
        case .low: return Constants.WebRTC.QualityPresets.lowBitrate
        case .medium: return Constants.WebRTC.QualityPresets.mediumBitrate
        case .high: return Constants.WebRTC.QualityPresets.highBitrate
        }
    }
    
    var webRTCFramerate: Int {
        switch self {
        case .low: return 15
        case .medium: return 24
        case .high: return 30
        }
    }
    
    var webRTCResolutionScale: CGFloat {
        switch self {
        case .low: return 0.5    // Half resolution
        case .medium: return 0.75 // 3/4 resolution
        case .high: return 1.0    // Full resolution
        }
    }
}
