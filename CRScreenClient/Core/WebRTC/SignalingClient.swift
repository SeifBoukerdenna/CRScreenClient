import Foundation
import WebRTC

protocol SignalingClientDelegate: AnyObject {
    func signalingClientDidConnect(_ signalingClient: SignalingClient)
    func signalingClientDidDisconnect(_ signalingClient: SignalingClient)
    func signalingClient(_ signalingClient: SignalingClient, didReceiveSessionDescription sessionDescription: RTCSessionDescription)
    func signalingClient(_ signalingClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate)
    func signalingClient(_ signalingClient: SignalingClient, didReceiveError error: Error)
}

class SignalingClient: NSObject {
    
    // MARK: - Properties
    private let url: URL
    private let sessionCode: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    weak var delegate: SignalingClientDelegate?
    
    private var isConnected = false
    private let reconnectDelay: TimeInterval = 3.0
    private var reconnectTimer: Timer?
    private let maxReconnectAttempts = 15
    private var reconnectAttempts = 0
    private var keepAliveTimer: Timer?
    private var lastPongReceived = Date()
    private var connectionTimeoutTimer: Timer?
    
    // MARK: - Initialization
    init(url: URL, sessionCode: String) {
        self.url = url
        self.sessionCode = sessionCode
        super.init()
        
        setupURLSession()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Connection Management
    func connect() {
        guard !isConnected else {
            NSLog("SignalingClient: Already connected")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionCode)", forHTTPHeaderField: "Authorization")
        request.setValue("webrtc-broadcast", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.timeoutInterval = 15.0 // Increased timeout
        
        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()
        
        // Set connection timeout
        startConnectionTimeout()
        
        NSLog("SignalingClient: Connecting to \(url.absoluteString)")
        
        // Start listening for messages
        receiveMessage()
        
        // Send initial connection message
        sendConnectionMessage()
    }
    
    private func startConnectionTimeout() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            NSLog("SignalingClient: Connection timeout")
            self.handleDisconnection()
        }
    }
    
    private func stopConnectionTimeout() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
    }
    
    func sendKeepAlive() {
        guard isConnected else { return }
        
        let message = ["type": "ping", "timestamp": Date().timeIntervalSince1970] as [String: Any]
        sendMessage(message)
    }
    
    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.sendKeepAlive()
            self?.checkKeepAliveTimeout()
        }
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    private func checkKeepAliveTimeout() {
        let timeSinceLastPong = Date().timeIntervalSince(lastPongReceived)
        if timeSinceLastPong > 60.0 { // 60 second timeout
            NSLog("SignalingClient: Keep-alive timeout - forcing reconnection")
            handleDisconnection()
        }
    }
    
    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        
        if isConnected {
            let closeCode = URLSessionWebSocketTask.CloseCode.normalClosure
            webSocket?.cancel(with: closeCode, reason: nil)
        }
        
        webSocket = nil
        isConnected = false
        
        NSLog("SignalingClient: Disconnected")
    }
    
    private func handlePongMessage(_ json: [String: Any]?) {
        lastPongReceived = Date()
        NSLog("SignalingClient: Received pong - connection healthy")
    }
    
    private func handleDisconnection() {
        isConnected = false
        stopKeepAlive()
        stopConnectionTimeout()
        delegate?.signalingClientDidDisconnect(self)
        
        // Attempt reconnection if not manually disconnected
        if reconnectAttempts < maxReconnectAttempts {
            scheduleReconnect()
        } else {
            NSLog("SignalingClient: Max reconnection attempts reached (\(maxReconnectAttempts))")
        }
    }
    
    private func scheduleReconnect() {
        reconnectAttempts += 1
        
        // Exponential backoff with jitter
        let baseDelay = min(Double(reconnectAttempts) * 2.0, 30.0)
        let jitter = Double.random(in: 0...2.0)
        let delay = baseDelay + jitter
        
        NSLog("SignalingClient: Scheduling reconnect attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay)s")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
    
    // MARK: - Message Handling
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.receiveMessage() // Continue listening
                
            case .failure(let error):
                NSLog("SignalingClient: Failed to receive message: \(error.localizedDescription)")
                self?.handleDisconnection()
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleStringMessage(text)
        case .data(let data):
            handleDataMessage(data)
        @unknown default:
            NSLog("SignalingClient: Unknown message type received")
        }
    }
    
    private func handleStringMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            NSLog("SignalingClient: Failed to convert string message to data")
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let messageType = json?["type"] as? String else {
                NSLog("SignalingClient: Message missing type field")
                return
            }
            
            switch messageType {
            case "connected":
                handleConnectedMessage(json)
            case "offer", "answer":
                handleSessionDescriptionMessage(json, type: messageType)
            case "ice":
                handleIceCandidateMessage(json)
            case "pong":
                handlePongMessage(json)
            case "error":
                handleErrorMessage(json)
            default:
                NSLog("SignalingClient: Unknown message type: \(messageType)")
            }
            
        } catch {
            NSLog("SignalingClient: Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        // Handle binary data if needed
        NSLog("SignalingClient: Received binary message of \(data.count) bytes")
    }
    
    // MARK: - Specific Message Handlers
    private func handleConnectedMessage(_ json: [String: Any]?) {
        isConnected = true
        reconnectAttempts = 0
        reconnectTimer?.invalidate()
        stopConnectionTimeout()
        
        // Start keep-alive mechanism
        lastPongReceived = Date()
        startKeepAlive()
        
        NSLog("SignalingClient: Connected successfully with keep-alive enabled")
        delegate?.signalingClientDidConnect(self)
    }
    
    private func handleSessionDescriptionMessage(_ json: [String: Any]?, type: String) {
        guard let sdp = json?["sdp"] as? String else {
            NSLog("SignalingClient: Session description missing SDP")
            return
        }
        
        let sessionType: RTCSdpType = (type == "offer") ? .offer : .answer
        let sessionDescription = RTCSessionDescription(type: sessionType, sdp: sdp)
        
        delegate?.signalingClient(self, didReceiveSessionDescription: sessionDescription)
    }
    
    private func handleIceCandidateMessage(_ json: [String: Any]?) {
        guard let candidate = json?["candidate"] as? String,
              let sdpMLineIndex = json?["sdpMLineIndex"] as? Int32,
              let sdpMid = json?["sdpMid"] as? String else {
            NSLog("SignalingClient: ICE candidate message missing required fields")
            return
        }
        
        let iceCandidate = RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
        
        delegate?.signalingClient(self, didReceiveCandidate: iceCandidate)
    }
    
    private func handleErrorMessage(_ json: [String: Any]?) {
        let errorMessage = json?["message"] as? String ?? "Unknown error"
        let error = NSError(domain: "SignalingClientError", code: -1, userInfo: [
            NSLocalizedDescriptionKey: errorMessage
        ])
        
        delegate?.signalingClient(self, didReceiveError: error)
    }
    
    // MARK: - Sending Messages
    func send(sessionDescription: RTCSessionDescription) {
        let message: [String: Any] = [
            "type": sessionDescription.type == .offer ? "offer" : "answer",
            "sdp": sessionDescription.sdp,
            "sessionCode": sessionCode
        ]
        
        sendMessage(message)
    }
    
    func send(iceCandidate: RTCIceCandidate) {
        let message: [String: Any] = [
            "type": "ice",
            "candidate": iceCandidate.sdp,
            "sdpMLineIndex": iceCandidate.sdpMLineIndex,
            "sdpMid": iceCandidate.sdpMid ?? "",
            "sessionCode": sessionCode
        ]
        
        sendMessage(message)
    }
    
    private func sendConnectionMessage() {
        // Determine role based on context
        let role = determineConnectionRole()
        
        let message: [String: Any] = [
            "type": "connect",
            "sessionCode": sessionCode,
            "role": role
        ]
        
        sendMessage(message)
        NSLog("SignalingClient: Requesting connection as \(role)")
    }
    
    private func determineConnectionRole() -> String {
        // Check if this is being called from broadcast extension
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        
        if bundleIdentifier.contains("Broadcast") {
            return "broadcaster"
        } else {
            // Main app should always connect as viewer
            return "viewer"
        }
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard isConnected || webSocket?.state == .running else {
            NSLog("SignalingClient: Cannot send message - not connected")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            webSocket?.send(.string(jsonString)) { error in
                if let error = error {
                    NSLog("SignalingClient: Failed to send message: \(error.localizedDescription)")
                }
            }
            
        } catch {
            NSLog("SignalingClient: Failed to serialize message: \(error.localizedDescription)")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension SignalingClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        NSLog("SignalingClient: WebSocket opened with protocol")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        NSLog("SignalingClient: WebSocket closed with code: \(closeCode.rawValue)")
        handleDisconnection()
    }
}

// MARK: - URLSessionDelegate
extension SignalingClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("SignalingClient: URLSession task completed with error: \(error.localizedDescription)")
            handleDisconnection()
        }
    }
}
