import Foundation
import SwiftUI

@available(iOS 14.0, *)
class DebugSettings: ObservableObject {
    
    // MARK: - Properties
    private let defaults = UserDefaults(suiteName: AppGroup.identifier)
    
    @Published var customServerURL: String {
        didSet {
            defaults?.set(customServerURL, forKey: Keys.customServerURL)
        }
    }
    
    @Published var useCustomServer: Bool {
        didSet {
            defaults?.set(useCustomServer, forKey: Keys.useCustomServer)
        }
    }
    
    @Published var disableVideoPreview: Bool {
        didSet {
            defaults?.set(disableVideoPreview, forKey: Keys.disableVideoPreview)
        }
    }
    
    @Published var disableLocalRecording: Bool {
        didSet {
            defaults?.set(disableLocalRecording, forKey: Keys.disableLocalRecording)
        }
    }
    
    @Published var debugModeEnabled: Bool {
        didSet {
            defaults?.set(debugModeEnabled, forKey: Keys.debugModeEnabled)
        }
    }
    
    // Updated to default to secure connections for api.tormentor.dev
    @Published var preferSecureConnection: Bool {
        didSet {
            defaults?.set(preferSecureConnection, forKey: Keys.preferSecureConnection)
        }
    }
    
    // Updated default port for HTTPS/WSS
    @Published var customPort: String {
        didSet {
            defaults?.set(customPort, forKey: Keys.customPort)
        }
    }
    
    @Published var showWatermark: Bool {
        didSet {
            defaults?.set(showWatermark, forKey: Keys.showWatermark)
        }
    }
    
    // MARK: - Computed Properties
    
    var effectiveServerURL: String {
        if useCustomServer && !customServerURL.isEmpty {
            return formatServerURL(customServerURL)
        }
        // Return the new secure default
        return "https://api.tormentor.dev:443"
    }
    
    var effectiveWebRTCURL: String {
        if useCustomServer && !customServerURL.isEmpty {
            let baseURL = formatServerURL(customServerURL)
            let protocol_url = preferSecureConnection ? "wss://" : "ws://"
            
            // Remove http/https prefix and add ws/wss
            var cleanURL = baseURL
            if cleanURL.hasPrefix("https://") {
                cleanURL = String(cleanURL.dropFirst(8))
            } else if cleanURL.hasPrefix("http://") {
                cleanURL = String(cleanURL.dropFirst(7))
            }
            
            return "\(protocol_url)\(cleanURL)/ws"
        }
        // Return the new secure default WebSocket URL
        return "wss://api.tormentor.dev:443/ws"
    }
    
    // MARK: - Initialization
    
    init() {
        // Load with secure defaults for api.tormentor.dev
        customServerURL = defaults?.string(forKey: Keys.customServerURL) ?? ""
        useCustomServer = defaults?.bool(forKey: Keys.useCustomServer) ?? false
        disableVideoPreview = defaults?.bool(forKey: Keys.disableVideoPreview) ?? false
        disableLocalRecording = defaults?.bool(forKey: Keys.disableLocalRecording) ?? false
        debugModeEnabled = defaults?.bool(forKey: Keys.debugModeEnabled) ?? false
        // Default to secure connections for your secure server
        preferSecureConnection = defaults?.bool(forKey: Keys.preferSecureConnection) ?? true
        // Default to HTTPS/WSS port
        customPort = defaults?.string(forKey: Keys.customPort) ?? "443"
        showWatermark = defaults?.bool(forKey: Keys.showWatermark) ?? true
        
        // Log the initial configuration
        if Constants.FeatureFlags.enableDebugLogging {
            print("🔧 DebugSettings initialized:")
            print("  🔒 Secure by default: \(preferSecureConnection)")
            print("  🌐 Effective URL: \(effectiveServerURL)")
            print("  📡 WebSocket URL: \(effectiveWebRTCURL)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatServerURL(_ url: String) -> String {
        var formattedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing slash
        if formattedURL.hasSuffix("/") {
            formattedURL = String(formattedURL.dropLast())
        }
        
        // Add protocol if missing - default to secure
        if !formattedURL.hasPrefix("http://") && !formattedURL.hasPrefix("https://") {
            formattedURL = preferSecureConnection ? "https://\(formattedURL)" : "http://\(formattedURL)"
        }
        
        // Add port if specified and not already present
        if !customPort.isEmpty && customPort != "80" && customPort != "443" {
            // Check if port is already in URL
            let urlComponents = formattedURL.components(separatedBy: ":")
            if urlComponents.count == 2 { // Only protocol, no port
                formattedURL += ":\(customPort)"
            } else if urlComponents.count == 3 {
                // Replace existing port
                let protocolAndHost = "\(urlComponents[0]):\(urlComponents[1])"
                formattedURL = "\(protocolAndHost):\(customPort)"
            }
        } else if customPort == "443" && formattedURL.hasPrefix("https://") {
            // Standard HTTPS port - no need to specify
            // Keep as is
        } else if customPort == "80" && formattedURL.hasPrefix("http://") {
            // Standard HTTP port - no need to specify
            // Keep as is
        } else if !customPort.isEmpty && !formattedURL.contains(":") {
            // Add port if specified
            if let range = formattedURL.range(of: "://") {
                let afterProtocol = formattedURL[range.upperBound...]
                if !afterProtocol.contains(":") {
                    formattedURL += ":\(customPort)"
                }
            }
        }
        
        return formattedURL
    }
    
    // MARK: - Key Constants
    
    private enum Keys {
        static let customServerURL = "debug_customServerURL"
        static let useCustomServer = "debug_useCustomServer"
        static let disableVideoPreview = "debug_disableVideoPreview"
        static let disableLocalRecording = "debug_disableLocalRecording"
        static let debugModeEnabled = "debug_debugModeEnabled"
        static let preferSecureConnection = "debug_preferSecureConnection"
        static let customPort = "debug_customPort"
        static let showWatermark = "debug_showWatermark"
    }
    
    // MARK: - Helper Methods
    
    func resetToDefaults() {
        customServerURL = ""
        useCustomServer = false
        disableVideoPreview = false
        disableLocalRecording = false
        // Default to secure connections for api.tormentor.dev
        preferSecureConnection = true
        // Default to HTTPS/WSS port
        customPort = "443"
        // IMPORTANT: Keep watermark ON even after reset for security
        showWatermark = true
        // Leave debug mode enabled since they're in the debug menu
        
        print("🔄 Debug settings reset to secure defaults")
        print("  🔒 Secure connection: \(preferSecureConnection)")
        print("  🔌 Default port: \(customPort)")
    }
    
    /// Validates the current server URL format
    func validateServerURL() -> (isValid: Bool, message: String) {
        guard useCustomServer && !customServerURL.isEmpty else {
            return (true, "Using secure default server (api.tormentor.dev:443)")
        }
        
        let trimmedURL = customServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic format validation
        if trimmedURL.isEmpty {
            return (false, "Server URL cannot be empty")
        }
        
        // Check for basic URL format
        if !trimmedURL.contains(".") && !trimmedURL.contains("localhost") && !trimmedURL.contains("127.0.0.1") {
            return (false, "URL should contain a domain or IP address")
        }
        
        // Check for protocol conflicts
        if (trimmedURL.hasPrefix("http://") && preferSecureConnection) {
            return (false, "HTTP URL with secure connection preference - consider using HTTPS")
        }
        
        // Validate port
        if !customPort.isEmpty {
            if let port = Int(customPort) {
                if port < 1 || port > 65535 {
                    return (false, "Port must be between 1 and 65535")
                }
                // Warn about common secure ports
                if preferSecureConnection && port != 443 && port != 8443 {
                    return (true, "Non-standard port for secure connection")
                }
            } else {
                return (false, "Invalid port number")
            }
        }
        
        return (true, "Server URL format appears valid")
    }
    
    /// Gets the complete server configuration for logging
    func getServerConfiguration() -> [String: Any] {
        return [
            "useCustomServer": useCustomServer,
            "customServerURL": customServerURL,
            "effectiveServerURL": effectiveServerURL,
            "effectiveWebRTCURL": effectiveWebRTCURL,
            "preferSecureConnection": preferSecureConnection,
            "customPort": customPort,
            "showWatermark": showWatermark,
            "isValidURL": validateServerURL().isValid,
            "isSecureDefault": !useCustomServer && preferSecureConnection
        ]
    }
    
    /// Quick setup for api.tormentor.dev
    func setupForSecureServer() {
        useCustomServer = false
        preferSecureConnection = true
        customPort = "443"
        
        print("🔧 Configured for secure api.tormentor.dev server")
        print("  🌐 URL: \(effectiveServerURL)")
        print("  📡 WebSocket: \(effectiveWebRTCURL)")
    }
    
    /// Check if current configuration is using the secure default
    var isUsingSecureDefault: Bool {
        return !useCustomServer && preferSecureConnection
    }
}

// MARK: - AppGroup Helper
extension DebugSettings {
    enum AppGroup {
        static let identifier = "group.coreradiant.crscreenclient"
    }
}
