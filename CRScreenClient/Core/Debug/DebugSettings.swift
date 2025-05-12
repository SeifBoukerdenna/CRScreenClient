// CRScreenClient/Core/Debug/DebugSettings.swift
// Add to App/AppEnvironment.swift directly instead of using an extension
import Foundation
import Combine

/// Debug settings model that stores and persists app debug configurations
class DebugSettings: ObservableObject {
    // MARK: - Published Properties
    
    /// Custom server URL for broadcasting
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
    
    // MARK: - Computed Properties
    
    /// The effective server URL to use for broadcasting
    var effectiveServerURL: String {
        if useCustomServer && !customServerURL.isEmpty {
            // Ensure URL ends with a slash
            var url = customServerURL
            if !url.hasSuffix("/") {
                url += "/"
            }
            return url
        }
        return Constants.URLs.broadcastServer
    }
    
    // MARK: - Initialization
    
    init() {
        // Load saved values or use defaults
        self.customServerURL = UserDefaults.standard.string(forKey: Keys.customServerURL) ?? ""
        self.useCustomServer = UserDefaults.standard.bool(forKey: Keys.useCustomServer)
        self.disableVideoPreview = UserDefaults.standard.bool(forKey: Keys.disableVideoPreview)
        self.disableLocalRecording = UserDefaults.standard.bool(forKey: Keys.disableLocalRecording)
        self.debugModeEnabled = UserDefaults.standard.bool(forKey: Keys.debugModeEnabled)
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        UserDefaults.standard.set(customServerURL, forKey: Keys.customServerURL)
        UserDefaults.standard.set(useCustomServer, forKey: Keys.useCustomServer)
        UserDefaults.standard.set(disableVideoPreview, forKey: Keys.disableVideoPreview)
        UserDefaults.standard.set(disableLocalRecording, forKey: Keys.disableLocalRecording)
        UserDefaults.standard.set(debugModeEnabled, forKey: Keys.debugModeEnabled)
        
        // Also save disableLocalRecording to app group for broadcast extension to access
        UserDefaults(suiteName: Constants.Broadcast.groupID)?.set(
            disableLocalRecording,
            forKey: Keys.disableLocalRecording
        )
        
        // For debugging
        if Constants.FeatureFlags.enableDebugLogging {
            print("Debug settings saved: useCustomServer=\(useCustomServer), customURL=\(customServerURL)")
            print("Debug settings saved: disableVideoPreview=\(disableVideoPreview), disableLocalRecording=\(disableLocalRecording)")
        }
    }
    
    // MARK: - Key Constants
    
    private enum Keys {
        static let customServerURL = "debug_customServerURL"
        static let useCustomServer = "debug_useCustomServer"
        static let disableVideoPreview = "debug_disableVideoPreview"
        static let disableLocalRecording = "debug_disableLocalRecording"
        static let debugModeEnabled = "debug_debugModeEnabled"
    }
    
    // Helper to reset all settings to defaults
    func resetToDefaults() {
        customServerURL = ""
        useCustomServer = false
        disableVideoPreview = false
        disableLocalRecording = false
        // Leave debug mode enabled since they're in the debug menu
    }
}
