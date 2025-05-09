import SwiftUI
import AVKit

struct BroadcastPlayerScreen: View {
    let broadcast: BroadcastRecord
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var isControlsVisible = true
    
    init(broadcast: BroadcastRecord) {
        self.broadcast = broadcast
        _player = State(initialValue: AVPlayer(url: broadcast.fileURL))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Use the custom player that maintains the correct aspect ratio
            FullSizeVideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    // Set up video player with optimal settings
                    player.automaticallyWaitsToMinimizeStalling = false
                    player.play()
                    
                    // Log the dimensions if available
                    if Constants.FeatureFlags.enableDebugLogging && broadcast.width > 0 {
                        print("Playing video with dimensions: \(broadcast.dimensionsFormatted)")
                    }
                }
                .onDisappear {
                    player.pause()
                }
            
            // Controls overlay
            if isControlsVisible {
                VStack {
                    HStack {
                        Button(action: dismiss.callAsFunction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        if broadcast.width > 0 {
                            Text(broadcast.dimensionsFormatted)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                        }
                    }
                    
                    Spacer()
                    
                    // Playback controls
                    HStack {
                        Button(action: {
                            if player.timeControlStatus == .playing {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }) {
                            Image(systemName: player.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(broadcast.formattedDate)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            
                            Text(broadcast.formattedDuration)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.5)))
                    }
                }
                .padding()
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isControlsVisible.toggle()
            }
        }
    }
}

// Custom video player implementation that maintains correct aspect ratio
struct FullSizeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
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
