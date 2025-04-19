import ReplayKit
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
    // Configure connection
    private let uploadURL = URL(string: "http://192.168.2.150:8080/upload")!
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    // Quality settings (defaults to medium quality)
    private var compressionQuality: CGFloat = 0.6  // Medium quality
    private var frameSkip = 1  // Process every 2nd frame for medium quality
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    
    // Frame sampling
    private var frameCount = 0
    
    // Performance tracking
    private var lastLogTime = Date()
    private var processedFrames = 0
    
    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // Parse quality level from setup info
        if let qualityLevel = setupInfo?["qualityLevel"] as? String {
            switch qualityLevel {
            case "low":
                compressionQuality = 0.3
                frameSkip = 2  // Process every 3rd frame
            case "high":
                compressionQuality = 0.7
                frameSkip = 0  // Process every frame
            default: // medium (default)
                compressionQuality = 0.6
                frameSkip = 1  // Process every 2nd frame
            }
        }
        
        // Override quality if explicitly provided
        if let q = setupInfo?["quality"] as? NSNumber {
            compressionQuality = max(0.2, min(0.8, CGFloat(truncating: q)))
        }
        
        UserDefaults(suiteName: groupID)?
                .set(Date(), forKey: kStartedAtKey)
        
        NSLog("Broadcast started with quality: \(compressionQuality), frame skip: \(frameSkip)")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        // Only handle video frames
        guard sampleBufferType == .video else { return }
        
        // Frame sampling - skip frames based on quality settings
        frameCount += 1
        if frameCount % (frameSkip + 1) != 0 {
            return  // Skip this frame
        }
        
        // Performance tracking
        processedFrames += 1
        let now = Date()
        if now.timeIntervalSince(lastLogTime) > 5.0 {
            let fps = Double(processedFrames) / now.timeIntervalSince(lastLogTime)
            NSLog("Sending \(fps) FPS to server (quality: \(compressionQuality))")
            processedFrames = 0
            lastLogTime = now
        }
        
        // Process frame to JPEG with appropriate quality
        guard let jpegData = optimizedJpegData(from: sampleBuffer) else { return }
        
        // Send to server
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        let task = session.uploadTask(with: request, from: jpegData) { _, _, error in
            if let error = error {
                NSLog("Upload error: \(error.localizedDescription)")
            }
        }
        task.priority = URLSessionTask.highPriority
        task.resume()
    }
    
    override func broadcastFinished() {
        NSLog("Broadcast finished")
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)

    }
    
    // Optimized JPEG encoder with quality settings
    private func optimizedJpegData(from buffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Get dimensions for potential downsampling
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create CIImage directly from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Optional downsampling for very large screens (e.g., iPad Pro)
        // This helps maintain low latency while keeping good quality
        let finalImage: CIImage
        
        // The downsampling threshold depends on the compression quality
        // Higher quality = more aggressive downsampling
        let downsampleThreshold = compressionQuality > 0.6 ? 1280 : 1600
        
        if width > downsampleThreshold || height > downsampleThreshold {
            // Downsample large screens
            let scale = Double(downsampleThreshold) / max(Double(width), Double(height))
            finalImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        } else {
            finalImage = ciImage
        }
        
        // Create CGImage with proper quality
        guard let cgImage = ciContext.createCGImage(finalImage, from: finalImage.extent) else { return nil }
        
        // Use configured compression quality
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: compressionQuality)
    }
}
