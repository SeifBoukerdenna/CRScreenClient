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
    
    // MARK: - Video Processing
    private var compressionQuality: CGFloat = 0.6
    private var frameSkip = 1
    private var downsizeFactor: CGFloat = 0.8
    private var threshold: Int = 1280
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    
    // MARK: - State Management
    private var frameCount = 0
    private var lastLog = Date()
    private var processed = 0
    private var isWebRTCConnected = false
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 10
    
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
        let defaults = UserDefaults(suiteName: groupID)
        
        // Get session code and quality settings
        sessionCode = defaults?.string(forKey: kCodeKey) ?? "0000"
        disableLocalRecording = defaults?.bool(forKey: "debug_disableLocalRecording") ?? false
        
        if let savedQuality = defaults?.string(forKey: kQualityKey) {
            qualityLevel = savedQuality
        } else if let quality = setupInfo?["qualityLevel"] as? String {
            qualityLevel = quality
        }
        
        applyQualitySettings(qualityLevel)
        
        // Mark broadcast as started
        defaults?.set(Date(), forKey: kStartedAtKey)
        
        // Initialize WebRTC with proper sequencing
        setupWebRTCWithRetry()
        
        // Setup local recording if enabled
        if !disableLocalRecording {
            setupLocalRecording()
        }
        
        NSLog("Broadcast started - Session: \(sessionCode), Quality: \(qualityLevel)")
    }
    
    private func setupWebRTCWithRetry() {
        connectionAttempts += 1
        
        if connectionAttempts > maxConnectionAttempts {
            NSLog("❌ Max WebRTC connection attempts reached")
            return
        }
        
        NSLog("🔄 WebRTC setup attempt \(connectionAttempts)/\(maxConnectionAttempts)")
        
        // Initialize WebRTC components
        setupWebRTC()
        
        // If connection fails, retry after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            
            if !self.isWebRTCConnected && self.connectionAttempts < self.maxConnectionAttempts {
                NSLog("⚠️ WebRTC not connected, retrying...")
                self.cleanup()
                self.setupWebRTCWithRetry()
            }
        }
    }
    
    private func setupWebRTC() {
        // Initialize peer connection factory
        peerConnectionFactory = createPeerConnectionFactory()
        
        // Create video source
        videoSource = peerConnectionFactory.videoSource()
        
        // Create video track
        videoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "video_track_\(sessionCode)")
        
        // Setup signaling client
        let signalingURL = getSignalingURL()
        signalingClient = SignalingClient(url: signalingURL, sessionCode: sessionCode)
        signalingClient?.delegate = self
        
        // Connect to signaling server
        signalingClient?.connect()
        
        NSLog("📡 WebRTC initialized - Signaling: \(signalingURL)")
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
        
        NSLog("📞 Peer connection created")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video else { return }
        
        frameCount += 1
        
        // Process for local recording if enabled
        if !disableLocalRecording {
            processForLocalRecording(sampleBuffer)
        }
        
        // Skip frames based on quality settings
        if frameCount % (frameSkip + 1) != 0 { return }
        
        // Send via WebRTC if connected
        if isWebRTCConnected, let videoSource = videoSource {
            sendFrameViaWebRTC(sampleBuffer: sampleBuffer, videoSource: videoSource)
        }
        
        processed += 1
        let now = Date()
        if now.timeIntervalSince(lastLog) > 5 {
            NSLog("📊 Stats: %.1f FPS, Quality: %@, WebRTC: %@",
                  Double(processed) / now.timeIntervalSince(lastLog),
                  qualityLevel,
                  isWebRTCConnected ? "Connected" : "Disconnected")
            processed = 0
            lastLog = now
        }
    }
    
    private func sendFrameViaWebRTC(sampleBuffer: CMSampleBuffer, videoSource: RTCVideoSource) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1_000_000_000
        
        // Create RTCCVPixelBuffer
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: Int64(timeStampNs))
        
        // Send frame to video source
        videoSource.capturer(RTCVideoCapturer(), didCapture: videoFrame)
    }
    
    override func broadcastFinished() {
        NSLog("🛑 Broadcast finished")
        
        // Close WebRTC connections
        cleanup()
        
        // Finalize local recording if enabled
        if !disableLocalRecording {
            finalizeRecording { success in
                NSLog("📹 Recording finalization: \(success ? "✅" : "❌")")
            }
        }
        
        UserDefaults(suiteName: groupID)?.removeObject(forKey: kStartedAtKey)
    }
    
    private func cleanup() {
        isWebRTCConnected = false
        connectionAttempts = 0
        
        peerConnection?.close()
        signalingClient?.disconnect()
        
        peerConnection = nil
        videoTrack = nil
        videoSource = nil
        signalingClient = nil
        
        NSLog("🧹 WebRTC cleanup completed")
    }
    
    // MARK: - Quality Settings (unchanged)
    private func applyQualitySettings(_ quality: String) {
        switch quality {
        case "low":
            compressionQuality = 0.3
            frameSkip = 2
            downsizeFactor = 0.6
            threshold = 960
        case "high":
            compressionQuality = 0.85
            frameSkip = 0
            downsizeFactor = 1.0
            threshold = 1600
        default: // medium
            compressionQuality = 0.6
            frameSkip = 1
            downsizeFactor = 0.8
            threshold = 1280
        }
    }
    
    // MARK: - Local Recording Methods (unchanged from original)
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
                        AVVideoAverageBitRateKey: 6000000,
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
            isWebRTCConnected = true
            connectionAttempts = 0 // Reset on successful connection
            NSLog("✅ WebRTC connection established")
        case .disconnected:
            isWebRTCConnected = false
            NSLog("⚠️ WebRTC connection lost")
            // Attempt reconnection
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.attemptReconnection()
            }
        case .failed:
            isWebRTCConnected = false
            NSLog("❌ WebRTC connection failed")
            // Attempt reconnection with cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.cleanupAndReconnect()
            }
        case .closed:
            isWebRTCConnected = false
            NSLog("🔒 WebRTC connection closed")
        default:
            break
        }
    }
    
    private func attemptReconnection() {
        guard connectionAttempts < maxConnectionAttempts else {
            NSLog("❌ Max reconnection attempts reached")
            return
        }
        
        if !isWebRTCConnected {
            NSLog("🔄 Attempting WebRTC reconnection...")
            signalingClient?.connect()
        }
    }
    
    private func cleanupAndReconnect() {
        guard connectionAttempts < maxConnectionAttempts else {
            NSLog("❌ Max reconnection attempts reached")
            return
        }
        
        NSLog("🧹 Cleanup and reconnect WebRTC...")
        
        // Close existing connections
        peerConnection?.close()
        signalingClient?.disconnect()
        
        // Reset connection state
        peerConnection = nil
        
        // Wait a moment then reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.setupWebRTCWithRetry()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        NSLog("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        NSLog("Generated ICE candidate")
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
        createPeerConnection()
        
        // Create offer as broadcaster
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sessionDescription, error in
            guard let self = self, let sessionDescription = sessionDescription else {
                NSLog("❌ Failed to create offer: \(error?.localizedDescription ?? "Unknown error")")
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
        isWebRTCConnected = false
        
        // Attempt reconnection if we haven't exceeded max attempts
        if connectionAttempts < maxConnectionAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.attemptReconnection()
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveSessionDescription sessionDescription: RTCSessionDescription) {
        NSLog("📡 Received session description: \(sessionDescription.type.rawValue)")
        
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
        NSLog("📡 Received ICE candidate")
        peerConnection?.add(candidate) { error in
            if let error = error {
                NSLog("❌ Failed to add ICE candidate: \(error.localizedDescription)")
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveError error: Error) {
        NSLog("📡❌ Signaling error: \(error.localizedDescription)")
        isWebRTCConnected = false
    }
}
