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
    
    // MARK: - OPTIMIZATION: Frame Batching System
    private struct FrameBatch {
        let sampleBuffer: CMSampleBuffer
        let timestamp: CFAbsoluteTime
        let sequenceNumber: Int
    }
    
    private var frameBatchQueue: [FrameBatch] = []
    private let maxBatchSize = 3 // Process 3 frames at once
    private let maxBatchAge: CFAbsoluteTime = 0.05 // 50ms max batch age
    private var batchSequenceNumber = 0
    private var frameProcessingQueue = DispatchQueue(label: "frame.processing", qos: .userInitiated)
    private var lastBatchProcessTime = CFAbsoluteTimeGetCurrent()
    
    // OPTIMIZATION: Adaptive Performance Management
    private var adaptiveFrameSkip = 1 // Dynamic frame skipping
    private var targetFPS: Double = 30.0 // Target 30 FPS for real-time
    private var actualFPS: Double = 30.0
    private var fpsHistory: [Double] = []
    private let maxFPSHistory = 10
    private var lastFPSUpdate: CFAbsoluteTime = 0
    
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
    private let ciContext = CIContext(options: [
        .workingColorSpace: NSNull(),
        .cacheIntermediates: false, // OPTIMIZATION: Disable caching for better memory
        .highQualityDownsample: false // OPTIMIZATION: Faster processing
    ])
    
    // MARK: - Performance Monitoring (OPTIMIZED)
    private var systemMonitorTimer: Timer?
    private var currentCPUUsage: Double = 0
    private var currentMemoryPressure: Double = 0
    private var settingsRefreshTimer: Timer?
    private var performanceUpdateCounter = 0 // OPTIMIZATION: Reduce monitoring frequency
    
    // MARK: - State Management
    private var frameCount = 0
    private var lastLog = Date()
    private var processed = 0
    private var dropped = 0 // OPTIMIZATION: Track dropped frames
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
    
    // MARK: - STUN Servers Configuration
    private let stunServers = [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
        "stun:stun2.l.google.com:19302",
        "stun:stun3.l.google.com:19302",
        "stun:stun4.l.google.com:19302"
    ]
    
    // MARK: - WebRTC Factory Configuration
    private func createPeerConnectionFactory() -> RTCPeerConnectionFactory {
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        
        return RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
    }
    
    private func setupSecureConfiguration() {
        // Validate the secure connection setup
        guard validateSecureConnection() else {
            NSLog("❌ Secure connection validation failed")
            return
        }
        
        NSLog("🚀 CRScreenClient configured for secure api.tormentor.dev server")
        NSLog("  🔒 Health endpoint: \(getServerHealthURL())")
        
        // Log the WebSocket URL that will be used
        let defaults = UserDefaults(suiteName: groupID)
        let preferSecure = defaults?.bool(forKey: "debug_preferSecureConnection") ?? true
        if preferSecure {
            NSLog("  📡 WebSocket: wss://api.tormentor.dev:443/ws")
        }
    }
    
    // MARK: - Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        NSLog("🚀 OPTIMIZED Broadcast session starting with frame batching")
        
        let defaults = UserDefaults(suiteName: groupID)
        
        // Initialize broadcast state
        isBroadcastActive = true
        hasEstablishedConnection = false
        connectionAttempts = 0
        frameCount = 0
        processed = 0
        dropped = 0
        lastLog = Date()
        
        // Get session code and quality settings
        sessionCode = defaults?.string(forKey: kCodeKey) ?? "0000"
        disableLocalRecording = defaults?.bool(forKey: "debug_disableLocalRecording") ?? true
        
        if let savedQuality = defaults?.string(forKey: kQualityKey) {
            qualityLevel = savedQuality
        } else if let quality = setupInfo?["qualityLevel"] as? String {
            qualityLevel = quality
        }
        
        // Load custom settings from user preferences
        loadCustomSettings()
        
        // Apply settings (custom settings override quality presets)
        applyCustomSettings()
        
        // OPTIMIZATION: Initialize adaptive performance system
        initializeAdaptiveSystem()
        
        // Mark broadcast as started
        defaults?.set(Date(), forKey: kStartedAtKey)
        
        // Setup secure configuration
        setupSecureConfiguration()
        
        // OPTIMIZATION: Less frequent system monitoring
        startSystemMonitoring(interval: 30.0) // Every 30s instead of 5s
        
        // OPTIMIZATION: Less frequent settings refresh
        startSettingsRefreshTimer(interval: 10.0) // Every 10s instead of 3s
        
        // Initialize WebRTC with proper lifecycle management
        initializeWebRTCSession()
        
        // Reset frame counters
        framesSentToServer = 0
        lastFrameSentTime = Date()
        
        NSLog("🚀 OPTIMIZED broadcast started - Session: \(sessionCode), Recording: \(disableLocalRecording ? "DISABLED" : "ENABLED"), Custom Quality: \(Int(customImageQuality * 100))%, Frame Ratio: 1:\(Int(customFrameRatio)), Bitrate: \(Int(customBitrate/1000))k")
    }
    
    // MARK: - OPTIMIZATION: Core Frame Processing with Smart Batching
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video && isBroadcastActive else { return }
        
        frameCount += 1
        
        // OPTIMIZATION: Adaptive frame skipping based on performance
        if shouldSkipFrame() {
            dropped += 1
            return
        }
        
        // OPTIMIZATION: Add frame to batch instead of processing immediately
        addFrameToBatch(sampleBuffer)
        
        // Process batch if conditions are met
        if shouldProcessBatch() {
            frameProcessingQueue.async { [weak self] in
                self?.processBatch()
            }
        }
        
        // OPTIMIZATION: Update performance metrics less frequently
        updatePerformanceMetrics()
    }
    
    // MARK: - OPTIMIZATION: Frame Batching Logic
    private func addFrameToBatch(_ sampleBuffer: CMSampleBuffer) {
        // Create frame batch entry
        let frameBatch = FrameBatch(
            sampleBuffer: sampleBuffer,
            timestamp: CFAbsoluteTimeGetCurrent(),
            sequenceNumber: batchSequenceNumber
        )
        batchSequenceNumber += 1
        
        frameBatchQueue.append(frameBatch)
        
        // OPTIMIZATION: Remove old frames to prevent memory buildup
        removeStaleFrames()
    }
    
    private func shouldProcessBatch() -> Bool {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let batchAge = currentTime - lastBatchProcessTime
        
        // Process if batch is full OR batch is getting old
        return frameBatchQueue.count >= maxBatchSize || batchAge >= maxBatchAge
    }
    
    private func processBatch() {
        guard !frameBatchQueue.isEmpty else { return }
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        lastBatchProcessTime = currentTime
        
        // OPTIMIZATION: Process only the most recent frame from batch (for real-time)
        // This maintains low latency while benefiting from batched processing setup
        let latestFrame = frameBatchQueue.last!
        
        // Clear the batch to prevent memory buildup
        frameBatchQueue.removeAll()
        
        // Process the latest frame
        processFrameForWebRTC(latestFrame.sampleBuffer)
        
        // Update FPS tracking
        updateFPSTracking()
        
        processed += 1
        
        // OPTIMIZATION: Log less frequently
        logPerformanceStats()
    }
    
    private func removeStaleFrames() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        frameBatchQueue.removeAll { frame in
            currentTime - frame.timestamp > maxBatchAge * 2 // Remove frames older than 100ms
        }
    }
    
    // MARK: - OPTIMIZATION: Adaptive Performance Management
    private func initializeAdaptiveSystem() {
        targetFPS = 30.0
        actualFPS = 30.0
        adaptiveFrameSkip = 1
        fpsHistory.removeAll()
        lastFPSUpdate = 0 // Reset FPS tracking
    }
    
    private func shouldSkipFrame() -> Bool {
        // OPTIMIZATION: Adaptive frame skipping based on performance
        if adaptiveFrameSkip <= 1 {
            return false
        }
        
        return frameCount % adaptiveFrameSkip != 0
    }
    
    private func updateFPSTracking() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        if lastFPSUpdate == 0 {
            lastFPSUpdate = currentTime
            return
        }
        
        let timeDelta = currentTime - lastFPSUpdate
        if timeDelta >= 1.0 { // Update FPS every second
            let currentFPS = Double(processed) / timeDelta
            actualFPS = currentFPS
            
            fpsHistory.append(currentFPS)
            if fpsHistory.count > maxFPSHistory {
                fpsHistory.removeFirst()
            }
            
            adjustAdaptiveFrameSkip()
            
            lastFPSUpdate = currentTime
            processed = 0 // Reset counter for next measurement
        }
    }
    
    private func adjustAdaptiveFrameSkip() {
        let avgFPS = fpsHistory.reduce(0, +) / Double(max(fpsHistory.count, 1))
        
        if avgFPS < targetFPS * 0.8 { // If FPS is below 80% of target
            adaptiveFrameSkip = min(adaptiveFrameSkip + 1, 4) // Increase skipping, max 4
        } else if avgFPS > targetFPS * 0.95 { // If FPS is above 95% of target
            adaptiveFrameSkip = max(adaptiveFrameSkip - 1, 1) // Decrease skipping, min 1
        }
    }
    
    private func updatePerformanceMetrics() {
        performanceUpdateCounter += 1
        
        // OPTIMIZATION: Update performance metrics every 60 frames instead of every frame
        if performanceUpdateCounter >= 60 {
            performanceUpdateCounter = 0
            
            // Update CPU and memory usage
            currentCPUUsage = getCurrentCPUUsage()
            currentMemoryPressure = getCurrentMemoryPressure()
            
            // Adjust frame skipping based on system load
            if currentCPUUsage > 0.8 || currentMemoryPressure > 0.9 {
                adaptiveFrameSkip = min(adaptiveFrameSkip + 1, 3)
            }
        }
    }
    
    // MARK: - Core WebRTC Frame Processing
    private func processFrameForWebRTC(_ sampleBuffer: CMSampleBuffer) {
        guard isWebRTCConnected && isBroadcastActive, let videoSource = videoSource else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Apply custom processing
        let processedPixelBuffer = applyCustomProcessing(to: pixelBuffer)
        
        let timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: processedPixelBuffer)
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: Int64(timeStampNs))
        
        // Send to WebRTC on main thread for thread safety
        DispatchQueue.main.async { [weak self] in
            videoSource.capturer(RTCVideoCapturer(), didCapture: videoFrame)
            self?.framesSentToServer += 1
            self?.lastFrameSentTime = Date()
            
            // Post notification for frame sent (throttled to avoid spam)
            if let framesSent = self?.framesSentToServer, framesSent % 10 == 0 {
                NotificationCenter.default.post(name: .frameSentToServer, object: nil)
            }
        }
    }
    
    // MARK: - OPTIMIZATION: Reduced Logging Frequency
    private func logPerformanceStats() {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastLog) > 15 { // Log every 15s instead of 10s
            let fps = Double(processed) / currentTime.timeIntervalSince(lastLog)
            let effectiveFPS = fps / customFrameRatio
            let dropRate = Double(dropped) / Double(frameCount) * 100
            
            NSLog("📊 OPTIMIZED Stats: %.1f FPS (target: %.1f), Effective: %.1f, Drop Rate: %.1f%%, Skip: %d, WebRTC: %@, Sent: %d",
                  fps, targetFPS, effectiveFPS, dropRate, adaptiveFrameSkip,
                  isWebRTCConnected ? "✅" : "❌", framesSentToServer)
            
            lastLog = currentTime
            processed = 0
            dropped = 0
        }
    }
    
    private func validateSecureConnection() -> Bool {
        let healthURL = getServerHealthURL()
        
        // Ensure we're using HTTPS for the health check
        if !healthURL.hasPrefix("https://") {
            NSLog("⚠️ Warning: Health check URL is not secure: \(healthURL)")
            return false
        }
        
        // Ensure we're connecting to the right server
        if !healthURL.contains("api.tormentor.dev") {
            NSLog("ℹ️ Using custom server: \(healthURL)")
        }
        
        NSLog("🔒 Secure connection validated: \(healthURL)")
        return true
    }
    
    private func getServerHealthURL() -> String {
        let defaults = UserDefaults(suiteName: groupID)
        let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
        let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
        let preferSecure = defaults?.bool(forKey: "debug_preferSecureConnection") ?? true
        
        if useCustomServer && !customServerURL.isEmpty {
            var baseURL = customServerURL
            
            // Remove ws:// or wss:// prefix if present
            if baseURL.hasPrefix("ws://") {
                baseURL = String(baseURL.dropFirst(5))
            } else if baseURL.hasPrefix("wss://") {
                baseURL = String(baseURL.dropFirst(6))
            }
            
            // Add appropriate HTTP protocol based on preference
            if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                baseURL = preferSecure ? "https://" + baseURL : "http://" + baseURL
            }
            
            // Remove trailing /ws if present
            if baseURL.hasSuffix("/ws") {
                baseURL = String(baseURL.dropLast(3))
            }
            
            return "\(baseURL)/health"
        }
        
        // Updated default to use your secure api.tormentor.dev server
        return "https://api.tormentor.dev:443/health"
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
        
        // Apply custom image quality
        compressionQuality = CGFloat(customImageQuality)
        
        // Apply custom resolution scaling
        downsizeFactor = CGFloat(customResolutionScale)
        
        // Calculate threshold based on resolution scale
        threshold = Int(1920 * customResolutionScale) // Base 1920 width scaled down
        
        NSLog("🎛️ Applied custom settings - FrameSkip: \(frameSkip), Quality: \(compressionQuality), Scale: \(downsizeFactor), Threshold: \(threshold)")
    }
    
    // OPTIMIZATION: Less frequent settings refresh
    private func startSettingsRefreshTimer(interval: TimeInterval) {
        settingsRefreshTimer?.invalidate()
        settingsRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
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
        NSLog("📡 Initializing OPTIMIZED WebRTC session (attempt \(connectionAttempts + 1))")
        
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
        
        NSLog("📡 OPTIMIZED WebRTC components initialized - connecting to: \(signalingURL.absoluteString)")
        
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
        
        NSLog("🔄 Retrying OPTIMIZED WebRTC connection")
        cleanupWebRTCComponents()
        
        let delay = min(Double(connectionAttempts) * 2.0, 10.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isBroadcastActive else { return }
            self.initializeWebRTCSession()
        }
    }
    
    private func getSignalingURL() -> URL {
        // Get the WebSocket URL for your secure server
        let defaults = UserDefaults(suiteName: groupID)
        let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
        let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
        let preferSecure = defaults?.bool(forKey: "debug_preferSecureConnection") ?? true
        
        let baseURL: String
        
        if useCustomServer && !customServerURL.isEmpty {
            var customURL = customServerURL
            
            // Remove HTTP protocols if present
            if customURL.hasPrefix("http://") {
                customURL = String(customURL.dropFirst(7))
            } else if customURL.hasPrefix("https://") {
                customURL = String(customURL.dropFirst(8))
            }
            
            // Add WebSocket protocol
            let protocol_url = preferSecure ? "wss://" : "ws://"
            customURL = protocol_url + customURL
            
            // Ensure it ends with /ws
            if !customURL.hasSuffix("/ws") {
                customURL += "/ws"
            }
            
            baseURL = customURL
        } else {
            // Default to your secure server
            baseURL = "wss://api.tormentor.dev:443/ws"
        }
        
        let fullURL = "\(baseURL)/\(sessionCode)"
        
        NSLog("🔗 OPTIMIZED Signaling URL: \(fullURL)")
        return URL(string: fullURL)!
    }
    
    private func createPeerConnection() {
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, skipping peer connection creation")
            return
        }
        
        let config = RTCConfiguration()
        config.iceServers = stunServers.map { RTCIceServer(urlStrings: [$0]) }
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
        
        NSLog("📞 OPTIMIZED Peer connection created with custom bitrate: \(Int(customBitrate/1000))k")
    }
    
    // MARK: - System Resource Monitoring (OPTIMIZED)
    private func startSystemMonitoring(interval: TimeInterval) {
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
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
            adaptiveFrameSkip = min(customFrameSkipBase + 2, 5)
            NSLog("⚠️ High system load - adaptive frame skip: \(adaptiveFrameSkip)")
        } else if currentCPUUsage < 40 && currentMemoryPressure < 0.5 {
            let customFrameSkipBase = max(1, Int(customFrameRatio) - 1)
            adaptiveFrameSkip = max(customFrameSkipBase, 1)
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
        NSLog("🛑 OPTIMIZED Broadcast session ending")
        
        isBroadcastActive = false
        
        // Stop all timers
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        settingsRefreshTimer?.invalidate()
        settingsRefreshTimer = nil
        
        // Clear frame batch queue
        frameBatchQueue.removeAll()
        
        NSLog("📊 Final OPTIMIZED stats: %d frames sent, %d dropped, %.1f%% drop rate",
              framesSentToServer, dropped, Double(dropped) / Double(frameCount) * 100)
        
        cleanupWebRTCComponents()
        
        // Clear broadcast started timestamp
        if let defaults = UserDefaults(suiteName: groupID) {
            defaults.removeObject(forKey: kStartedAtKey)
            NSLog("✅ OPTIMIZED broadcast cleanup completed")
        }
    }
    
    private func cleanupWebRTCComponents() {
        NSLog("🧹 Cleaning up OPTIMIZED WebRTC components")
        
        peerConnection?.close()
        peerConnection = nil
        
        signalingClient?.disconnect()
        signalingClient = nil
        
        isWebRTCConnected = false
        isSignalingConnected = false
        
        videoTrack = nil
        videoSource = nil
        
        NSLog("🧹 OPTIMIZED WebRTC cleanup completed")
    }
}

// MARK: - RTCPeerConnectionDelegate
extension SampleHandler: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        NSLog("🔄 OPTIMIZED Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        NSLog("📡 OPTIMIZED Stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        NSLog("📡 OPTIMIZED Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        NSLog("🤝 OPTIMIZED Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("🧊 OPTIMIZED ICE connection state: \(newState.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            switch newState {
            case .connected, .completed:
                if let self = self, !self.hasEstablishedConnection {
                    self.hasEstablishedConnection = true
                    self.isWebRTCConnected = true
                    self.connectionAttempts = 0
                    NSLog("✅ OPTIMIZED WebRTC connection established - Frame ratio: 1:\(Int(self.customFrameRatio)), Quality: \(Int(self.customImageQuality * 100))%%")
                }
            case .checking:
                NSLog("🔍 OPTIMIZED ICE connection checking...")
            case .disconnected:
                self?.isWebRTCConnected = false
                NSLog("⚠️ OPTIMIZED WebRTC connection lost")
                
                if let self = self, self.isBroadcastActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        guard self.isBroadcastActive else { return }
                        self.attemptReconnection()
                    }
                }
            case .failed:
                self?.isWebRTCConnected = false
                NSLog("❌ OPTIMIZED WebRTC connection failed")
                
                if let self = self, self.isBroadcastActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        guard self.isBroadcastActive else { return }
                        self.retryConnection()
                    }
                }
            case .closed:
                self?.isWebRTCConnected = false
                NSLog("🔒 OPTIMIZED WebRTC connection closed")
            default:
                break
            }
        }
    }
    
    private func attemptReconnection() {
        guard isBroadcastActive && connectionAttempts < maxConnectionAttempts else {
            NSLog("❌ Cannot reconnect - broadcast inactive or max attempts reached")
            return
        }
        
        if !isWebRTCConnected {
            NSLog("🔄 Attempting OPTIMIZED WebRTC reconnection...")
            signalingClient?.connect()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        NSLog("🔄 OPTIMIZED ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        signalingClient?.send(iceCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        NSLog("🗑️ OPTIMIZED Removed ICE candidates")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        NSLog("📊 OPTIMIZED Data channel opened")
    }
}

// MARK: - RTCDataChannelDelegate
extension SampleHandler: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        NSLog("📊 OPTIMIZED Data channel state changed: \(dataChannel.readyState.rawValue)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        NSLog("📨 OPTIMIZED Received data channel message")
    }
}

// MARK: - SignalingClientDelegate
extension SampleHandler: SignalingClientDelegate {
    func signalingClient(_ client: SignalingClient, didRequestOfferForViewer viewerId: String) {
        NSLog("📨 OPTIMIZED Received request to create offer for viewer: \(viewerId)")
        
        guard isBroadcastActive, let peerConnection = peerConnection else {
            NSLog("❌ Cannot create offer - broadcast inactive or peer connection nil")
            return
        }
        
        // Create offer for specific viewer
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )
        
        peerConnection.offer(for: constraints) { [weak self] offer, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("❌ Failed to create offer for viewer \(viewerId): \(error.localizedDescription)")
                return
            }
            
            guard let offer = offer else {
                NSLog("❌ Offer is nil for viewer \(viewerId)")
                return
            }
            
            // Set local description
            self.peerConnection?.setLocalDescription(offer) { error in
                if let error = error {
                    NSLog("❌ Failed to set local description for viewer \(viewerId): \(error.localizedDescription)")
                    return
                }
                
                NSLog("✅ OPTIMIZED Created and set offer for viewer \(viewerId)")
                
                // Send targeted offer to specific viewer
                self.signalingClient?.sendOffer(offer, targetViewerId: viewerId)
            }
        }
    }
    
    func signalingClientDidConnect(_ signalingClient: SignalingClient) {
        NSLog("📡 OPTIMIZED Signaling connected to secure server")
        
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
                    NSLog("✅ OPTIMIZED Local description set - sending offer to secure server")
                    self.signalingClient?.send(sessionDescription: sessionDescription)
                }
            }
        }
    }
    
    func signalingClientDidDisconnect(_ signalingClient: SignalingClient) {
        NSLog("📡❌ OPTIMIZED Signaling disconnected from secure server")
        isSignalingConnected = false
        
        if isBroadcastActive && connectionAttempts < maxConnectionAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self, self.isBroadcastActive else { return }
                self.attemptReconnection()
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveSessionDescription sessionDescription: RTCSessionDescription) {
        NSLog("📡 OPTIMIZED Received session description: \(sessionDescription.type.rawValue)")
        
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, ignoring session description")
            return
        }
        
        peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            if let error = error {
                NSLog("❌ Failed to set remote description: \(error.localizedDescription)")
            } else {
                NSLog("✅ OPTIMIZED Remote description set successfully")
                
                if sessionDescription.type == .answer {
                    NSLog("📡 OPTIMIZED Answer received - WebRTC negotiation complete")
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
        NSLog("📡❌ OPTIMIZED Signaling error: \(error.localizedDescription)")
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
