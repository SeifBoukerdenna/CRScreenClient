import UIKit
import AVFoundation

/// Utility for generating media content
class MediaGenerator {
    /// Creates a video with a colored background and text
    static func createColorVideo(completion: @escaping (URL?) -> Void) {
        // Get the device screen dimensions for proper video size
        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale
        let size = CGSize(
            width: screenBounds.width * screenScale,
            height: screenBounds.height * screenScale
        )
        
        if Constants.FeatureFlags.enableDebugLogging {
            print("Creating video with screen dimensions: \(size.width)x\(size.height)")
        }
        
        // Create a simple colored frame with proper dimensions
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
                .font: UIFont.boldSystemFont(ofSize: 36 * screenScale),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = "Screen Broadcast"
            let textRect = CGRect(
                x: 0, y: (size.height - 36 * screenScale) / 2,
                width: size.width, height: 36 * screenScale
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // Create a video from this image
        if let pixelBuffer = createPixelBuffer(from: image) {
            createVideoFromPixelBuffer(pixelBuffer: pixelBuffer, completion: completion)
        } else {
            completion(nil)
        }
    }
    
    /// Creates a CVPixelBuffer from a UIImage
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
            Logger.error("Failed to create pixel buffer", to: Logger.media)
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
            Logger.error("Failed to create CG context", to: Logger.media)
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    /// Creates a video file from a pixel buffer
    private static func createVideoFromPixelBuffer(pixelBuffer: CVPixelBuffer, completion: @escaping (URL?) -> Void) {
        let documentsPath = NSTemporaryDirectory()
        let videoOutputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("demoVideo.mov")
        
        try? FileManager.default.removeItem(at: videoOutputURL)
        
        guard let assetWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: .mov) else {
            Logger.error("Failed to create asset writer", to: Logger.media)
            completion(nil)
            return
        }
        
        // Use the actual dimensions from the pixel buffer
        let videoWidth = CVPixelBufferGetWidth(pixelBuffer)
        let videoHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        // Use high quality video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6000000, // 6 Mbps
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30 // Keyframe every second at 30fps
            ]
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
        
        // Create a 5 second video at 30fps
        let frameCount = 150 // 5 seconds at 30fps
        let frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        if Constants.FeatureFlags.enableDebugLogging {
            print("Creating video with dimensions: \(videoWidth)x\(videoHeight)")
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<frameCount {
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(i))
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }
            
            writerInput.markAsFinished()
            
            assetWriter.finishWriting {
                DispatchQueue.main.async {
                    completion(videoOutputURL)
                }
            }
        }
    }
}
