import Foundation
import WebRTC
import Combine

/// Manages WebRTC connections for the main app (viewer mode only)
class WebRTCManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isConnected = false
    @Published private(set) var connectionState: RTCIceConnectionState = .new
    @Published private(set) var remoteVideoTrack: RTCVideoTrack?
    @Published private(set) var receivedFrameCount = 0
    @Published private(set) var isBroadcastActive = false
    @Published private(set) var activeBroadcastCode: String?
    
    // MARK: - Private Properties
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var signalingClient: SignalingClient?
    private var localVideoRenderer: RTCVideoRenderer?
    
    // Configuration
    private let debugSettings: DebugSettings
    private let groupID = "group.com.elmelz.crcoach"
    
    // Stats tracking
    private var statsTimer: Timer?
    private var lastStatsTime = Date()
    private var lastFrameCount = 0
    
    // Broadcast monitoring
    private var broadcastMonitorTimer: Timer?
    
    // MARK: - Initialization
    init(debugSettings: DebugSettings) {
        self.debugSettings = debugSettings
        super.init()
        
        setupWebRTC()
        startBroadcastMonitoring()
    }
    
    deinit {
        stopBroadcastMonitoring()
        disconnect()
    }
    
    // MARK: - Broadcast State Monitoring
    private func startBroadcastMonitoring() {
        broadcastMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBroadcastState()
        }
    }
    
    private func stopBroadcastMonitoring() {
        broadcastMonitorTimer?.invalidate()
        broadcastMonitorTimer = nil
    }
    
    private func checkBroadcastState() {
        let defaults = UserDefaults(suiteName: groupID)
        let isActive = defaults?.bool(forKey: "webrtc_broadcasting") ?? false
        let sessionCode = defaults?.string(forKey: "webrtc_session_code")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let wasActive = self.isBroadcastActive
            self.isBroadcastActive = isActive
            self.activeBroadcastCode = sessionCode
            
            // Handle broadcast state changes
            if isActive && !wasActive {
                // Broadcast started - device is now broadcasting, don't connect as viewer
                self.disconnect()
                Logger.info("WebRTCManager: Device is now broadcasting, viewer mode disabled", to: Logger.app)
            } else if !isActive && wasActive {
                // Broadcast ended - can now connect as viewer if needed
                self.disconnect()
                Logger.info("WebRTCManager: Broadcast ended, viewer mode available", to: Logger.app)
            }
        }
    }
    
    // MARK: - Public Methods
    func connectAsViewer(to sessionCode: String) {
        // Prevent connecting as viewer if this device is broadcasting
        guard !isBroadcastActive else {
            Logger.info("WebRTCManager: Cannot connect as viewer - device is currently broadcasting", to: Logger.app)
            return
        }
        
        guard !isConnected else {
            Logger.info("WebRTCManager: Already connected", to: Logger.app)
            return
        }
        
        let signalingURL = getSignalingURL(for: sessionCode)
        signalingClient = SignalingClient(url: signalingURL, sessionCode: sessionCode)
        signalingClient?.delegate = self
        signalingClient?.connect()
        
        Logger.info("WebRTCManager: Connecting as viewer to \(signalingURL)", to: Logger.app)
    }
    
    func disconnect() {
        statsTimer?.invalidate()
        statsTimer = nil
        
        signalingClient?.disconnect()
        peerConnection?.close()
        
        signalingClient = nil
        peerConnection = nil
        remoteVideoTrack = nil
        isConnected = false
        receivedFrameCount = 0
        
        Logger.info("WebRTCManager: Disconnected", to: Logger.app)
    }
    
    func setVideoRenderer(_ renderer: RTCVideoRenderer) {
        localVideoRenderer = renderer
        remoteVideoTrack?.add(renderer)
    }
    
    func removeVideoRenderer(_ renderer: RTCVideoRenderer) {
        remoteVideoTrack?.remove(renderer)
        if localVideoRenderer === renderer {
            localVideoRenderer = nil
        }
    }
    
    func incrementFrameCount() {
        DispatchQueue.main.async { [weak self] in
            self?.receivedFrameCount += 1
        }
    }
    
    // MARK: - Private Methods
    private func setupWebRTC() {
        // Initialize WebRTC
        RTCInitializeSSL()
        
        // Create peer connection factory
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        
        Logger.info("WebRTCManager: WebRTC factory initialized", to: Logger.app)
    }
    
    private func getSignalingURL(for sessionCode: String) -> URL {
        // Use the dynamic URL from Constants which checks debug settings
        let baseURL = Constants.URLs.webRTCSignalingServer
        let fullURL = "\(baseURL)/\(sessionCode)"
        
        if Constants.FeatureFlags.enableDebugLogging {
            print("WebRTCManager: Using signaling URL: \(fullURL)")
            print("Debug settings - Custom server enabled: \(debugSettings.useCustomServer)")
            print("Debug settings - Custom URL: \(debugSettings.customServerURL)")
        }
        
        return URL(string: fullURL)!
    }
    
    private func createPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = Constants.URLs.stunServers.map { RTCIceServer(urlStrings: [$0]) }
        config.bundlePolicy = .balanced
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .disabled
        config.candidateNetworkPolicy = .all
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
        
        Logger.info("WebRTCManager: Peer connection created", to: Logger.app)
    }
    
    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.logStats()
        }
    }
    
    private func logStats() {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastStatsTime)
        let frameDiff = receivedFrameCount - lastFrameCount
        let fps = Double(frameDiff) / timeDiff
        
        Logger.info("WebRTCManager: Receiving \(String(format: "%.1f", fps)) FPS, Total frames: \(receivedFrameCount)", to: Logger.app)
        
        lastStatsTime = now
        lastFrameCount = receivedFrameCount
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Logger.info("WebRTCManager: Signaling state changed to \(stateChanged.rawValue)", to: Logger.app)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Logger.info("WebRTCManager: Stream added with \(stream.videoTracks.count) video tracks", to: Logger.app)
        
        DispatchQueue.main.async { [weak self] in
            if let videoTrack = stream.videoTracks.first {
                self?.remoteVideoTrack = videoTrack
                
                // Add to renderer if available
                if let renderer = self?.localVideoRenderer {
                    videoTrack.add(renderer)
                }
                
                // Start stats tracking
                self?.startStatsTimer()
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Logger.info("WebRTCManager: Stream removed", to: Logger.app)
        
        DispatchQueue.main.async { [weak self] in
            if let renderer = self?.localVideoRenderer {
                self?.remoteVideoTrack?.remove(renderer)
            }
            self?.remoteVideoTrack = nil
            self?.statsTimer?.invalidate()
            self?.statsTimer = nil
        }
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Logger.info("WebRTCManager: Should negotiate", to: Logger.app)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Logger.info("WebRTCManager: ICE connection state changed to \(newState.rawValue)", to: Logger.app)
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = newState
            
            switch newState {
            case .connected, .completed:
                self?.isConnected = true
            case .disconnected, .failed, .closed:
                self?.isConnected = false
            default:
                break
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Logger.info("WebRTCManager: ICE gathering state changed to \(newState.rawValue)", to: Logger.app)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Logger.debug("WebRTCManager: Generated ICE candidate", to: Logger.app)
        signalingClient?.send(iceCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Logger.debug("WebRTCManager: Removed ICE candidates", to: Logger.app)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Logger.info("WebRTCManager: Data channel opened", to: Logger.app)
    }
}

// MARK: - SignalingClientDelegate
extension WebRTCManager: SignalingClientDelegate {
    func signalingClientDidConnect(_ signalingClient: SignalingClient) {
        Logger.info("WebRTCManager: Signaling client connected as viewer", to: Logger.app)
        createPeerConnection()
    }
    
    func signalingClientDidDisconnect(_ signalingClient: SignalingClient) {
        Logger.info("WebRTCManager: Signaling client disconnected", to: Logger.app)
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveSessionDescription sessionDescription: RTCSessionDescription) {
        Logger.info("WebRTCManager: Received session description of type \(sessionDescription.type.rawValue)", to: Logger.app)
        
        peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            if let error = error {
                Logger.error("WebRTCManager: Failed to set remote description: \(error.localizedDescription)", to: Logger.app)
            } else {
                Logger.info("WebRTCManager: Remote description set successfully", to: Logger.app)
                
                if sessionDescription.type == .offer {
                    // Create answer as viewer
                    let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
                    self?.peerConnection?.answer(for: constraints) { sessionDescription, error in
                        guard let sessionDescription = sessionDescription else {
                            Logger.error("WebRTCManager: Failed to create answer: \(error?.localizedDescription ?? "Unknown error")", to: Logger.app)
                            return
                        }
                        
                        self?.peerConnection?.setLocalDescription(sessionDescription) { error in
                            if let error = error {
                                Logger.error("WebRTCManager: Failed to set local description: \(error.localizedDescription)", to: Logger.app)
                            } else {
                                Logger.info("WebRTCManager: Answer set as local description", to: Logger.app)
                                self?.signalingClient?.send(sessionDescription: sessionDescription)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        Logger.debug("WebRTCManager: Received ICE candidate", to: Logger.app)
        peerConnection?.add(candidate) { error in
            if let error = error {
                Logger.error("WebRTCManager: Failed to add ICE candidate: \(error.localizedDescription)", to: Logger.app)
            } else {
                Logger.debug("WebRTCManager: ICE candidate added successfully", to: Logger.app)
            }
        }
    }
    
    func signalingClient(_ signalingClient: SignalingClient, didReceiveError error: Error) {
        Logger.error("WebRTCManager: Signaling client error: \(error.localizedDescription)", to: Logger.app)
    }
}

// MARK: - Custom Video Renderer for Frame Counting
class FrameCountingVideoRenderer: NSObject, RTCVideoRenderer {
    weak var webRTCManager: WebRTCManager?
    private let actualRenderer: RTCVideoRenderer
    
    init(actualRenderer: RTCVideoRenderer, webRTCManager: WebRTCManager) {
        self.actualRenderer = actualRenderer
        self.webRTCManager = webRTCManager
        super.init()
    }
    
    func setSize(_ size: CGSize) {
        actualRenderer.setSize(size)
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        if frame != nil {
            webRTCManager?.incrementFrameCount()
        }
        actualRenderer.renderFrame(frame)
    }
}
