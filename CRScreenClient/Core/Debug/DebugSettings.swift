// CRScreenClient/Core/Debug/DebugSettings.swift
import Foundation
import Combine

/// Debug settings model that stores and persists app debug configurations
class DebugSettings: ObservableObject {
    // MARK: - Published Properties
    
    /// Custom server URL for broadcasting and WebRTC signaling
    @Published var customServerURL: String {
        didSet {
            saveSettings()
        }
    }
    
    /// Whether to use the custom server URL instead of the default
    @Published var useCustomServer: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Whether to show the video preview during broadcasting
    @Published var disableVideoPreview: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Whether to disable local recording during broadcast
    @Published var disableLocalRecording: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Whether debug mode is enabled
    @Published var debugModeEnabled: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Server connection protocol preference
    @Published var preferSecureConnection: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Custom port number for server connection
    @Published var customPort: String {
        didSet {
            saveSettings()
        }
    }
    
    // MARK: - Computed Properties
    
    /// The effective server URL to use for broadcasting
    var effectiveServerURL: String {
        if useCustomServer && !customServerURL.isEmpty {
            return formatServerURL(customServerURL)
        }
        return "Default Server (34.56.170.86:8080)"
    }
    
    /// The effective WebRTC signaling URL
    var effectiveWebRTCURL: String {
        if useCustomServer && !customServerURL.isEmpty {
            let formattedURL = formatServerURL(customServerURL)
            if formattedURL.hasPrefix("http") {
                return formattedURL.replacingOccurrences(of: "http", with: "ws")
            }
            return formattedURL
        }
        return "Default WebRTC Server (ws://34.56.170.86:8080/ws)"
    }
    
    // MARK: - Initialization
    
    init() {
        // Load saved values or use defaults
        self.customServerURL = UserDefaults.standard.string(forKey: Keys.customServerURL) ?? ""
        self.useCustomServer = UserDefaults.standard.bool(forKey: Keys.useCustomServer)
        self.disableVideoPreview = UserDefaults.standard.bool(forKey: Keys.disableVideoPreview)
        self.disableLocalRecording = UserDefaults.standard.bool(forKey: Keys.disableLocalRecording)
        self.debugModeEnabled = UserDefaults.standard.bool(forKey: Keys.debugModeEnabled)
        self.preferSecureConnection = UserDefaults.standard.bool(forKey: Keys.preferSecureConnection)
        self.customPort = UserDefaults.standard.string(forKey: Keys.customPort) ?? "8080"
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        UserDefaults.standard.set(customServerURL, forKey: Keys.customServerURL)
        UserDefaults.standard.set(useCustomServer, forKey: Keys.useCustomServer)
        UserDefaults.standard.set(disableVideoPreview, forKey: Keys.disableVideoPreview)
        UserDefaults.standard.set(disableLocalRecording, forKey: Keys.disableLocalRecording)
        UserDefaults.standard.set(debugModeEnabled, forKey: Keys.debugModeEnabled)
        UserDefaults.standard.set(preferSecureConnection, forKey: Keys.preferSecureConnection)
        UserDefaults.standard.set(customPort, forKey: Keys.customPort)
        
        // Also save critical settings to app group for broadcast extension access
        let groupDefaults = UserDefaults(suiteName: Constants.Broadcast.groupID)
        groupDefaults?.set(useCustomServer, forKey: Keys.useCustomServer)
        groupDefaults?.set(customServerURL, forKey: Keys.customServerURL)
        groupDefaults?.set(disableLocalRecording, forKey: Keys.disableLocalRecording)
        groupDefaults?.set(preferSecureConnection, forKey: Keys.preferSecureConnection)
        groupDefaults?.set(customPort, forKey: Keys.customPort)
        
        // For debugging
        if Constants.FeatureFlags.enableDebugLogging {
            print("Debug settings saved: useCustomServer=\(useCustomServer), customURL=\(effectiveServerURL)")
            print("WebRTC URL: \(effectiveWebRTCURL)")
        }
    }
    
    private func formatServerURL(_ url: String) -> String {
        var formattedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle port addition if specified
        if !customPort.isEmpty && customPort != "8080" && !formattedURL.contains(":") {
            // Add port only if it's not already in the URL
            if formattedURL.contains("localhost") || formattedURL.contains("127.0.0.1") || formattedURL.contains("192.168.") {
                formattedURL += ":\(customPort)"
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
    }
    
    // MARK: - Helper Methods
    
    func resetToDefaults() {
        customServerURL = ""
        useCustomServer = false
        disableVideoPreview = false
        disableLocalRecording = false
        preferSecureConnection = false
        customPort = "8080"
        // Leave debug mode enabled since they're in the debug menu
    }
    
    /// Validates the current server URL format
    func validateServerURL() -> (isValid: Bool, message: String) {
        guard useCustomServer && !customServerURL.isEmpty else {
            return (true, "Using default server")
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
        if (trimmedURL.hasPrefix("http") && preferSecureConnection) {
            return (false, "HTTP URL with secure connection preference - consider using HTTPS")
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
            "isValidURL": validateServerURL().isValid
        ]
    }
}
