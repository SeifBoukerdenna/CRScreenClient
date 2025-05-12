import ReplayKit
import UIKit
import CoreImage
import AVFoundation

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
    private var threshold: Int = 1280 // Will be set based on quality
    
    // Debug settings
    private var disableLocalRecording = false
    private var useCustomServer = false
    private var customServerURL = ""
    
    // Local recording
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private var recordingURL: URL?

    // MARK: – Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // Get the defaults from the app group
        let defaults = UserDefaults(suiteName: groupID)
        
        // 1) Retrieve saved 4‑digit code
        sessionCode = defaults?.string(forKey: kCodeKey) ?? "0000"
        
        // 2) Get debug settings
        disableLocalRecording = defaults?.bool(forKey: "debug_disableLocalRecording") ?? false
        useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
        customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
        
        // 3) Get the server URL
        if useCustomServer && !customServerURL.isEmpty {
            var customURL = customServerURL
            
            // Check if the custom URL already includes the protocol
            if !customURL.hasPrefix("http://") && !customURL.hasPrefix("https://") {
                customURL = "http://" + customURL
            }
            
            if !customURL.hasSuffix("/") {
                customURL += "/"
            }
            
            uploadURL = URL(string: "\(customURL)\(sessionCode)") ?? uploadURL
            NSLog("Using custom server URL: \(uploadURL.absoluteString)")
        } else {
            let serverBase = "http://192.168.2.12:8080/upload/"
            uploadURL = URL(string: "\(serverBase)\(sessionCode)") ?? uploadURL
        }

        // 4) Get quality level from UserDefaults or setupInfo
        if let savedQuality = defaults?.string(forKey: kQualityKey) {
            qualityLevel = savedQuality
        } else if let quality = setupInfo?["qualityLevel"] as? String {
            qualityLevel = quality
        }
        
        // Apply quality settings
        applyQualitySettings(qualityLevel)
        
        // Set up local recording if not disabled
        if !disableLocalRecording {
            setupLocalRecording()
        } else {
            NSLog("Local recording is disabled by debug settings")
        }
        
        defaults?.set(Date(), forKey: kStartedAtKey)
        NSLog("Broadcast started (code \(sessionCode), quality \(qualityLevel))")
        NSLog("Upload URL: \(uploadURL.absoluteString)")
        if let recordingURL = recordingURL {
            NSLog("Recording locally to: %@", recordingURL.path)
        }
    }

    override func processSampleBuffer(_ sb: CMSampleBuffer,
                                      with t: RPSampleBufferType) {
        guard t == .video else { return }

        frameCount += 1
        
        // Process for local recording if not disabled
        if !disableLocalRecording {
            processForLocalRecording(sb)
        }
        
        // Skip frames for server upload based on quality settings
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

        // Use preserve dimensions for high quality recording
        let preserveOriginalDimensions = (qualityLevel == "high")
        guard let jpeg = jpegData(from: sb, preserveOriginalDimensions: preserveOriginalDimensions) else { return }

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
        
        // Finalize local recording if not disabled
        if !disableLocalRecording {
            finalizeRecording { success in
                if success {
                    NSLog("Successfully finalized local recording")
                } else {
                    NSLog("Failed to finalize local recording")
                }
                
                // Log the recordings directory path
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID) {
                    let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
                    NSLog("Recordings directory: %@", recordingsDir.path)
                    
                    // List all files in the recordings directory
                    do {
                        let files = try FileManager.default.contentsOfDirectory(atPath: recordingsDir.path)
                        NSLog("Files in recordings directory: %@", files.joined(separator: ", "))
                    } catch {
                        NSLog("Failed to list recordings directory: %@", error.localizedDescription)
                    }
                }
            }
        } else {
            NSLog("Local recording was disabled - no recording to finalize")
        }
        
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
    }
    
    // MARK: - Quality Settings
    private func applyQualitySettings(_ quality: String) {
        switch quality {
        case "low":
            compressionQuality = 0.3
            frameSkip = 2
            downsizeFactor = 0.6
            threshold = lowQualityThreshold
        case "high":
            compressionQuality = 0.85
            frameSkip = 0
            downsizeFactor = 1.0
            threshold = highQualityThreshold
        default: // medium
            compressionQuality = 0.6
            frameSkip = 1
            downsizeFactor = 0.8
            threshold = mediumQualityThreshold
        }
    }
    
    // MARK: - Local Recording
    private func setupLocalRecording() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            NSLog("Failed to get app group container URL")
            return
        }
        
        // Create Recordings directory if it doesn't exist
        let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            do {
                try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
                NSLog("Created recordings directory at: %@", recordingsDir.path)
            } catch {
                NSLog("Failed to create recordings directory: %@", error.localizedDescription)
                return
            }
        }
        
        // Create a unique filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "broadcast_\(timestamp).mp4"
        recordingURL = recordingsDir.appendingPathComponent(filename)
        
        guard let recordingURL = recordingURL else {
            NSLog("Failed to create recording URL")
            return
        }
        
        // Remove existing file if any
        if FileManager.default.fileExists(atPath: recordingURL.path) {
            do {
                try FileManager.default.removeItem(at: recordingURL)
            } catch {
                NSLog("Failed to remove existing recording: %@", error.localizedDescription)
            }
        }
        
        // We'll initialize the AVAssetWriter when we get the first frame
        // to ensure we have the correct video dimensions
        NSLog("Recording setup complete. Will save to: %@", recordingURL.path)
    }
    
    private func processForLocalRecording(_ sampleBuffer: CMSampleBuffer) {
        guard let recordingURL = recordingURL else {
            return
        }
        
        // Initialize asset writer with the first frame
        if assetWriter == nil {
            do {
                assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: .mp4)
                
                // Get video dimensions from sample buffer
                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                    NSLog("Failed to get format description")
                    return
                }
                
                // No need for optional binding here since this returns a struct directly
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                
                // High quality recording settings
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 6000000, // 6 Mbps
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoMaxKeyFrameIntervalKey: 30  // Keyframe every second at 30fps
                    ]
                ]
                
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput?.expectsMediaDataInRealTime = true
                
                // Create pixel buffer adapter
                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: dimensions.width,
                    kCVPixelBufferHeightKey as String: dimensions.height
                ]
                
                pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput!,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )
                
                if let videoInput = videoInput, assetWriter!.canAdd(videoInput) {
                    assetWriter!.add(videoInput)
                } else {
                    NSLog("Failed to add video input to asset writer")
                    assetWriter = nil
                    return
                }
                
                // Start writing
                let success = assetWriter!.startWriting()
                if !success {
                    NSLog("Failed to start writing: %@", assetWriter!.error?.localizedDescription ?? "Unknown error")
                    assetWriter = nil
                    return
                }
                
                assetWriter!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                recordingStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                NSLog("Started recording with dimensions: %dx%d", dimensions.width, dimensions.height)
            } catch {
                NSLog("Failed to create asset writer: %@", error.localizedDescription)
                return
            }
        }
        
        // Write video frame
        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData,
              let recordingStartTime = recordingStartTime else {
            return
        }
        
        // Get presentation time
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        _ = CMTimeSubtract(presentationTime, recordingStartTime)
        
        // Directly append sample buffer to the video input
        videoInput.append(sampleBuffer)
    }
    
    private func finalizeRecording(completion: @escaping (Bool) -> Void) {
        guard let assetWriter = assetWriter else {
            NSLog("No asset writer to finalize")
            completion(false)
            return
        }
        
        // Mark input as finished
        videoInput?.markAsFinished()
        
        // Finish writing
        assetWriter.finishWriting {
            let success = assetWriter.status == .completed
            if success {
                NSLog("Successfully finished writing recording to: %@", self.recordingURL?.path ?? "unknown")
            } else if let error = assetWriter.error {
                NSLog("Failed to finish writing: %@", error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: – Helpers
    private func jpegData(from buf: CMSampleBuffer, preserveOriginalDimensions: Bool = false) -> Data? {
        guard let pix = CMSampleBufferGetImageBuffer(buf) else { return nil }
        CVPixelBufferLockBaseAddress(pix, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pix, .readOnly) }

        let w = CVPixelBufferGetWidth(pix)
        let h = CVPixelBufferGetHeight(pix)
        let ci = CIImage(cvPixelBuffer: pix)
        
        // Apply resize if needed and not preserving dimensions
        let img: CIImage
        if !preserveOriginalDimensions && (w > threshold || h > threshold) {
            let scaleFactor = CGFloat(threshold) / CGFloat(max(w, h)) * downsizeFactor
            img = ci.transformed(by: CGAffineTransform(
                scaleX: scaleFactor,
                y: scaleFactor
            ))
        } else if !preserveOriginalDimensions && downsizeFactor < 1.0 {
            // Apply downsizing even for smaller images in low/medium quality
            img = ci.transformed(by: CGAffineTransform(
                scaleX: downsizeFactor,
                y: downsizeFactor
            ))
        } else {
            // Keep original dimensions
            img = ci
        }

        guard let cg = ciCtx.createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: compressionQuality)
    }
}
