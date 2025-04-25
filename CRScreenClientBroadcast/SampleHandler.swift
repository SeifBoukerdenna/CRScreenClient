import ReplayKit
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
    // MARK: – Connection
    private var uploadURL = URL(string: "http://127.0.0.1:8080/upload/0000")!
    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 2
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    // MARK: – Encoding
    private var compressionQuality: CGFloat = 0.6
    private var frameSkip = 1
    private var downsizeFactor: CGFloat = 0.8 // Default is medium quality
    
    // Thresholds for image resizing based on quality
    private let highQualityThreshold: Int = 1600
    private let mediumQualityThreshold: Int = 1280
    private let lowQualityThreshold: Int = 960
    
    private let ciCtx = CIContext(options: [.workingColorSpace: NSNull()])

    // MARK: – State
    private var frameCount = 0
    private var lastLog = Date()
    private var processed = 0

    // App Group
    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    private let kCodeKey = "sessionCode"
    private let kQualityKey = "streamQuality"
    private var sessionCode = "0000"
    private var qualityLevel = "medium" // Default quality level

    // MARK: – Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // 1) retrieve saved 4‑digit code
        let defaults = UserDefaults(suiteName: groupID)
        sessionCode = defaults?.string(forKey: kCodeKey) ?? "0000"
        
        // Get the server URL
        let serverBase = "http://172.20.10.3:8080/upload/"
        uploadURL = URL(string: "\(serverBase)\(sessionCode)") ?? uploadURL

        // 2) Get quality level from UserDefaults or setupInfo
        if let savedQuality = defaults?.string(forKey: kQualityKey) {
            qualityLevel = savedQuality
        } else if let quality = setupInfo?["qualityLevel"] as? String {
            qualityLevel = quality
        }
        
        // Apply quality settings
        applyQualitySettings(qualityLevel)
        
        defaults?.set(Date(), forKey: kStartedAtKey)
        NSLog("Broadcast started (code \(sessionCode), quality \(qualityLevel))")
        NSLog("Upload URL: \(uploadURL.absoluteString)")
    }

    override func processSampleBuffer(_ sb: CMSampleBuffer,
                                      with t: RPSampleBufferType) {
        guard t == .video else { return }

        frameCount += 1
        if frameCount % (frameSkip + 1) != 0 { return }

        processed += 1
        let now = Date()
        if now.timeIntervalSince(lastLog) > 5 {
            NSLog("Sending %.1f FPS, Q=%.2f, Quality Level=%@",
                  Double(processed) / now.timeIntervalSince(lastLog),
                  compressionQuality,
                  qualityLevel)
            processed = 0; lastLog = now
        }

        guard let jpeg = jpegData(from: sb) else { return }

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.setValue(qualityLevel, forHTTPHeaderField: "X-Quality-Level")
        let task = session.uploadTask(with: req, from: jpeg)
        task.priority = URLSessionTask.highPriority
        task.resume()
    }

    override func broadcastFinished() {
        NSLog("Broadcast finished")
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
    }
    
    // MARK: - Quality Settings
    private func applyQualitySettings(_ quality: String) {
        switch quality {
        case "low":
            compressionQuality = 0.3
            frameSkip = 2
            downsizeFactor = 0.6
        case "high":
            compressionQuality = 0.85
            frameSkip = 0
            downsizeFactor = 1.0
        default: // medium
            compressionQuality = 0.6
            frameSkip = 1
            downsizeFactor = 0.8
        }
    }

    // MARK: – Helpers
    private func jpegData(from buf: CMSampleBuffer) -> Data? {
        guard let pix = CMSampleBufferGetImageBuffer(buf) else { return nil }
        CVPixelBufferLockBaseAddress(pix, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pix, .readOnly) }

        let w = CVPixelBufferGetWidth(pix)
        let h = CVPixelBufferGetHeight(pix)
        let ci = CIImage(cvPixelBuffer: pix)
        
        // Resize threshold depends on quality level
        let threshold: Int
        switch qualityLevel {
        case "low": threshold = lowQualityThreshold
        case "high": threshold = highQualityThreshold
        default: threshold = mediumQualityThreshold
        }
        
        // Apply resize if needed
        let img: CIImage
        if w > threshold || h > threshold {
            let scaleFactor = CGFloat(threshold) / CGFloat(max(w, h)) * downsizeFactor
            img = ci.transformed(by: CGAffineTransform(
                scaleX: scaleFactor,
                y: scaleFactor
            ))
        } else if downsizeFactor < 1.0 {
            // Apply downsizing even for smaller images in low/medium quality
            img = ci.transformed(by: CGAffineTransform(
                scaleX: downsizeFactor,
                y: downsizeFactor
            ))
        } else {
            img = ci
        }

        guard let cg = ciCtx.createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: compressionQuality)
    }
}
