// CRScreenClientBroadcast/SampleHandler.swift

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
    
    // Recording Assets
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var recordingURL: URL?
    private var isRecording = false
    private var firstSampleTime: CMTime?
    private var hasReceivedFirstSample = false
    
    // For tracking writing status
    private var isFinishingRecording = false
    private var hasSamplesWaitingToWrite = false

    // MARK: – Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // 1) retrieve saved 4‑digit code
        let defaults = UserDefaults(suiteName: groupID)
        sessionCode = defaults?.string(forKey: kCodeKey) ?? "0000"
        
        // Get the server URL
        let serverBase = "http://10.20.5.212:8080/upload/"
        uploadURL = URL(string: "\(serverBase)\(sessionCode)") ?? uploadURL

        // 2) Get quality level from UserDefaults or setupInfo
        if let savedQuality = defaults?.string(forKey: kQualityKey) {
            qualityLevel = savedQuality
        } else if let quality = setupInfo?["qualityLevel"] as? String {
            qualityLevel = quality
        }
        
        // Apply quality settings
        applyQualitySettings(qualityLevel)
        
        // Setup for recording
        setupRecordingWithRetry()
        
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

        // Record video sample
        recordSampleBuffer(sb)

        // Continue with the existing streaming logic
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
        
        // Finish recording
        finishRecording()
        
        // Remove broadcast start time
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
    }
    
    // MARK: - Recording Methods
    
    private func setupRecordingWithRetry(retryCount: Int = 0) {
        // Max retries to prevent infinite loops
        if retryCount > 3 {
            NSLog("Failed to set up recording after multiple attempts")
            return
        }
        
        do {
            let fileManager = FileManager.default
            guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
                NSLog("Failed to get container URL")
                return
            }
            
            let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: recordingsDir.path) {
                try fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
            }
            
            // Create unique file name based on timestamp
            let timestamp = Date().timeIntervalSince1970
            let fileName = "broadcast_\(timestamp).mp4"
            recordingURL = recordingsDir.appendingPathComponent(fileName)
            
            NSLog("Setting up recording to: \(recordingURL?.path ?? "unknown")")
            
            if let url = recordingURL {
                // Remove any existing file
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                
                // Initialize asset writer
                assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
                
                // Get the screen dimensions for proper aspect ratio
                // Since we can't access UIScreen in extension, we'll use common device dimensions
                // and adjust based on the incoming sample buffers
                
                // Default to 16:9 aspect ratio for iPhone landscape, but this will be refined
                // when we get the first sample buffer's dimensions
                let defaultWidth = 1920
                let defaultHeight = 1080
                
                // Adjust based on quality level
                var width: Int
                var height: Int
                var bitRate: Int
                var profileLevel: String
                
                switch qualityLevel {
                case "low":
                    width = 854
                    height = 480
                    bitRate = 1_500_000 // 1.5 Mbps
                    profileLevel = AVVideoProfileLevelH264BaselineAutoLevel
                case "high":
                    width = defaultWidth
                    height = defaultHeight
                    bitRate = 6_000_000 // 6 Mbps
                    profileLevel = AVVideoProfileLevelH264HighAutoLevel
                default: // medium
                    width = 1280
                    height = 720
                    bitRate = 3_000_000 // 3 Mbps
                    profileLevel = AVVideoProfileLevelH264MainAutoLevel
                }
                
                // Configure video settings based on quality
                var videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: bitRate,
                        AVVideoProfileLevelKey: profileLevel,
                        AVVideoMaxKeyFrameIntervalKey: 60, // Keyframe every 2 seconds at 30fps
                        AVVideoAllowFrameReorderingKey: false, // Reduce latency
                        AVVideoExpectedSourceFrameRateKey: 30 // Expect 30fps
                    ] as [String: Any]
                ]
                
                // Create video input
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                
                // Important: this needs to be true for real-time broadcasting
                videoInput?.expectsMediaDataInRealTime = true
                
                // Configure the transform to handle rotation
                // This will be set properly when we get the first sample buffer
                // videoInput?.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2) // For portrait
                
                if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
                    assetWriter?.add(videoInput)
                    isRecording = true
                    hasReceivedFirstSample = false
                    hasSamplesWaitingToWrite = false
                    isFinishingRecording = false
                    NSLog("Recording setup successfully with dimensions \(width)x\(height)")
                } else {
                    NSLog("Failed to add video input to asset writer")
                    // Retry with different settings
                    setupRecordingWithRetry(retryCount: retryCount + 1)
                }
            }
        } catch {
            NSLog("Failed to setup recording: \(error.localizedDescription)")
            // Retry with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupRecordingWithRetry(retryCount: retryCount + 1)
            }
        }
    }
    
    
    private func recordSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              !isFinishingRecording,
              let assetWriter = assetWriter,
              let videoInput = videoInput,
              sampleBuffer.isValid else { return }
        
        // Check if this is the first sample
        if !hasReceivedFirstSample {
            firstSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if let firstSampleTime = firstSampleTime {
                hasReceivedFirstSample = true
                
                // Start writing session with first sample time
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: firstSampleTime)
                NSLog("Started writing session at \(CMTimeGetSeconds(firstSampleTime)) seconds")
            }
        }
        
        if assetWriter.status == .writing && videoInput.isReadyForMoreMediaData {
            hasSamplesWaitingToWrite = true
            
            let appendSuccess = videoInput.append(sampleBuffer)
            if !appendSuccess {
                NSLog("Failed to append video sample buffer: \(assetWriter.status.rawValue)")
                if let error = assetWriter.error {
                    NSLog("AssetWriter error: \(error.localizedDescription)")
                }
            }
        } else if assetWriter.status == .failed {
            NSLog("AssetWriter failed: \(assetWriter.error?.localizedDescription ?? "unknown error")")
        }
    }
    
    private func finishRecording() {
        guard isRecording,
              !isFinishingRecording,
              let assetWriter = assetWriter,
              hasReceivedFirstSample,
              hasSamplesWaitingToWrite else {
            NSLog("Cannot finish recording: isRecording=\(isRecording), isFinishing=\(isFinishingRecording), hasFirstSample=\(hasReceivedFirstSample), hasSamples=\(hasSamplesWaitingToWrite)")
            
            // If we haven't received any samples, delete the empty file
            cleanupFailedRecording()
            return
        }
        
        isFinishingRecording = true
        isRecording = false
        
        // Mark inputs as finished
        videoInput?.markAsFinished()
        
        // Use a semaphore to wait for finishing to complete
        let semaphore = DispatchSemaphore(value: 0)
        
        NSLog("Finishing recording...")
        
        assetWriter.finishWriting { [weak self] in
            guard let self = self, let url = self.recordingURL else {
                semaphore.signal()
                return
            }
            
            if assetWriter.status == .completed {
                NSLog("Successfully finished writing recording to \(url.path)")
                
                // Verify file exists and has content
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        let attributes = try fileManager.attributesOfItem(atPath: url.path)
                        if let fileSize = attributes[.size] as? NSNumber {
                            NSLog("Recording file size: \(fileSize) bytes")
                            
                            if fileSize.int64Value > 10000 { // Ensure it has reasonable size
                                // Save the recording path to UserDefaults
                                UserDefaults(suiteName: self.groupID)?.set(url.path, forKey: "lastRecordingPath")
                                NSLog("Saved recording path to UserDefaults")
                            } else {
                                NSLog("Recording file is too small (\(fileSize) bytes), may be corrupt")
                                self.cleanupFailedRecording()
                            }
                        }
                    } catch {
                        NSLog("Failed to get recording file attributes: \(error.localizedDescription)")
                    }
                } else {
                    NSLog("ERROR: Recording file does not exist at \(url.path)")
                }
            } else if let error = assetWriter.error {
                NSLog("Failed to finish writing recording: \(error.localizedDescription)")
                self.cleanupFailedRecording()
            }
            
            semaphore.signal()
        }
        
        // Wait for a reasonable timeout
        _ = semaphore.wait(timeout: .now() + 5.0)
        NSLog("Finished recording process")
    }
    
    private func cleanupFailedRecording() {
        if let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
                NSLog("Removed failed recording at \(url.path)")
            } catch {
                NSLog("Failed to remove recording: \(error.localizedDescription)")
            }
        }
        
        // Make sure we don't save the path to UserDefaults
        UserDefaults(suiteName: groupID)?.removeObject(forKey: "lastRecordingPath")
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
        
        // Apply resize if needed - PRESERVE ASPECT RATIO
        let img: CIImage
        if w > threshold || h > threshold {
            // Calculate scale factor while preserving aspect ratio
            let widthScale = CGFloat(threshold) / CGFloat(w)
            let heightScale = CGFloat(threshold) / CGFloat(h)
            let scaleFactor = min(widthScale, heightScale) * downsizeFactor
            
            img = ci.transformed(by: CGAffineTransform(
                scaleX: scaleFactor,
                y: scaleFactor
            ))
        } else if downsizeFactor < 1.0 {
            // Apply downsizing evenly to preserve aspect ratio
            img = ci.transformed(by: CGAffineTransform(
                scaleX: downsizeFactor,
                y: downsizeFactor
            ))
        } else {
            img = ci
        }

        // Ensure we're getting the entire image extent
        guard let cg = ciCtx.createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: compressionQuality)
    }
}
