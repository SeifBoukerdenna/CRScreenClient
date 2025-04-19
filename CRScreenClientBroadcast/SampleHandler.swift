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
    private let ciCtx = CIContext(options: [.workingColorSpace: NSNull()])

    // MARK: – State
    private var frameCount = 0
    private var lastLog = Date()
    private var processed = 0

    // App Group
    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    private let kCodeKey      = "sessionCode"
    private var sessionCode   = "0000"

    // MARK: – Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // 1) retrieve saved 4‑digit code
        sessionCode = UserDefaults(suiteName: groupID)?
            .string(forKey: kCodeKey) ?? "0000"
        uploadURL = URL(string:
            "http://192.168.2.150:8080/upload/\(sessionCode)")!

        // 2) parse quality level (unchanged)
        if let level = setupInfo?["qualityLevel"] as? String {
            switch level {
            case "low":   compressionQuality = 0.3; frameSkip = 2
            case "high":  compressionQuality = 0.7; frameSkip = 0
            default:      compressionQuality = 0.6; frameSkip = 1
            }
        }
        UserDefaults(suiteName: groupID)?
            .set(Date(), forKey: kStartedAtKey)
        NSLog("Broadcast started (code \(sessionCode))")
    }

    override func processSampleBuffer(_ sb: CMSampleBuffer,
                                      with t: RPSampleBufferType) {
        guard t == .video else { return }

        frameCount += 1
        if frameCount % (frameSkip + 1) != 0 { return }

        processed += 1
        let now = Date()
        if now.timeIntervalSince(lastLog) > 5 {
            NSLog("Sending %.1f FPS, Q=%.2f", Double(processed) /
                  now.timeIntervalSince(lastLog), compressionQuality)
            processed = 0; lastLog = now
        }

        guard let jpeg = jpegData(from: sb) else { return }

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let task = session.uploadTask(with: req, from: jpeg)
        task.priority = URLSessionTask.highPriority
        task.resume()
    }

    override func broadcastFinished() {
        NSLog("Broadcast finished")
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
    }

    // MARK: – Helpers
    private func jpegData(from buf: CMSampleBuffer) -> Data? {
        guard let pix = CMSampleBufferGetImageBuffer(buf) else { return nil }
        CVPixelBufferLockBaseAddress(pix, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pix, .readOnly) }

        let w = CVPixelBufferGetWidth(pix)
        let h = CVPixelBufferGetHeight(pix)
        let ci = CIImage(cvPixelBuffer: pix)

        let down = compressionQuality > 0.6 ? 1280 : 1600
        let img = (w > down || h > down)
            ? ci.transformed(by: CGAffineTransform(
                scaleX: Double(down) / Double(max(w, h)),
                y: Double(down) / Double(max(w, h))))
            : ci

        guard let cg = ciCtx.createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: compressionQuality)
    }
}
