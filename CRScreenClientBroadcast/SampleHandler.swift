import ReplayKit
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
    // Configure connection
    private let uploadURL = URL(string: "http://192.168.2.150:8080/upload")!
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0  // shorter timeout
        config.waitsForConnectivity = false     // don't wait for connectivity
        return URLSession(configuration: config)
    }()
    
    // Image compression settings
    private var compressionQuality: CGFloat = 0.3  // Lower quality for faster transmission
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    
    // Performance tracking
    private var frameCount = 0
    private var lastLogTime = Date()
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        if let q = setupInfo?["quality"] as? NSNumber {
            compressionQuality = max(0.1, min(0.7, CGFloat(truncating: q)))
        }
        
        // Log the start of broadcast
        NSLog("Broadcast started with quality: \(compressionQuality)")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        // Only handle video frames
        guard sampleBufferType == .video else { return }
        
        // Performance tracking
        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(lastLogTime) > 5.0 {
            let fps = Double(frameCount) / now.timeIntervalSince(lastLogTime)
            NSLog("Capturing at \(fps) FPS")
            frameCount = 0
            lastLogTime = now
        }
        
        // Fast path to get JPEG data
        guard let jpegData = optimizedJpegData(from: sampleBuffer) else { return }
        
        // Prepare and send request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        // Use a background task for network operations
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
    }
    
    // Optimized JPEG encoder with less overhead
    private func optimizedJpegData(from buffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Create CIImage directly from pixel buffer - faster than UIImage path
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        // Use lower compression quality for faster encoding
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: compressionQuality)
    }
}
