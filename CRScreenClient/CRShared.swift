import Foundation
import SwiftUI

enum Constants {
    enum URLs {
        static let demoVideo = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        
        // Updated default server URLs to use your secure api.tormentor.dev server
        private static let defaultWebRTCSignalingServer = "wss://api.tormentor.dev:443/ws"
        private static let defaultWebRTCSignalingServerSecure = "wss://api.tormentor.dev:443/ws"
        private static let defaultBroadcastServer = "https://api.tormentor.dev:443/upload/"
        
        // Fallback URLs (for backward compatibility or fallback scenarios)
        private static let fallbackWebRTCSignalingServer = "ws://35.208.133.112:8080/ws"
        private static let fallbackWebRTCSignalingServerSecure = "wss://35.208.133.112:8080/ws"
        private static let fallbackBroadcastServer = "http://35.208.133.112:8080/upload/"
        
        // Dynamic server URL getters that check debug settings
        static var webRTCSignalingServer: String {
            let defaults = UserDefaults(suiteName: AppGroup.identifier)
            let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
            let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
            
            if useCustomServer && !customServerURL.isEmpty {
                var baseURL = customServerURL
                if !baseURL.hasPrefix("ws://") && !baseURL.hasPrefix("wss://") {
                    // Default to secure connection for custom servers
                    baseURL = "wss://" + baseURL
                }
                if baseURL.hasSuffix("/") {
                    baseURL = String(baseURL.dropLast())
                }
                return "\(baseURL)/ws"
            }
            
            // Use secure connection by default
            return defaultWebRTCSignalingServerSecure
        }
        
        static var webRTCSignalingServerSecure: String {
            let defaults = UserDefaults(suiteName: AppGroup.identifier)
            let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
            let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
            
            if useCustomServer && !customServerURL.isEmpty {
                var baseURL = customServerURL
                if !baseURL.hasPrefix("wss://") && !baseURL.hasPrefix("ws://") {
                    baseURL = "wss://" + baseURL
                }
                if baseURL.hasSuffix("/") {
                    baseURL = String(baseURL.dropLast())
                }
                return "\(baseURL)/ws"
            }
            return defaultWebRTCSignalingServerSecure
        }
        
        static var broadcastServer: String {
            let defaults = UserDefaults(suiteName: AppGroup.identifier)
            let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
            let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
            
            if useCustomServer && !customServerURL.isEmpty {
                var baseURL = customServerURL
                
                // Remove WebSocket protocols if present
                if baseURL.hasPrefix("ws://") {
                    baseURL = "http://" + String(baseURL.dropFirst(5))
                } else if baseURL.hasPrefix("wss://") {
                    baseURL = "https://" + String(baseURL.dropFirst(6))
                }
                
                // Add HTTPS if no protocol specified (secure by default)
                if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                    baseURL = "https://" + baseURL
                }
                
                if baseURL.hasSuffix("/") {
                    baseURL = String(baseURL.dropLast())
                }
                return "\(baseURL)/upload/"
            }
            return defaultBroadcastServer
        }
        
        // Health check endpoint
        static var healthCheckServer: String {
            let defaults = UserDefaults(suiteName: AppGroup.identifier)
            let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
            let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
            
            if useCustomServer && !customServerURL.isEmpty {
                var baseURL = customServerURL
                
                // Remove WebSocket protocols if present
                if baseURL.hasPrefix("ws://") {
                    baseURL = "http://" + String(baseURL.dropFirst(5))
                } else if baseURL.hasPrefix("wss://") {
                    baseURL = "https://" + String(baseURL.dropFirst(6))
                }
                
                // Add HTTPS if no protocol specified (secure by default)
                if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                    baseURL = "https://" + baseURL
                }
                
                if baseURL.hasSuffix("/") {
                    baseURL = String(baseURL.dropLast())
                }
                return "\(baseURL)/health"
            }
            return "https://api.tormentor.dev:443/health"
        }
        
        // API endpoints
        static var apiBaseURL: String {
            let defaults = UserDefaults(suiteName: AppGroup.identifier)
            let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
            let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
            
            if useCustomServer && !customServerURL.isEmpty {
                var baseURL = customServerURL
                
                // Remove WebSocket protocols if present
                if baseURL.hasPrefix("ws://") {
                    baseURL = "http://" + String(baseURL.dropFirst(5))
                } else if baseURL.hasPrefix("wss://") {
                    baseURL = "https://" + String(baseURL.dropFirst(6))
                }
                
                // Add HTTPS if no protocol specified (secure by default)
                if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                    baseURL = "https://" + baseURL
                }
                
                if baseURL.hasSuffix("/") {
                    baseURL = String(baseURL.dropLast())
                }
                return baseURL
            }
            return "https://api.tormentor.dev:443"
        }
        
        // Utility method to get WebRTC signaling URL for a specific session
        static func webRTCSignalingURL(for sessionCode: String) -> URL {
            let baseURL = webRTCSignalingServerSecure // Use secure by default
            return URL(string: "\(baseURL)/\(sessionCode)")!
        }
        
        // STUN/TURN servers for WebRTC (these remain static)
        static let stunServers = [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ]
        
        static let webApp = "royaltrainer.com"
        
        /// Get the appropriate WebSocket URL based on security preference
        static func getWebSocketURL(preferSecure: Bool = true) -> String {
            return preferSecure ? webRTCSignalingServerSecure : webRTCSignalingServer
        }
        
        /// Get the appropriate HTTP URL based on security preference
        static func getHTTPURL(preferSecure: Bool = true) -> String {
            let base = apiBaseURL
            return preferSecure ? base.replacingOccurrences(of: "http://", with: "https://") : base
        }
        
        /// Validate if the server URL is using secure protocols
        static func isSecureConnection() -> Bool {
            let wsURL = webRTCSignalingServerSecure
            let httpURL = apiBaseURL
            return wsURL.hasPrefix("wss://") && httpURL.hasPrefix("https://")
        }
    }
    
    enum AppGroup {
        static let identifier = "group.com.elmelz.crcoach"
    }
        
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonBorderWidth: CGFloat = 3
        static let animationDuration: Double = 0.3
        static let defaultPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let iconSize: CGFloat = 20
        static let buttonHeight: CGFloat = 44
        static let cardElevation: CGFloat = 4
    }
    
    enum Broadcast {
        static let extensionID = "com.elmelz.CRScreenClient.Broadcast"
        static let groupID = "group.com.elmelz.crcoach"
        static let recordingKey = "lastRecordingPath"
    }
    
    enum WebRTC {
        // Conservative WebRTC configuration constants
        static let maxReconnectAttempts = 3
        static let reconnectDelay: TimeInterval = 5.0
        static let connectionTimeout: TimeInterval = 8.0
        static let signalingTimeout: TimeInterval = 20.0
        
        // Conservative video encoding parameters
        enum VideoEncoding {
            static let maxBitrate = 1_200_000
            static let minBitrate = 300_000
            static let startBitrate = 600_000
            static let maxFramerate = 24
            static let keyFrameInterval = 60
        }
        
        // Conservative quality presets for WebRTC
        enum QualityPresets {
            static let lowBitrate = 400_000
            static let mediumBitrate = 800_000
            static let highBitrate = 1_200_000
        }
        
        // System performance thresholds
        enum PerformanceThresholds {
            static let highCPUThreshold = 70.0
            static let lowCPUThreshold = 40.0
            static let highMemoryThreshold = 0.8
            static let lowMemoryThreshold = 0.5
            static let maxDynamicFrameSkip = 5
            static let minFrameInterval: TimeInterval = 0.033
        }
    }
    
    enum FeatureFlags {
        static let enablePictureInPicture = true
        static let enableDebugLogging = true
        static let useLocalVideoOnly = false
        static let enableWebRTC = true
        static let enableLegacyHTTP = false
        static let enableWebRTCStats = true
        static let enableAutoReconnect = true
        static let useConservativeDefaults = true
        static let enableAdaptiveQuality = true
        // Enable secure connections by default
        static let preferSecureConnections = true
        // Enable frame acknowledgment for better reliability
        static let enableFrameAcknowledgment = true
    }
    
    enum Network {
        // Updated timeouts for secure connections
        static let connectionTimeout: TimeInterval = 15.0
        static let requestTimeout: TimeInterval = 10.0
        static let webSocketPingInterval: TimeInterval = 30.0
        static let maxReconnectAttempts = 8
        static let baseReconnectDelay: TimeInterval = 3.0
        static let maxReconnectDelay: TimeInterval = 30.0
    }
    
    enum Performance {
        static let maxFrameRate: Double = 30.0
        static let defaultImageQuality: Double = 0.7
        static let maxImageQuality: Double = 0.9
        static let minImageQuality: Double = 0.3
        // Adjusted for secure server performance
        static let targetLatencyMs: Double = 150.0
        static let maxAcceptableLatencyMs: Double = 500.0
    }
    
    enum Security {
        // Enhanced security settings for your secure server
        static let requireSecureConnection = true
        static let validateSSLCertificates = true
        static let allowSelfSignedCertificates = false
        static let minimumTLSVersion = "1.2"
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
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.7
        }
    }
    
    var frameSkip: Int {
        switch self {
        case .low: return 3
        case .medium: return 2
        case .high: return 1
        }
    }
    
    var downsizeFactor: CGFloat {
        switch self {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.85
        }
    }
    
    var webRTCBitrate: Int {
        switch self {
        case .low: return Constants.WebRTC.QualityPresets.lowBitrate
        case .medium: return Constants.WebRTC.QualityPresets.mediumBitrate
        case .high: return Constants.WebRTC.QualityPresets.highBitrate
        }
    }
    
    var webRTCFramerate: Int {
        switch self {
        case .low: return 12
        case .medium: return 20
        case .high: return 24
        }
    }
    
    var webRTCResolutionScale: CGFloat {
        switch self {
        case .low: return 0.4
        case .medium: return 0.65
        case .high: return 0.85
        }
    }
    
    var resolutionThreshold: Int {
        switch self {
        case .low: return 720
        case .medium: return 1080
        case .high: return 1280
        }
    }
    
    func adaptedSettings(cpuUsage: Double, memoryPressure: Double) -> (frameSkip: Int, bitrate: Int, resolutionScale: CGFloat) {
        var adaptedFrameSkip = self.frameSkip
        var adaptedBitrate = self.webRTCBitrate
        var adaptedResolutionScale = self.webRTCResolutionScale
        
        if cpuUsage > Constants.WebRTC.PerformanceThresholds.highCPUThreshold ||
           memoryPressure > Constants.WebRTC.PerformanceThresholds.highMemoryThreshold {
            adaptedFrameSkip = min(adaptedFrameSkip + 2, Constants.WebRTC.PerformanceThresholds.maxDynamicFrameSkip)
            adaptedBitrate = Int(Double(adaptedBitrate) * 0.7)
            adaptedResolutionScale *= 0.8
        }
        else if cpuUsage < Constants.WebRTC.PerformanceThresholds.lowCPUThreshold &&
                memoryPressure < Constants.WebRTC.PerformanceThresholds.lowMemoryThreshold {
            adaptedFrameSkip = max(adaptedFrameSkip - 1, 1)
            adaptedBitrate = min(Int(Double(adaptedBitrate) * 1.1), self.webRTCBitrate)
            adaptedResolutionScale = min(adaptedResolutionScale * 1.05, self.webRTCResolutionScale)
        }
        
        return (frameSkip: adaptedFrameSkip, bitrate: adaptedBitrate, resolutionScale: adaptedResolutionScale)
    }
}

// MARK: - Debug Helper
extension Constants {
    static func logConfiguration() {
        if FeatureFlags.enableDebugLogging {
            print("🔧 CRScreenClient Configuration:")
            print("  📡 WebSocket: \(URLs.webRTCSignalingServerSecure)")
            print("  🌐 HTTP API: \(URLs.apiBaseURL)")
            print("  💾 Broadcast: \(URLs.broadcastServer)")
            print("  ❤️ Health: \(URLs.healthCheckServer)")
            print("  🔒 Secure: \(URLs.isSecureConnection())")
            print("  🎯 Target Latency: \(Performance.targetLatencyMs)ms")
            print("  🔄 Max Reconnects: \(Network.maxReconnectAttempts)")
        }
    }
}
