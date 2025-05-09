import SwiftUI
import AVKit

struct BroadcastPlayerScreen: View {
    let broadcast: BroadcastRecord
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var isControlsVisible = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var dragOffset = CGSize.zero
    
    init(broadcast: BroadcastRecord) {
        self.broadcast = broadcast
        _player = State(initialValue: AVPlayer(url: broadcast.fileURL))
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            // Video player
            VideoPlayerWithGestures(player: player, dragOffset: $dragOffset) {
                // Triggered when drag ends with significant offset
                dismiss()
            }
            .ignoresSafeArea()
            
            // Overlay for drag gesture visualization (adds a slight fade effect during drag)
            Color.black.opacity(abs(min(dragOffset.height, 0)) / 1000.00)
                .ignoresSafeArea()
            
            // Controls overlay
            if isControlsVisible {
                VStack {
                    // Top bar with close button
                    HStack {
                        Button(action: dismiss.callAsFunction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if broadcast.width > 0 {
                                Text(broadcast.dimensionsFormatted)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            
                            Text(broadcast.formattedDate)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    // Play/pause button in center
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    // Bottom controls with slider
                    VStack(spacing: 8) {
                        // Time slider
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 50, alignment: .leading)
                            
                            // Custom slider with preview
                            CustomSlider(
                                value: $currentTime,
                                range: 0...max(duration, 1),
                                onEditingChanged: { editing in
                                    if !editing {
                                        // When user finished sliding, seek to position
                                        let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                                        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                        
                                        if !isPlaying {
                                            // If was paused, start playing
                                            player.play()
                                            isPlaying = true
                                        }
                                    }
                                }
                            )
                            
                            Text(formatTime(duration))
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 50, alignment: .trailing)
                        }
                        
                        // Additional controls like replay, skip
                        HStack {
                            Button(action: rewind10) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Play/pause button
                            Button(action: togglePlayback) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            
                            Spacer()
                            
                            Button(action: skip10) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .padding()
                .transition(.opacity)
            }
        }
        .offset(y: max(0, dragOffset.height)) // Apply the drag offset
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // Only allow downward drag
                    if gesture.translation.height > 0 {
                        dragOffset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    // If dragged down more than 100px, dismiss
                    if gesture.translation.height > 100 {
                        dismiss()
                    } else {
                        // Otherwise reset
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isControlsVisible.toggle()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            // Clean up
            player.pause()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func setupPlayer() {
        // Set up time observer to update our time display and progress
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            currentTime = time.seconds
            isPlaying = player.timeControlStatus == .playing
        }
        
        // Get duration using modern API
        if let playerItem = player.currentItem {
            Task {
                do {
                    let asset = playerItem.asset
                    // Using the modern load method instead of directly accessing the duration property
                    let assetDuration = try await asset.load(.duration)
                    self.duration = assetDuration.seconds
                } catch {
                    // Fallback if loading fails
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Error loading duration: \(error)")
                    }
                    // Set a default duration
                    self.duration = 1.0
                }
            }
        }
        
        // Observe when playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            // Reset to beginning
            player.seek(to: .zero)
            isPlaying = false
        }
        
        // Start playback
        player.play()
        isPlaying = true
    }
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func rewind10() {
        let newTime = max(currentTime - 10, 0)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: targetTime)
    }
    
    private func skip10() {
        let newTime = min(currentTime + 10, duration)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: targetTime)
    }
    
    private func formatTime(_ timeInSeconds: Double) -> String {
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Custom video player with swipe gestures
struct VideoPlayerWithGestures: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var dragOffset: CGSize
    var onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        
        // Critical settings for proper display
        controller.videoGravity = .resizeAspect  // This maintains aspect ratio
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// Custom slider with preview
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }
    @State private var isEditing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                // Filled portion
                Rectangle()
                    .foregroundColor(.white)
                    .frame(width: max(0, min(CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound) * geometry.size.width, geometry.size.width)), height: 8)
                    .cornerRadius(4)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: max(0, min(CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound) * geometry.size.width - 10, geometry.size.width - 20)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isEditing = true
                                let newValue = range.lowerBound + Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                                value = max(range.lowerBound, min(newValue, range.upperBound))
                                onEditingChanged(true)
                            }
                            .onEnded { _ in
                                isEditing = false
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(height: 20)
        }
        .frame(height: 20)
        .padding(.vertical, 10)  // Add padding for easier touch
    }
}
