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
    
    // MARK: - Video Processing with Conservative Defaults
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
    
    // MARK: - State Management with Proper Lifecycle Control
    private var frameCount = 0
    private var lastLog = Date()
    private var processed = 0
    private var isWebRTCConnected = false
    private var isSignalingConnected = false
    private var hasEstablishedConnection = false
    private var isBroadcastActive = true
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 5
    
    // MARK: - Adaptive Connection Management
    private var currentBitrate = 800_000
    private var connectionQualityScore = 1.0
    private var lastConnectionCheck = Date()
    
    // MARK: - Local Recording
    private var disableLocalRecording = false
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    private var recordingURL: URL?
    
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
        
        // Apply conservative settings for stability
        if qualityLevel == "high" {
            qualityLevel = "medium"
            NSLog("🛡️ Overriding high quality to medium for stability")
        }
        
        applyQualitySettings(qualityLevel)
        dynamicFrameSkip = max(frameSkip, 2)
        
        // Mark broadcast as started
        defaults?.set(Date(), forKey: kStartedAtKey)
        
        // Start system resource monitoring
        startSystemMonitoring()
        
        // Initialize WebRTC with proper lifecycle management
        initializeWebRTCSession()
        
        // Setup local recording if enabled
        if !disableLocalRecording {
            setupLocalRecording()
        }
        
        NSLog("🚀 Broadcast started - Session: \(sessionCode), Quality: \(qualityLevel), Active: \(isBroadcastActive)")
    }
    
    // MARK: - Proper WebRTC Initialization
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
        
        // Initialize peer connection factory
        peerConnectionFactory = createPeerConnectionFactory()
        
        // Create video source
        videoSource = peerConnectionFactory.videoSource()
        
        // Create video track
        videoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "video_track_\(sessionCode)")
        
        // Setup signaling client with proper lifecycle management
        let signalingURL = getSignalingURL()
        signalingClient = SignalingClient(url: signalingURL, sessionCode: sessionCode)
        signalingClient?.delegate = self
        
        // Connect to signaling server
        signalingClient?.connect()
        
        NSLog("📡 WebRTC components initialized - Signaling: \(signalingURL)")
        
        // Set connection timeout with proper state checking
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
        
        // Clean up current connection without terminating broadcast
        cleanupWebRTCComponents()
        
        // Retry after delay
        let delay = min(Double(connectionAttempts) * 2.0, 10.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isBroadcastActive else { return }
            self.initializeWebRTCSession()
        }
    }
    
    private func getSignalingURL() -> URL {
        let defaults = UserDefaults(suiteName: groupID)
        let useCustomServer = defaults?.bool(forKey: "debug_useCustomServer") ?? false
        let customServerURL = defaults?.string(forKey: "debug_customServerURL") ?? ""
        
        if useCustomServer && !customServerURL.isEmpty {
            var baseURL = customServerURL
            if !baseURL.hasPrefix("ws://") && !baseURL.hasPrefix("wss://") {
                baseURL = "ws://" + baseURL
            }
            if baseURL.hasSuffix("/") {
                baseURL = String(baseURL.dropLast())
            }
            return URL(string: "\(baseURL)/ws/\(sessionCode)")!
        } else {
            return URL(string: "ws://10.20.5.212:8080/ws/\(sessionCode)")!
        }
    }
    
    private func createPeerConnection() {
        guard isBroadcastActive else {
            NSLog("⚠️ Broadcast inactive, skipping peer connection creation")
            return
        }
        
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
        ]
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
        
        // Add video track
        if let videoTrack = videoTrack {
            peerConnection?.add(videoTrack, streamIds: ["broadcast_stream"])
        }
        
        NSLog("📞 Peer connection created successfully")
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
        
        // Adaptive frame skipping based on system load
        if currentCPUUsage > 70 || currentMemoryPressure > 0.8 {
            dynamicFrameSkip = min(dynamicFrameSkip + 1, 5)
            NSLog("⚠️ High system load detected (CPU: \(currentCPUUsage)%, Mem: \(currentMemoryPressure)) - frame skip: \(dynamicFrameSkip)")
        } else if currentCPUUsage < 40 && currentMemoryPressure < 0.5 {
            dynamicFrameSkip = max(dynamicFrameSkip - 1, max(frameSkip, 1))
        }
        
        adjustBitrateBasedOnSystem()
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
    
    private func adjustBitrateBasedOnSystem() {
        if currentCPUUsage > 60 || currentMemoryPressure > 0.7 {
            currentBitrate = max(Int(Double(currentBitrate) * 0.8), 300_000)
        } else if currentCPUUsage < 30 && currentMemoryPressure < 0.4 {
            currentBitrate = min(Int(Double(currentBitrate) * 1.05), getBitrateForQuality())
        }
    }
    
    private func getBitrateForQuality() -> Int {
        switch qualityLevel {
        case "low": return 500_000
        case "high": return 1_500_000
        default: return 1_000_000
        }
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video && isBroadcastActive else { return }
        
        frameCount += 1
        
        // Process for local recording if enabled
        if !disableLocalRecording {
            processForLocalRecording(sampleBuffer)
        }
        
        // Dynamic frame skipping based on processing load and system resources
        let now = Date()
        let timeSinceLastProcess = now.timeIntervalSince(lastProcessTime)
        
        if timeSinceLastProcess < maxProcessingInterval {
            dynamicFrameSkip = min(dynamicFrameSkip + 1, 5)
        } else if timeSinceLastProcess > maxProcessingInterval * 3 {
            dynamicFrameSkip = max(dynamicFrameSkip - 1, max(frameSkip, 1))
        }
        
        let effectiveFrameSkip = max(frameSkip, dynamicFrameSkip)
        if frameCount % (effectiveFrameSkip + 1) != 0 { return }
        
        lastProcessTime = now
        
        // Send via WebRTC if connected and broadcast is active
        if isWebRTCConnected && isBroadcastActive, let videoSource = videoSource {
            sendFrameViaWebRTC(sampleBuffer: sampleBuffer, videoSource: videoSource)
        }
        
        processed += 1
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastLog) > 10 {
            let fps = Double(processed) / currentTime.timeIntervalSince(lastLog)
            NSLog("📊 Stats: %.1f FPS, Quality: %@, Skip: %d, WebRTC: %@, Signaling: %@, CPU: %.1f%%, Mem: %.1f%%",
                  fps, qualityLevel, effectiveFrameSkip,
                  isWebRTCConnected ? "✅" : "❌",
                  isSignalingConnected ? "✅" : "❌",
                  currentCPUUsage, currentMemoryPressure * 100)
            processed = 0
            lastLog = currentTime
        }
    }
    
    private func sendFrameViaWebRTC(sampleBuffer: CMSampleBuffer, videoSource: RTCVideoSource) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: Int64(timeStampNs))
        
        videoSource.capturer(RTCVideoCapturer(), didCapture: videoFrame)
    }
    
    override func broadcastFinished() {
        NSLog("🛑 Broadcast session ending")
        
        // Mark broadcast as inactive to prevent reconnection attempts
        isBroadcastActive = false
        
        // Stop system monitoring
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        
        // Properly close WebRTC connections
        cleanupWebRTCComponents()
        
        // Finalize local recording if enabled
        if !disableLocalRecording {
            finalizeRecording { success in
                NSLog("📹 Recording finalization: \(success ? "✅" : "❌")")
            }
        }
        
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
        NSLog("🛑 Broadcast session cleanup completed")
    }
    
    // MARK: - Proper Cleanup Methods
    private func cleanupWebRTCComponents() {
        NSLog("🧹 Cleaning up WebRTC components")
        
        // Close peer connection
        peerConnection?.close()
        peerConnection = nil
        
        // Disconnect signaling client properly
        signalingClient?.disconnect()
        signalingClient = nil
        
        // Reset connection state
        isWebRTCConnected = false
        isSignalingConnected = false
        
        // Clean up video components
        videoTrack = nil
        videoSource = nil
        
        NSLog("🧹 WebRTC cleanup completed")
    }
    
    // MARK: - Quality Settings
    private func applyQualitySettings(_ quality: String) {
        switch quality {
        case "low":
            compressionQuality = 0.25
            frameSkip = 3
            downsizeFactor = 0.5
            threshold = 720
            currentBitrate = 400_000
        case "high":
            compressionQuality = 0.7
            frameSkip = 1
            downsizeFactor = 0.85
            threshold = 1280
            currentBitrate = 1_200_000
        default:
            compressionQuality = 0.5
            frameSkip = 2
            downsizeFactor = 0.7
            threshold = 1080
            currentBitrate = 800_000
        }
        
        NSLog("🎛️ Applied quality settings - Quality: \(quality), Bitrate: \(currentBitrate), Skip: \(frameSkip)")
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
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: currentBitrate,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoMaxKeyFrameIntervalKey: 30
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
                
                NSLog("Started recording with dimensions: %dx%d", dimensions.width, dimensions.height)
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
                connectionQualityScore = 1.0
                NSLog("✅ WebRTC connection established successfully - maintaining signaling connection")
                
                // CRITICAL: Do NOT close signaling connection here
                // The signaling channel must remain open for the duration of the broadcast
            }
        case .checking:
            connectionQualityScore = max(connectionQualityScore - 0.1, 0.3)
            NSLog("🔍 ICE connection checking...")
        case .disconnected:
            isWebRTCConnected = false
            connectionQualityScore = max(connectionQualityScore - 0.3, 0.1)
            NSLog("⚠️ WebRTC connection lost")
            
            // Only attempt reconnection if broadcast is still active
            if isBroadcastActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, self.isBroadcastActive else { return }
                    self.attemptReconnection()
                }
            }
        case .failed:
            isWebRTCConnected = false
            connectionQualityScore = 0.0
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
        NSLog("📡 Signaling connected - creating peer connection")
        
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
                    NSLog("✅ Local description set - sending offer")
                    self.signalingClient?.send(sessionDescription: sessionDescription)
                }
            }
        }
    }
    
    func signalingClientDidDisconnect(_ signalingClient: SignalingClient) {
        NSLog("📡❌ Signaling disconnected")
        isSignalingConnected = false
        
        // Only attempt reconnection if broadcast is still active and we haven't established a connection yet
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
                    NSLog("📡 Answer received - WebRTC negotiation complete")
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
        
        // Only retry if broadcast is still active
        if isBroadcastActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, self.isBroadcastActive else { return }
                self.retryConnection()
            }
        }
    }
}
