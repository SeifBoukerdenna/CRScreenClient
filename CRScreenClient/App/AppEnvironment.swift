import SwiftUI
import Combine
import AVFAudio  // Added explicit import for AVAudioSession

/// Global app state and environment values
class AppEnvironment: ObservableObject {
    @Published var appTheme: AppTheme = .standard
    @Published var debugMode: Bool = false
    
    // Debug settings
    @Published var debugSettings = DebugSettings()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // App initialization logic
        setupAudioSession()
        
        #if DEBUG
        // Additional debug setup
        debugMode = true
        #endif
    }
    
    private func setupAudioSession() {
        // Configure global audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.error("Failed to set audio session: \(error)", to: Logger.app)
        }
    }
    
    enum AppTheme {
        case standard
        case dark
        case light
    }
}
