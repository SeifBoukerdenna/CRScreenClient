import Foundation
import SwiftUI

enum Constants {
    enum URLs {
        static let demoVideo = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        
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
        // Conservative WebRTC configuration constants
        static let maxReconnectAttempts = 3 // Reduced from 5
        static let reconnectDelay: TimeInterval = 5.0 // Increased from 3.0
        static let connectionTimeout: TimeInterval = 8.0 // Reduced from 10.0
        static let signalingTimeout: TimeInterval = 20.0 // Reduced from 30.0
        
        // Conservative video encoding parameters
        enum VideoEncoding {
            static let maxBitrate = 1_200_000 // Reduced from 2 Mbps
            static let minBitrate = 300_000   // 300 Kbps
            static let startBitrate = 600_000 // Reduced from 1 Mbps
            static let maxFramerate = 24     // Reduced from 30
            static let keyFrameInterval = 60 // Increased from 30 seconds
        }
        
        // Conservative quality presets for WebRTC
        enum QualityPresets {
            static let lowBitrate = 400_000    // Reduced from 500 Kbps
            static let mediumBitrate = 800_000 // Reduced from 1 Mbps
            static let highBitrate = 1_200_000 // Reduced from 2 Mbps
        }
        
        // System performance thresholds
        enum PerformanceThresholds {
            static let highCPUThreshold = 70.0
            static let lowCPUThreshold = 40.0
            static let highMemoryThreshold = 0.8
            static let lowMemoryThreshold = 0.5
            static let maxDynamicFrameSkip = 5
            static let minFrameInterval: TimeInterval = 0.033 // ~30 FPS max
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
        static let useConservativeDefaults = true // New flag for stability
        static let enableAdaptiveQuality = true  // New flag for dynamic adjustments
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
    
    // Conservative compression settings (for local recording)
    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.25  // Reduced from 0.3
        case .medium: return 0.5 // Reduced from 0.6
        case .high: return 0.7   // Reduced from 0.85
        }
    }
    
    var frameSkip: Int {
        switch self {
        case .low: return 3      // Increased from 2
        case .medium: return 2   // Increased from 1
        case .high: return 1     // Increased from 0
        }
    }
    
    var downsizeFactor: CGFloat {
        switch self {
        case .low: return 0.5    // Reduced from 0.6
        case .medium: return 0.7 // Reduced from 0.8
        case .high: return 0.85  // Reduced from 1.0
        }
    }
    
    // Conservative WebRTC-specific settings
    var webRTCBitrate: Int {
        switch self {
        case .low: return Constants.WebRTC.QualityPresets.lowBitrate
        case .medium: return Constants.WebRTC.QualityPresets.mediumBitrate
        case .high: return Constants.WebRTC.QualityPresets.highBitrate
        }
    }
    
    var webRTCFramerate: Int {
        switch self {
        case .low: return 12     // Reduced from 15
        case .medium: return 20  // Reduced from 24
        case .high: return 24    // Reduced from 30
        }
    }
    
    var webRTCResolutionScale: CGFloat {
        switch self {
        case .low: return 0.4    // Reduced from 0.5
        case .medium: return 0.65 // Reduced from 0.75
        case .high: return 0.85   // Reduced from 1.0
        }
    }
    
    // Threshold for resolution downscaling
    var resolutionThreshold: Int {
        switch self {
        case .low: return 720    // Reduced from 960
        case .medium: return 1080 // Reduced from 1280
        case .high: return 1280   // Reduced from 1600
        }
    }
    
    // Adaptive quality adjustments based on system performance
    func adaptedSettings(cpuUsage: Double, memoryPressure: Double) -> (frameSkip: Int, bitrate: Int, resolutionScale: CGFloat) {
        var adaptedFrameSkip = self.frameSkip
        var adaptedBitrate = self.webRTCBitrate
        var adaptedResolutionScale = self.webRTCResolutionScale
        
        // Increase frame skip under high system load
        if cpuUsage > Constants.WebRTC.PerformanceThresholds.highCPUThreshold ||
           memoryPressure > Constants.WebRTC.PerformanceThresholds.highMemoryThreshold {
            adaptedFrameSkip = min(adaptedFrameSkip + 2, Constants.WebRTC.PerformanceThresholds.maxDynamicFrameSkip)
            adaptedBitrate = Int(Double(adaptedBitrate) * 0.7)
            adaptedResolutionScale *= 0.8
        }
        // Reduce frame skip under low system load
        else if cpuUsage < Constants.WebRTC.PerformanceThresholds.lowCPUThreshold &&
                memoryPressure < Constants.WebRTC.PerformanceThresholds.lowMemoryThreshold {
            adaptedFrameSkip = max(adaptedFrameSkip - 1, 1)
            adaptedBitrate = min(Int(Double(adaptedBitrate) * 1.1), self.webRTCBitrate)
            adaptedResolutionScale = min(adaptedResolutionScale * 1.05, self.webRTCResolutionScale)
        }
        
        return (frameSkip: adaptedFrameSkip, bitrate: adaptedBitrate, resolutionScale: adaptedResolutionScale)
    }
}
