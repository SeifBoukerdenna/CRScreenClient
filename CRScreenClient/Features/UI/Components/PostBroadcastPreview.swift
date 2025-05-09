//
//  PostBroadcastPreview.swift
//  CRScreenClient
//
//  Shows the recorded broadcast in a Clash-Royale-styled card,
//  automatically sizing the player to the movie’s real aspect-ratio.
//

import SwiftUI
import AVKit

struct PostBroadcastPreview: View {

    // ───────── Public API ─────────
    let recordingURL: URL
    let onDiscard: () -> Void
    let onSend: () -> Void

    // ───────── State ─────────
    @State private var player: AVPlayer = .init()
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlayerReady = false
    @State private var timeObserverToken: Any?

    // dynamic aspect-ratio (default = portrait iPhone)
    @State private var videoAR: CGFloat = 9.0 / 16.0   // width / height

    // MARK: – Body
    var body: some View {
        VStack(spacing: 16) {

            Text("Broadcast Recording")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.crGold)
                .padding(.top)

            // ───────── Player Card ─────────
            ZStack {
                VideoPlayerView(player: player)
                    .aspectRatio(videoAR, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                            .stroke(Color.crGold, lineWidth: 2)
                    )
                    .padding(.horizontal)

                if !isPlayerReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }

            // ───────── Timeline & Controls ─────────
            timelineView
            controlsView

            // ───────── Info & Actions ─────────
            Text("Your broadcast has been recorded. Would you like to save it or discard it?")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            actionButtons
                .padding(.bottom, 40)
        }
        .background(
            LinearGradient(colors: [.crBlue, Color(red: 0, green: 0.1, blue: 0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: cleanupPlayer)
    }

    // MARK: – Sub-Views
    private var timelineView: some View {
        VStack(spacing: 8) {
            Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                if editing {
                    player.pause()
                } else {
                    player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                    if isPlaying { player.play() }
                }
            }
            .disabled(!isPlayerReady)
            .accentColor(.crGold)
            .padding(.horizontal)

            HStack {
                Text(format(currentTime))
                Spacer()
                Text(format(duration))
            }
            .font(.system(size: 14, weight: .medium).monospacedDigit())
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 30)
        }
        .padding(.top, 8)
    }

    private var controlsView: some View {
        HStack(spacing: 30) {
            Button { restart() } label: {
                Image(systemName: "backward.end.fill")
            }
            .disabled(!isPlayerReady)

            Button { togglePlayback() } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.crGold)
            }
            .disabled(!isPlayerReady)

            Button { skip(10) } label: {
                Image(systemName: "goforward.10")
            }
            .disabled(!isPlayerReady)
        }
        .font(.system(size: 24))
        .foregroundColor(.white)
        .padding(.vertical, 10)
    }

    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: { cleanupPlayer(); onDiscard() }) {
                labelledButton(icon: "trash.fill", text: "Discard", bg: .red.opacity(0.8))
            }
            .buttonStyle(ClashRoyaleButtonStyle())

            Button(action: { cleanupPlayer(); onSend() }) {
                labelledButton(icon: "square.and.arrow.up.fill", text: "Send", bg: .clear)
                    .background(GoldButtonBackground())
            }
            .buttonStyle(.plain)
        }
    }

    private func labelledButton(icon: String, text: String, bg: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .resizable().scaledToFit().frame(height: 24)
            Text(text).font(.system(size: 18, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 32).padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(bg)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.5), lineWidth: 2))
        )
    }

    // MARK: – Player Setup
    private func setupPlayer() {
        let asset = AVURLAsset(url: recordingURL,
                               options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        // Load metadata asynchronously
        Task {
            do {
                // Duration
                let dur = try await asset.load(.duration)
                duration = dur.seconds

                // Aspect-ratio
                if let track = try await asset.loadTracks(withMediaType: .video).first {
                    // Use the modern load methods instead of deprecated properties
                    let naturalSize = try await track.load(.naturalSize)
                    let preferredTransform = try await track.load(.preferredTransform)
                    
                    // Apply the transform to the size
                    let size = naturalSize.applying(preferredTransform)
                    let w = abs(size.width), h = abs(size.height)
                    if w > 0 && h > 0 { videoAR = w / h }
                }

                // Prepare player on the main thread
                await MainActor.run {
                    let item = AVPlayerItem(asset: asset,
                                            automaticallyLoadedAssetKeys: ["duration", "tracks"])
                    player.replaceCurrentItem(with: item)

                    // Ready after a brief delay to let layout settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isPlayerReady = true
                        player.play(); isPlaying = true
                    }

                    // Loop & time observer
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                           object: item,
                                                           queue: .main) { _ in restart() }
                    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval,
                                                                       queue: .main) { t in
                        currentTime = t.seconds
                    }
                }
            } catch {
                Logger.error("Preview setup failed: \(error.localizedDescription)", to: Logger.media)
            }
        }
    }

    // MARK: – Helpers
    private func togglePlayback() { isPlaying.toggle(); isPlaying ? player.play() : player.pause() }
    private func restart()        { player.seek(to: .zero); currentTime = 0; if isPlaying { player.play() } }
    private func skip(_ s: Double){ let t = min(currentTime + s, duration); player.seek(to: .init(seconds: t, preferredTimescale: 600)); currentTime = t }
    private func cleanupPlayer()  {
        if let tok = timeObserverToken { player.removeTimeObserver(tok); timeObserverToken = nil }
        player.pause(); player.replaceCurrentItem(with: nil)
    }
    private func format(_ s: Double) -> String { String(format: "%02d:%02d", Int(s)/60, Int(s)%60) }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    // MARK: – UIViewRepresentable
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect       // keep full frame
        layer.frame = view.bounds
        view.layer.addSublayer(layer)

        view.layer.addObserver(context.coordinator,
                               forKeyPath: "bounds",
                               options: .new,
                               context: nil)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.player = player
            layer.videoGravity = .resizeAspect
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: – Coordinator
    class Coordinator: NSObject {
        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == "bounds",
                  let container = object as? CALayer,
                  let playerLayer = container.sublayers?.first as? AVPlayerLayer else { return }
            playerLayer.frame = container.bounds
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        uiView.layer.removeObserver(coordinator, forKeyPath: "bounds")
    }
}
