import SwiftUI
import AVKit
import ReplayKit

struct ContentView: View {
    @StateObject private var bm = BroadcastManager()
    @StateObject private var pipManager = PiPManager()
    @State private var broadcastButton: UIButton?
    @State private var player = AVPlayer()
    @State private var isVideoPrepared = false
    @State private var shouldSetupVideo = false
    
    @Environment(\.scenePhase) private var phase
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.crBlue, .crBlue.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Player View for PiP (hidden when not broadcasting)
                if bm.isBroadcasting {
                    if isVideoPrepared {
                        PlayerView(player: player) { layer in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                pipManager.setup(with: layer)
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.crGold, lineWidth: 2)
                        )
                        .padding(.horizontal)
                    } else {
                        // Placeholder until video is prepared
                        Rectangle()
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.crGold, lineWidth: 2)
                            )
                            .padding(.horizontal)
                    }
                }
                
                // LIVE / OFFLINE pills
                HStack(spacing: 12) {
                    CapsuleLabel(
                        text: bm.isBroadcasting ? "LIVE" : "OFFLINE",
                        color: bm.isBroadcasting ? .red : .gray
                    )
                    if bm.isBroadcasting {
                        CapsuleLabel(
                            text: timeString(bm.elapsed),
                            color: .crGold.opacity(0.9)
                        )
                    }
                }
                
                // Session Code only when live
                if bm.isBroadcasting {
                    VStack(spacing: 6) {
                        Text("Session Code")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        Text(bm.code)
                            .font(.system(
                                size: 48,
                                weight: .heavy,
                                design: .monospaced
                            ))
                            .foregroundColor(.white)
                    }
                }
                
                // Guide
                GuideCard()
                
                // Start/Stop button
                Button(action: toggleBroadcast) {
                    VStack(spacing: 8) {
                        Image(systemName: bm.isBroadcasting
                              ? "stop.fill"
                              : "dot.radiowaves.left.and.right")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .foregroundColor(.white)
                        Text(bm.isBroadcasting ? "Stop Broadcasting"
                                               : "Start Broadcasting")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                    .background(GoldButtonBackground())
                }
                .buttonStyle(.plain)
                
                // PiP Button (only shown when broadcasting and video is prepared)
                if bm.isBroadcasting && isVideoPrepared {
                    Button(action: {
                        pipManager.togglePiP()
                    }) {
                        Label(
                            pipManager.isPiPActive ? "Exit Picture-in-Picture" : "Enter Picture-in-Picture",
                            systemImage: pipManager.isPiPActive ? "pip.exit" : "pip.enter"
                        )
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.crPurple)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                    .disabled(!pipManager.isPiPPossible)
                    .opacity(pipManager.isPiPPossible ? 1.0 : 0.5)
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal)
        }
        .background(
            BroadcastPickerHelper(
                extensionID: "com.elmelz.CRScreenClient.Broadcast",
                broadcastButton: $broadcastButton
            )
            .frame(width: 0, height: 0)
        )
        .onAppear {
            // Check initial state
            if bm.isBroadcasting && !isVideoPrepared {
                shouldSetupVideo = true
            }
        }
        .onChange(of: phase) { _, newValue in
            if newValue == .background {
                bm.stopIfNeeded()
            }
        }
        .onChange(of: bm.isBroadcasting) { _, newValue in
            if newValue {
                // Mark that we should set up the video, but don't do it during view update
                shouldSetupVideo = true
                isVideoPrepared = false
            } else {
                player.pause()
                isVideoPrepared = false
            }
        }
        .onChange(of: shouldSetupVideo) { _, newValue in
            if newValue {
                // This change happens after the view update is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    setupDemoVideo()
                    shouldSetupVideo = false
                }
            }
        }
    }
    
    private func setupDemoVideo() {
        // Use a reliable sample video for testing
        let urlString = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        
        guard let url = URL(string: urlString) else {
            createColorVideoItem()
            return
        }
        
        // Create asset
        let asset = AVURLAsset(url: url)
        
        // iOS 17+ approach using modern async/await APIs
        Task {
            do {
                // Load the playable status asynchronously
                let isPlayable = try await asset.load(.isPlayable)
                
                if isPlayable {
                    // Create player item and set it on main thread
                    let playerItem = AVPlayerItem(asset: asset)
                    
                    await MainActor.run {
                        // Set up observers before playing using closure-based notification
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: playerItem,
                            queue: .main
                        ) { [self] _ in
                            player.seek(to: .zero)
                            player.play()
                        }
                        
                        self.player.replaceCurrentItem(with: playerItem)
                        self.player.play()
                        self.player.actionAtItemEnd = .none
                        self.isVideoPrepared = true
                    }
                } else {
                    await MainActor.run {
                        self.createColorVideoItem()
                    }
                }
            } catch {
                print("Error loading asset: \(error)")
                await MainActor.run {
                    self.createColorVideoItem()
                }
            }
        }
    }
    
    private func createColorVideoItem() {
        // Create a simple colored frame video for demo
        let size = CGSize(width: 640, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Draw gradient background
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Add text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = "Screen Broadcast"
            let textRect = CGRect(
                x: 0, y: (size.height - 36) / 2,
                width: size.width, height: 36
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // Create a video from this image
        if let pixelBuffer = createPixelBuffer(from: image),
           let videoURL = createVideoFromPixelBuffer(pixelBuffer: pixelBuffer) {
            player.replaceCurrentItem(with: AVPlayerItem(url: videoURL))
            player.play()
            player.actionAtItemEnd = .none
            
            // Loop the video using closure-based notification
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [self] _ in
                player.seek(to: .zero)
                player.play()
            }
            
            // Update state after successful video creation
            isVideoPrepared = true
        }
    }
    
    private func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Failed to create pixel buffer")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        if let context = context {
            // Clear background to black
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Draw the image centered
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            print("Failed to create CG context")
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    private func createVideoFromPixelBuffer(pixelBuffer: CVPixelBuffer) -> URL? {
        let documentsPath = NSTemporaryDirectory()
        let videoOutputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("demoVideo.mov")
        
        try? FileManager.default.removeItem(at: videoOutputURL)
        
        guard let assetWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: .mov) else {
            return nil
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: CVPixelBufferGetWidth(pixelBuffer),
            AVVideoHeightKey: CVPixelBufferGetHeight(pixelBuffer)
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: nil
        )
        
        writerInput.expectsMediaDataInRealTime = true
        assetWriter.add(writerInput)
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        // Create a 5 second video
        let frameCount = 150 // 5 seconds at 30fps
        let frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        for i in 0..<frameCount {
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(i))
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
        
        writerInput.markAsFinished()
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        assetWriter.finishWriting {
            dispatchGroup.leave()
        }
        
        dispatchGroup.wait()
        
        return videoOutputURL
    }
    
    private func toggleBroadcast() {
        if !bm.isBroadcasting { bm.prepareNewCode() }
        broadcastButton?.sendActions(for: .touchUpInside)
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d",
               Int(t) / 3600, Int(t) / 60 % 60, Int(t) % 60)
    }
}
