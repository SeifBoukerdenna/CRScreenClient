import ReplayKit
import UIKit
import CoreImage
import AVFoundation
import WebRTC

class SampleHandler: RPBroadcastSampleHandler {
    // MARK: - WebRTC Components
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var videoSource: RTCVideoSource?
    private var videoTrack: RTCVideoTrack?
    private var signalingClient: SignalingClient?
    
    // MARK: - Configuration
    private var sessionCode = "0000"
    private var qualityLevel = "medium"
    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    private let kCodeKey = "sessionCode"
    private let kQualityKey = "streamQuality"
    
    // MARK: - Custom Settings from User Interface
    private var customFrameRatio: Double = 1.0
    private var customImageQuality: Double = 0.6
    private var customBitrate: Double = 800000
    private var customResolutionScale: Double = 0.8
    
    // MARK: - Video Processing Variables
    private var compressionQuality: CGFloat = 0.5
    private var frameSkip = 2
    private var downsizeFactor: CGFloat = 0.7
    private var threshold: Int = 1080
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    
    // MARK: - Dynamic Performance Management
    private var dynamicFrameSkip = 2
    private var lastProcessTime = Date()
    private let maxProcessingInterval: TimeInterval = 0.033
    private var systemMonitorTimer: Timer?
    private var currentCPUUsage: Double = 0
    private var currentMemoryPressure: Double = 0
    private var settingsRefreshTimer: Timer?
    
    // MARK: - State Management
    private var frameCount = 0
    private var lastLog = Date()
    private var processed = 0
    private var isWebRTCConnected = false
    private var isSignalingConnected = false
    private var hasEstablishedConnection = false
    private var isBroadcastActive = true
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 5
    
    // MARK: - Local Recording
    private var disableLocalRecording = false
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private var recordingURL: URL?
    
    // MARK: - Server Connection Monitoring
    private var framesSentToServer = 0
    private var lastFrameSentTime = Date()
    private var serverPingTimer: Timer?
    private var lastServerPingTime = Date()
    
    // MARK: - WebRTC Factory Configuration
    private func createPeerConnectionFactory() -> RTCPeerConnectionFactory {
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        
        return RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
    }
    
    // MARK: - Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        NSLog("🚀 Broadcast session starting")
        
        let defaults = UserDefaults(suiteName: groupID)
        
        // Initialize broadcast state
        isBroadcastActive = true
        hasEstablishedConnection = false
        connectionAttempts = 0
        
        // Get session code and quality settings
        sessionCode = defaults?.string(forKey: kCodeKey) ?? "0000"
        disableLocalRecording = defaults?.bool(forKey: "debug_disableLocalRecording") ?? false
        
        if let savedQuality = defaults?.string(forKey: kQualityKey) {
            qualityLevel = savedQuality
        } else if let quality = setupInfo?["qualityLevel"] as? String {
            qualityLevel = quality
        }
        
        // Load custom settings from user preferences
        loadCustomSettings()
        
        // Apply settings (custom settings override quality presets)
        applyCustomSettings()
        
        // Mark broadcast as started
        defaults?.set(Date(), forKey: kStartedAtKey)
        
        // Start system resource monitoring
        startSystemMonitoring()
        
        // Start settings refresh timer to pick up real-time changes
        startSettingsRefreshTimer()
        
        // Start server ping monitoring
        startServerPingMonitoring()
        
        // Initialize WebRTC with proper lifecycle management
        initializeWebRTCSession()
        
        // Setup local recording if enabled
        if !disableLocalRecording {
            setupLocalRecording()
        }
        
        // Reset frame counters
        framesSentToServer = 0
        lastFrameSentTime = Date()
        
        NSLog("🚀 Broadcast started - Session: \(sessionCode), Custom Quality: \(Int(customImageQuality * 100))%, Frame Ratio: 1:\(Int(customFrameRatio)), Bitrate: \(Int(customBitrate/1000))k")
    }
    
    // MARK: - Server Connection Monitoring
    
    private func startServerPingMonitoring() {
        serverPingTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isBroadcastActive else { return }
            self.pingServer()
        }
        
        // Perform initial ping after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.pingServer()
        }
    }
    
    private func pingServer() {
        let serverURL = getServerHealthURL()
        
        guard let url = URL(string: serverURL) else {
            NSLog("❌ Invalid server URL: \(serverURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            let currentTime = Date()
            let timeSinceLastPing = currentTime.timeIntervalSince(self.lastServerPingTime)
            self.lastServerPingTime = currentTime
            
            if let error = error {
                NSLog("❌ Server ping failed after \(String(format: "%.1f", timeSinceLastPing))s: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    NSLog("✅ Server ping successful (\(String(format: "%.1f", timeSinceLastPing))s)")
                    
                    // Post notification that server is reachable
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .frameAcknowledgedByServer, object: nil)
                    }
                    
                    // Try to parse server info
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let sessions = json["active_sessions"] as? Int ?? 0
                        let broadcasters = json["total_broadcasters"] as? Int ?? 0
                        let viewers = json["total_viewers"] as? Int ?? 0
                        
                        if sessions > 0 || broadcasters > 0 {
                            NSLog("📊 Server status: \(sessions) sessions, \(broadcasters) broadcasters, \(viewers) viewers")
                        }
                    }
                } else {
                    NSLog("⚠️ Server ping returned HTTP \(httpResponse.statusCode)")
                }
            }
        }
        
        task.resume()
    }
    
    private func getServerHealthURL() -> String {
        let defaults = UserDefaults(suiteName: groupID)
        let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
        let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
        
        if useCustomServer && !customServerURL.isEmpty {
            var baseURL = customServerURL
            
            // Remove ws:// or wss:// prefix if present
            if baseURL.hasPrefix("ws://") {
                baseURL = String(baseURL.dropFirst(5))
            } else if baseURL.hasPrefix("wss://") {
                baseURL = String(baseURL.dropFirst(6))
            }
            
            // Add http:// prefix
            if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                baseURL = "http://" + baseURL
            }
            
            // Remove trailing /ws if present
            if baseURL.hasSuffix("/ws") {
                baseURL = String(baseURL.dropLast(3))
            }
            
            return "\(baseURL)/health"
        }
        
        // Default server
        return "http://34.56.170.86:8080/health"
    }
    
    // MARK: - Custom Settings Management
    
    private func loadCustomSettings() {
        let defaults = UserDefaults(suiteName: groupID)
        
        // Load custom settings with fallbacks
        customFrameRatio = defaults?.double(forKey: "customFrameRatio") ?? 1.0
        customImageQuality = defaults?.double(forKey: "customImageQuality") ?? 0.6
        customBitrate = defaults?.double(forKey: "customBitrate") ?? 800000
        customResolutionScale = defaults?.double(forKey: "customResolutionScale") ?? 0.8
        
        // Ensure values are within valid ranges
        customFrameRatio = max(1.0, min(5.0, customFrameRatio))
        customImageQuality = max(0.1, min(1.0, customImageQuality))
        customBitrate = max(200000, min(2000000, customBitrate))
        customResolutionScale = max(0.3, min(1.0, customResolutionScale))
        
        NSLog("📋 Loaded custom settings - Frame: 1:\(Int(customFrameRatio)), Quality: \(Int(customImageQuality * 100))%, Bitrate: \(Int(customBitrate/1000))k, Resolution: \(Int(customResolutionScale * 100))%")
    }
    
    private func applyCustomSettings() {
        // Apply custom frame ratio
        frameSkip = max(1, Int(customFrameRatio) - 1)
        dynamicFrameSkip = frameSkip
        
        // Apply custom image quality
        compressionQuality = CGFloat(customImageQuality)
        
        // Apply custom resolution scaling
        downsizeFactor = CGFloat(customResolutionScale)
        
        // Calculate threshold based on resolution scale
        threshold = Int(1920 * customResolutionScale) // Base 1920 width scaled down
        
        NSLog("🎛️ Applied custom settings - FrameSkip: \(frameSkip), Quality: \(compressionQuality), Scale: \(downsizeFactor), Threshold: \(threshold)")
    }
    
    private func startSettingsRefreshTimer() {
        // Refresh settings every 3 seconds to pick up real-time changes
        settingsRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isBroadcastActive else { return }
            
            let oldFrameRatio = self.customFrameRatio
            let oldImageQuality = self.customImageQuality
            let oldBitrate = self.customBitrate
            let oldResolutionScale = self.customResolutionScale
            
            self.loadCustomSettings()
            
            // Check if any settings changed
            if oldFrameRatio != self.customFrameRatio ||
               oldImageQuality != self.customImageQuality ||
               oldBitrate != self.customBitrate ||
               oldResolutionScale != self.customResolutionScale {
                
                NSLog("🔄 Settings changed - updating stream parameters")
                self.applyCustomSettings()
            }
        }
    }
    
    // MARK: - WebRTC Initialization
    private func initializeWebRTCSession() {
        NSLog("📡 Initializing WebRTC session (attempt \(connectionAttempts + 1))")
        
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast no longer active, skipping WebRTC initialization")
            return
        }
        
        connectionAttempts += 1
        
        if connectionAttempts > maxConnectionAttempts {
            NSLog("❌ Max WebRTC connection attempts reached - continuing with local recording only")
            return
        }
        
        setupWebRTC()
    }
    
    private func setupWebRTC() {
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, aborting WebRTC setup")
            return
        }
        
        peerConnectionFactory = createPeerConnectionFactory()
        videoSource = peerConnectionFactory.videoSource()
        videoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "video_track_\(sessionCode)")
        
        let signalingURL = getSignalingURL()
        signalingClient = SignalingClient(url: signalingURL, sessionCode: sessionCode)
        signalingClient?.delegate = self
        signalingClient?.connect()
        
        NSLog("📡 WebRTC components initialized with custom settings - connecting to: \(signalingURL.absoluteString)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, self.isBroadcastActive else { return }
            
            if !self.isWebRTCConnected && !self.hasEstablishedConnection {
                NSLog("⚠️ WebRTC connection timeout - attempting retry")
                self.retryConnection()
            }
        }
    }
    
    private func retryConnection() {
        guard isBroadcastActive && connectionAttempts < maxConnectionAttempts else {
            NSLog("❌ Cannot retry - broadcast inactive or max attempts reached")
            return
        }
        
        NSLog("🔄 Retrying WebRTC connection")
        cleanupWebRTCComponents()
        
        let delay = min(Double(connectionAttempts) * 2.0, 10.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isBroadcastActive else { return }
            self.initializeWebRTCSession()
        }
    }
    
    private func getSignalingURL() -> URL {
        // Use the dynamic URL from Constants which checks debug settings
        let baseURL = Constants.URLs.webRTCSignalingServer
        let fullURL = "\(baseURL)/\(sessionCode)"
        
        if Constants.FeatureFlags.enableDebugLogging {
            let defaults = UserDefaults(suiteName: groupID)
            let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
            let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
            
            print("SampleHandler: WebRTC signaling URL: \(fullURL)")
            print("SampleHandler: Custom server enabled: \(useCustomServer)")
            print("SampleHandler: Custom URL: \(customServerURL)")
        }
        
        return URL(string: fullURL)!
    }
    
    private func createPeerConnection() {
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, skipping peer connection creation")
            return
        }
        
        let config = RTCConfiguration()
        config.iceServers = Constants.URLs.stunServers.map { RTCIceServer(urlStrings: [$0]) }
        config.bundlePolicy = .balanced
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .disabled
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
        
        if let videoTrack = videoTrack {
            peerConnection?.add(videoTrack, streamIds: ["broadcast_stream"])
        }
        
        NSLog("📞 Peer connection created with custom bitrate: \(Int(customBitrate/1000))k")
    }
    
    // MARK: - System Resource Monitoring
    private func startSystemMonitoring() {
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isBroadcastActive else { return }
            self.checkSystemResources()
        }
    }
    
    private func checkSystemResources() {
        currentCPUUsage = getCurrentCPUUsage()
        currentMemoryPressure = getCurrentMemoryPressure()
        
        // More conservative dynamic adjustments with custom settings as base
        if currentCPUUsage > 70 || currentMemoryPressure > 0.8 {
            let customFrameSkipBase = max(1, Int(customFrameRatio) - 1)
            dynamicFrameSkip = min(customFrameSkipBase + 2, 5)
            NSLog("⚠️ High system load - dynamic frame skip: \(dynamicFrameSkip) (base: \(customFrameSkipBase))")
        } else if currentCPUUsage < 40 && currentMemoryPressure < 0.5 {
            let customFrameSkipBase = max(1, Int(customFrameRatio) - 1)
            dynamicFrameSkip = max(customFrameSkipBase, 1)
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024 * 100)
        }
        return 0
    }
    
    private func getCurrentMemoryPressure() -> Double {
        let pageSize = vm_page_size
        var vmInfo = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let kerr = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &infoCount)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalPages = vmInfo.free_count + vmInfo.active_count + vmInfo.inactive_count + vmInfo.wire_count
            let usedPages = totalPages - vmInfo.free_count
            return Double(usedPages) / Double(totalPages)
        }
        return 0
    }
    
    // MARK: - Enhanced Frame Processing with Custom Settings
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video && isBroadcastActive else { return }
        
        frameCount += 1
        
        // Process for local recording if enabled
        if !disableLocalRecording {
            processForLocalRecording(sampleBuffer)
        }
        
        // Apply custom frame ratio with dynamic adjustments
        let effectiveFrameSkip = max(frameSkip, dynamicFrameSkip)
        if frameCount % (Int(customFrameRatio)) != 0 { return }
        
        let now = Date()
        lastProcessTime = now
        
        // Send via WebRTC if connected with custom processing
        if isWebRTCConnected && isBroadcastActive, let videoSource = videoSource {
            sendFrameViaWebRTC(sampleBuffer: sampleBuffer, videoSource: videoSource)
        }
        
        processed += 1
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastLog) > 10 {
            let fps = Double(processed) / currentTime.timeIntervalSince(lastLog)
            let effectiveFPS = fps / customFrameRatio // Account for frame ratio
            
            NSLog("📊 Custom Stats: %.1f FPS (effective: %.1f), Quality: \(Int(customImageQuality * 100))%%, Ratio: 1:\(Int(customFrameRatio)), Scale: \(Int(customResolutionScale * 100))%%, WebRTC: %@, Frames Sent: \(framesSentToServer)",
                  fps, effectiveFPS,
                  isWebRTCConnected ? "✅" : "❌")
            processed = 0
            lastLog = currentTime
        }
    }
    
    private func sendFrameViaWebRTC(sampleBuffer: CMSampleBuffer, videoSource: RTCVideoSource) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Apply custom resolution scaling if needed
        let processedPixelBuffer = applyCustomProcessing(to: pixelBuffer)
        
        let timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: processedPixelBuffer)
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: Int64(timeStampNs))
        
        videoSource.capturer(RTCVideoCapturer(), didCapture: videoFrame)
        
        // Track frame sent
        framesSentToServer += 1
        lastFrameSentTime = Date()
        
        // Post notification for frame sent (throttled to avoid spam)
        if framesSentToServer % 10 == 0 { // Only notify every 10th frame
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .frameSentToServer, object: nil)
            }
        }
        
        if framesSentToServer % 100 == 0 {
            NSLog("📊 Sent \(framesSentToServer) frames to WebRTC")
        }
    }
    
    private func applyCustomProcessing(to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        // If resolution scale is 1.0, return original buffer
        guard customResolutionScale < 0.95 else { return pixelBuffer }
        
        let originalWidth = CVPixelBufferGetWidth(pixelBuffer)
        let originalHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let scaledWidth = Int(Double(originalWidth) * customResolutionScale)
        let scaledHeight = Int(Double(originalHeight) * customResolutionScale)
        
        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply scaling
        let scaleTransform = CGAffineTransform(scaleX: customResolutionScale, y: customResolutionScale)
        let scaledImage = ciImage.transformed(by: scaleTransform)
        
        // Create output pixel buffer
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferWidthKey: scaledWidth,
            kCVPixelBufferHeightKey: scaledHeight
        ] as CFDictionary
        
        var outputPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            scaledWidth,
            scaledHeight,
            kCVPixelFormatType_32BGRA,
            attrs,
            &outputPixelBuffer
        )
        
        guard status == kCVReturnSuccess, let outputBuffer = outputPixelBuffer else {
            return pixelBuffer // Return original if scaling fails
        }
        
        // Render scaled image to output buffer
        ciContext.render(scaledImage, to: outputBuffer)
        
        return outputBuffer
    }
    
    override func broadcastFinished() {
        NSLog("🛑 Broadcast session ending")
        
        isBroadcastActive = false
        
        // Stop all timers
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        settingsRefreshTimer?.invalidate()
        settingsRefreshTimer = nil
        serverPingTimer?.invalidate()
        serverPingTimer = nil
        
        // Log final frame count
        NSLog("📊 Final frame count: \(framesSentToServer) frames sent to server")
        
        cleanupWebRTCComponents()
        
        if !disableLocalRecording {
            finalizeRecording { success in
                NSLog("📹 Recording finalization: \(success ? "✅" : "❌")")
            }
        }
        
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
        NSLog("🛑 Broadcast session cleanup completed")
    }
    
    private func cleanupWebRTCComponents() {
        NSLog("🧹 Cleaning up WebRTC components")
        
        peerConnection?.close()
        peerConnection = nil
        
        signalingClient?.disconnect()
        signalingClient = nil
        
        isWebRTCConnected = false
        isSignalingConnected = false
        
        videoTrack = nil
        videoSource = nil
        
        NSLog("🧹 WebRTC cleanup completed")
    }
    
    // MARK: - Local Recording Methods
    private func setupLocalRecording() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            NSLog("Failed to get app group container URL")
            return
        }
        
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "broadcast_\(timestamp).mp4"
        recordingURL = recordingsDir.appendingPathComponent(filename)
        
        NSLog("Recording setup complete. Will save to: %@", recordingURL?.path ?? "unknown")
    }
    
    private func processForLocalRecording(_ sampleBuffer: CMSampleBuffer) {
        guard let recordingURL = recordingURL else { return }
        
        if assetWriter == nil {
            do {
                assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: .mp4)
                
                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                    NSLog("Failed to get format description")
                    return
                }
                
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                
                // Use custom bitrate in recording settings
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: Int(customBitrate),
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoMaxKeyFrameIntervalKey: 30,
                        AVVideoQualityKey: customImageQuality
                    ]
                ]
                
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput?.expectsMediaDataInRealTime = true
                
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
                
                let success = assetWriter!.startWriting()
                if !success {
                    NSLog("Failed to start writing: %@", assetWriter!.error?.localizedDescription ?? "Unknown error")
                    assetWriter = nil
                    return
                }
                
                assetWriter!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                recordingStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                NSLog("Started recording with custom settings - Bitrate: \(Int(customBitrate/1000))k, Quality: \(Int(customImageQuality * 100))%%")
            } catch {
                NSLog("Failed to create asset writer: %@", error.localizedDescription)
                return
            }
        }
        
        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData,
              let recordingStartTime = recordingStartTime else {
            return
        }
        
        videoInput.append(sampleBuffer)
    }
    
    private func finalizeRecording(completion: @escaping (Bool) -> Void) {
        guard let assetWriter = assetWriter else {
            completion(false)
            return
        }
        
        videoInput?.markAsFinished()
        
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
}

// MARK: - RTCPeerConnectionDelegate
extension SampleHandler: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        NSLog("Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        NSLog("Stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        NSLog("Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        NSLog("Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("📡 ICE connection state: \(newState.rawValue)")
        
        switch newState {
        case .connected, .completed:
            if !hasEstablishedConnection {
                hasEstablishedConnection = true
                isWebRTCConnected = true
                connectionAttempts = 0
                NSLog("✅ WebRTC connection established with custom settings - Frame ratio: 1:\(Int(customFrameRatio)), Quality: \(Int(customImageQuality * 100))%%")
            }
        case .checking:
            NSLog("🔍 ICE connection checking...")
        case .disconnected:
            isWebRTCConnected = false
            NSLog("⚠️ WebRTC connection lost")
            
            if isBroadcastActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, self.isBroadcastActive else { return }
                    self.attemptReconnection()
                }
            }
        case .failed:
            isWebRTCConnected = false
            NSLog("❌ WebRTC connection failed")
            
            if isBroadcastActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    guard let self = self, self.isBroadcastActive else { return }
                    self.retryConnection()
                }
            }
        case .closed:
            isWebRTCConnected = false
            NSLog("🔒 WebRTC connection closed")
        default:
            break
        }
    }
    
    private func attemptReconnection() {
        guard isBroadcastActive && connectionAttempts < maxConnectionAttempts else {
            NSLog("❌ Cannot reconnect - broadcast inactive or max attempts reached")
            return
        }
        
        if !isWebRTCConnected {
            NSLog("🔄 Attempting WebRTC reconnection...")
            signalingClient?.connect()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        NSLog("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        signalingClient?.send(iceCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        NSLog("Removed ICE candidates")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        NSLog("Data channel opened")
    }
}

// MARK: - RTCDataChannelDelegate
extension SampleHandler: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        NSLog("Data channel state changed: \(dataChannel.readyState.rawValue)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        NSLog("Received data channel message")
    }
}

// MARK: - SignalingClientDelegate
extension SampleHandler: SignalingClientDelegate {
    func signalingClientDidConnect(_ signalingClient: SignalingClient) {
        NSLog("📡 Signaling connected - creating peer connection with custom settings")
        
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, ignoring signaling connection")
            return
        }
        
        isSignalingConnected = true
        createPeerConnection()
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sessionDescription, error in
            guard let self = self, let sessionDescription = sessionDescription, self.isBroadcastActive else {
                NSLog("❌ Failed to create offer or broadcast inactive: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.peerConnection?.setLocalDescription(sessionDescription) { error in
                if let error = error {
                    NSLog("❌ Failed to set local description: \(error.localizedDescription)")
                } else {
                    NSLog("✅ Local description set with custom settings - sending offer")
                    self.signalingClient?.send(sessionDescription: sessionDescription)
                }
            }
        }
    }
    
    func signalingClientDidDisconnect(_ signalingClient: SignalingClient) {
        NSLog("📡❌ Signaling disconnected")
        isSignalingConnected = false
        
        if isBroadcastActive && connectionAttempts < maxConnectionAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self, self.isBroadcastActive else { return }
                self.attemptReconnection()
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveSessionDescription sessionDescription: RTCSessionDescription) {
        NSLog("📡 Received session description: \(sessionDescription.type.rawValue)")
        
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, ignoring session description")
            return
        }
        
        peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            if let error = error {
                NSLog("❌ Failed to set remote description: \(error.localizedDescription)")
            } else {
                NSLog("✅ Remote description set successfully")
                
                if sessionDescription.type == .answer {
                    NSLog("📡 Answer received - WebRTC negotiation complete with custom settings")
                }
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, ignoring ICE candidate")
            return
        }
        
        peerConnection?.add(candidate) { error in
            if let error = error {
                NSLog("❌ Failed to add ICE candidate: \(error.localizedDescription)")
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveError error: Error) {
        NSLog("📡❌ Signaling error: \(error.localizedDescription)")
        isSignalingConnected = false
        
        if isBroadcastActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, self.isBroadcastActive else { return }
                self.retryConnection()
            }
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let frameSentToServer = Notification.Name("frameSentToServer")
    static let frameAcknowledgedByServer = Notification.Name("frameAcknowledgedByServer")
}
