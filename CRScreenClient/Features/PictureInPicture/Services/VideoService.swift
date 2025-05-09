import AVFoundation
import UIKit
import SwiftUI

/// Service for handling video creation and playback
class VideoService {
    /// Prepares a video player with content
    
    static func setupDemoVideo(player: AVPlayer, useLocalOnly: Bool = false, onPrepared: @escaping () -> Void) {
        if Constants.FeatureFlags.enableDebugLogging {
            print("Setting up demo video. Local only: \(useLocalOnly)")
        }
        
        if !useLocalOnly, let url = URL(string: Constants.URLs.demoVideo) {
            // Create asset
            let asset = AVURLAsset(url: url)
            
            Task {
                do {
                    // Load the playable status asynchronously
                    let isPlayable = try await asset.load(.isPlayable)
                    
                    if isPlayable {
                        // Create player item and set it on main thread
                        let playerItem = AVPlayerItem(asset: asset)
                        
                        // Configure player item for optimal playback
                        playerItem.preferredForwardBufferDuration = 5.0
                        
                        await MainActor.run {
                            // Set up observers before playing using closure-based notification
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: playerItem,
                                queue: .main
                            ) { _ in
                                player.seek(to: .zero)
                                player.play()
                            }
                            
                            // Configure player for optimal playback
                            player.automaticallyWaitsToMinimizeStalling = false
                            player.allowsExternalPlayback = false
                            
                            player.replaceCurrentItem(with: playerItem)
                            player.play()
                            player.actionAtItemEnd = .none
                            onPrepared()
                        }
                    } else {
                        if Constants.FeatureFlags.enableDebugLogging {
                            print("Asset is not playable")
                        }
                        await MainActor.run {
                            createColorVideoItem(player: player, onPrepared: onPrepared)
                        }
                    }
                } catch {
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Error loading asset: \(error)")
                    }
                    await MainActor.run {
                        createColorVideoItem(player: player, onPrepared: onPrepared)
                    }
                }
            }
        } else {
            // Use locally generated video
            createColorVideoItem(player: player, onPrepared: onPrepared)
        }
    }
    
    /// Creates a colored video as fallback
    static func createColorVideoItem(player: AVPlayer, onPrepared: @escaping () -> Void) {
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
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
            
            // Update state after successful video creation
            onPrepared()
        } else {
            if Constants.FeatureFlags.enableDebugLogging {
                print("Failed to create video buffer")
            }
        }
    }
    
    private static func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
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
            if Constants.FeatureFlags.enableDebugLogging {
                print("Failed to create pixel buffer")
            }
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
            if Constants.FeatureFlags.enableDebugLogging {
                print("Failed to create CG context")
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    private static func createVideoFromPixelBuffer(pixelBuffer: CVPixelBuffer) -> URL? {
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
}
