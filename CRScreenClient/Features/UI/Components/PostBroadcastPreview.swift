// CRScreenClient/Features/UI/Components/PostBroadcastPreview.swift

import SwiftUI
import AVKit

struct PostBroadcastPreview: View {
    let recordingURL: URL
    let onDiscard: () -> Void
    let onSend: () -> Void
    
    @State private var player: AVPlayer
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlayerReady = false
    
    // Timer for updating current position
    @State private var timeObserverToken: Any?
    
    init(recordingURL: URL, onDiscard: @escaping () -> Void, onSend: @escaping () -> Void) {
        self.recordingURL = recordingURL
        self.onDiscard = onDiscard
        self.onSend = onSend
        
        // Initialize with AVPlayer
        let avPlayer = AVPlayer()
        self._player = State(initialValue: avPlayer)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Broadcast Recording")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.crGold)
                .padding(.top)
            
            // Player view
            ZStack {
                // Video player
                VideoPlayerView(player: player)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.6) // Increase height percentage
                    .cornerRadius(Constants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                            .stroke(Color.crGold, lineWidth: 2)
                    )
                    .padding(.horizontal)
                
                // Loading indicator
                if !isPlayerReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            
            // Video duration and progress
            VStack(spacing: 8) {
                // Video timeline slider
                Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                    if !editing {
                        // Seek to time when user finishes dragging
                        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                        if isPlaying {
                            player.play()
                        }
                    } else {
                        // Pause while dragging
                        if isPlaying {
                            player.pause()
                        }
                    }
                }
                .disabled(!isPlayerReady)
                .accentColor(.crGold)
                .padding(.horizontal)
                
                // Time display
                HStack {
                    // Current time
                    Text(formatSeconds(currentTime))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()
                    
                    Spacer()
                    
                    // Duration
                    Text(formatSeconds(duration))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()
                }
                .padding(.horizontal, 30)
            }
            .padding(.top, 8)
            
            // Player controls
            HStack(spacing: 30) {
                // Restart button
                Button(action: {
                    player.seek(to: .zero)
                    currentTime = 0
                    if isPlaying {
                        player.play()
                    }
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .disabled(!isPlayerReady)
                
                // Play/Pause button
                Button(action: {
                    togglePlayback()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.crGold)
                }
                .disabled(!isPlayerReady)
                
                // Forward 10 seconds
                Button(action: {
                    let newTime = min(currentTime + 10, duration)
                    player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                    currentTime = newTime
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .disabled(!isPlayerReady)
            }
            .padding(.vertical, 10)
            
            // Information text
            Text("Your broadcast has been recorded. Would you like to save it or discard it?")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 20) {
                // Discard button
                Button(action: {
                    cleanupPlayer()
                    onDiscard()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                            .foregroundColor(.white)
                        
                        Text("Discard")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )
                }
                .buttonStyle(ClashRoyaleButtonStyle())
                
                // Send button
                Button(action: {
                    cleanupPlayer()
                    onSend()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                            .foregroundColor(.white)
                        
                        Text("Send")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(GoldButtonBackground())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.1, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: cleanupPlayer)
    }
    
    // Format seconds to MM:SS display
    private func formatSeconds(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func setupPlayer() {
        // Log the setup
        Logger.info("Setting up player for: \(recordingURL.path)", to: Logger.media)
        
        // Create asset options for faster loading
        let options = [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ]
        
        // Create asset with options
        let asset = AVURLAsset(url: recordingURL, options: options)
        
        // Load duration property asynchronously
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                if durationSeconds > 0 {
                    Logger.info("Successfully loaded asset duration: \(durationSeconds)s", to: Logger.media)
                    
                    // Create player item on main thread
                    await MainActor.run {
                        self.duration = durationSeconds
                        
                        // Create item with better loading behavior
                        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["duration", "tracks"])
                        
                        // Replace item in player
                        player.replaceCurrentItem(with: playerItem)
                        
                        // Set player ready after a short delay to ensure UI is updated
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isPlayerReady = true
                            self.player.play()
                            self.isPlaying = true
                        }
                        
                        // Add loop observer
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: playerItem,
                            queue: .main
                        ) { _ in
                            self.player.seek(to: .zero)
                            self.currentTime = 0
                            if self.isPlaying {
                                self.player.play()
                            }
                        }
                        
                        // Add periodic time observer
                        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                        self.timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                            self.currentTime = time.seconds
                        }
                    }
                } else {
                    Logger.error("Asset has zero duration", to: Logger.media)
                    await createFallbackPlayer()
                }
            } catch {
                Logger.error("Failed to load asset duration: \(error.localizedDescription)", to: Logger.media)
                await createFallbackPlayer()
            }
        }
    }
    
    // Add fallback method for corrupted videos
    private func createFallbackPlayer() async {
        await MainActor.run {
            // Create a dummy video as fallback
            MediaGenerator.createColorVideo { url in
                guard let url = url else { return }
                
                Logger.info("Created fallback video at \(url.path)", to: Logger.media)
                
                let asset = AVURLAsset(url: url)
                let playerItem = AVPlayerItem(asset: asset)
                
                // Replace player item
                self.player.replaceCurrentItem(with: playerItem)
                
                // Update duration (typically 5 seconds for the demo video)
                Task {
                    do {
                        let duration = try await asset.load(.duration)
                        await MainActor.run {
                            self.duration = duration.seconds
                            self.isPlayerReady = true
                            self.player.play()
                            self.isPlaying = true
                            
                            // Add loop observer
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: playerItem,
                                queue: .main
                            ) { _ in
                                self.player.seek(to: .zero)
                                self.currentTime = 0
                                if self.isPlaying {
                                    self.player.play()
                                }
                            }
                            
                            // Add periodic time observer
                            let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                            self.timeObserverToken = self.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                                self.currentTime = time.seconds
                            }
                        }
                    } catch {
                        Logger.error("Failed to load fallback duration: \(error.localizedDescription)", to: Logger.media)
                    }
                }
            }
        }
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
    
    private func cleanupPlayer() {
        // Remove time observer
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        // Pause and clear player
        player.pause()
    }
}

// Custom video player view that uses AVPlayerLayer directly for better control
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        // Set up observer for layout changes
        view.layer.addObserver(context.coordinator, forKeyPath: "bounds", options: .new, context: nil)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update player when player reference changes
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: VideoPlayerView
        
        init(_ parent: VideoPlayerView) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "bounds", let layer = (object as? CALayer)?.sublayers?.first as? AVPlayerLayer {
                if let bounds = (object as? CALayer)?.bounds {
                    layer.frame = bounds
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        uiView.layer.removeObserver(coordinator, forKeyPath: "bounds")
    }
}
