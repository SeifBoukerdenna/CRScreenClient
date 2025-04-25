import SwiftUI
import AVKit

/// Manages Picture-in-Picture functionality
final class PiPManager: ObservableObject {
    @Published private(set) var isPiPActive = false
    @Published private(set) var isPiPPossible = false
    
    private var pipController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?
    private var pipObserver: NSKeyValueObservation?
    private var pipPossibleObserver: NSKeyValueObservation?
    
    /// Initialize PiP manager with a video player layer
    func setup(with playerLayer: AVPlayerLayer) {
        // Check if feature is enabled
        guard Constants.FeatureFlags.enablePictureInPicture else {
            if Constants.FeatureFlags.enableDebugLogging {
                print("PiP setup skipped - feature is disabled")
            }
            return
        }
        
        self.playerLayer = playerLayer
        
        // Check if PiP is supported on this device
        if AVPictureInPictureController.isPictureInPictureSupported() {
            // Configure audio session for background playback
            configureAudioSession()
            
            // Create PiP controller with proper configuration
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            
            // Force update the PiP possible state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isPiPPossible = self?.pipController?.isPictureInPicturePossible ?? false
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("PiP possible: \(self?.isPiPPossible ?? false)")
                }
            }
            
            // Observe PiP state changes
            pipObserver = pipController?.observe(\.isPictureInPictureActive, options: [.new, .initial]) { [weak self] _, change in
                guard let isActive = change.newValue else { return }
                DispatchQueue.main.async {
                    self?.isPiPActive = isActive
                    
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("PiP active state changed: \(isActive)")
                    }
                }
            }
            
            // Observe if PiP is possible
            pipPossibleObserver = pipController?.observe(\.isPictureInPicturePossible, options: [.new, .initial]) { [weak self] _, change in
                guard let isPossible = change.newValue else { return }
                DispatchQueue.main.async {
                    self?.isPiPPossible = isPossible
                }
            }
        } else {
            if Constants.FeatureFlags.enableDebugLogging {
                print("PiP is not supported on this device")
            }
        }
    }
    
    private func configureAudioSession() {
        // Configure this once and handle errors properly
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            if Constants.FeatureFlags.enableDebugLogging {
                print("Failed to set audio session category: \(error)")
            }
        }
    }
    
    /// Start Picture-in-Picture if possible
    func startPiP() {
        // Check if feature is enabled
        guard Constants.FeatureFlags.enablePictureInPicture else {
            return
        }
        
        guard let pipController = pipController, pipController.isPictureInPicturePossible else {
            if Constants.FeatureFlags.enableDebugLogging {
                print("PiP not possible at this moment")
            }
            return
        }
        
        pipController.startPictureInPicture()
    }
    
    /// Stop Picture-in-Picture if active
    func stopPiP() {
        // Check if feature is enabled
        guard Constants.FeatureFlags.enablePictureInPicture else {
            return
        }
        
        guard let pipController = pipController, pipController.isPictureInPictureActive else {
            return
        }
        
        pipController.stopPictureInPicture()
    }
    
    /// Toggle Picture-in-Picture state
    func togglePiP() {
        // Check if feature is enabled
        guard Constants.FeatureFlags.enablePictureInPicture else {
            return
        }
        
        if isPiPActive {
            stopPiP()
        } else {
            startPiP()
        }
    }
    
    deinit {
        pipObserver?.invalidate()
        pipPossibleObserver?.invalidate()
    }
}
