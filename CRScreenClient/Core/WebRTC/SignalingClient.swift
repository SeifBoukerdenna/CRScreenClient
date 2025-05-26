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
    
    // MARK: - Connection State Management
    private var isConnected = false
    private var isManualDisconnect = false
    private var shouldMaintainConnection = true
    private let reconnectDelay: TimeInterval = 5.0
    private var reconnectTimer: Timer?
    private let maxReconnectAttempts = 8
    private var reconnectAttempts = 0
    private var keepAliveTimer: Timer?
    private var lastPongReceived = Date()
    private var connectionTimeoutTimer: Timer?
    
    // MARK: - Health Monitoring
    private var connectionStartTime: Date?
    private var lastMessageTime = Date()
    private let messageTimeout: TimeInterval = 45.0
    private let connectionHealthCheckInterval: TimeInterval = 20.0
    
    // MARK: - Initialization
    init(url: URL, sessionCode: String) {
        self.url = url
        self.sessionCode = sessionCode
        super.init()
        
        setupURLSession()
    }
    
    deinit {
        NSLog("SignalingClient: Deinitializing for session \(sessionCode)")
        cleanupTimers()
        cleanupConnection()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Connection Management
    func connect() {
        guard shouldMaintainConnection else {
            NSLog("SignalingClient: Connection disabled, skipping connect")
            return
        }
        
        guard !isConnected else {
            NSLog("SignalingClient: Already connected to session \(sessionCode)")
            return
        }
        
        isManualDisconnect = false
        connectionStartTime = Date()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(sessionCode)", forHTTPHeaderField: "Authorization")
        request.setValue("webrtc-broadcast", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.timeoutInterval = 12.0
        
        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()
        
        startConnectionTimeout()
        
        NSLog("SignalingClient: Connecting to \(url.absoluteString) (attempt \(reconnectAttempts + 1))")
        
        receiveMessage()
        
        // Send initial connection message with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendConnectionMessage()
        }
    }
    
    func disconnect() {
        NSLog("SignalingClient: Manual disconnect requested for session \(sessionCode)")
        
        // Mark as manual disconnect to prevent automatic reconnection
        isManualDisconnect = true
        shouldMaintainConnection = false
        
        cleanupTimers()
        cleanupConnection()
        
        NSLog("SignalingClient: Manual disconnect completed")
    }
    
    private func cleanupTimers() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
    }
    
    private func cleanupConnection() {
        if let ws = webSocket, ws.state == .running {
            ws.cancel(with: .normalClosure, reason: nil)
        }
        
        webSocket = nil
        isConnected = false
        connectionStartTime = nil
        
        NSLog("SignalingClient: Connection cleanup completed")
    }
    
    private func startConnectionTimeout() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            NSLog("SignalingClient: Connection timeout after 12s")
            self.handleConnectionFailure()
        }
    }
    
    private func stopConnectionTimeout() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
    }
    
    // MARK: - Keep-Alive Management
    func sendKeepAlive() {
        guard isConnected && shouldMaintainConnection else { return }
        
        let message = ["type": "ping", "timestamp": Date().timeIntervalSince1970] as [String: Any]
        sendMessage(message)
        NSLog("SignalingClient: Sent keep-alive ping")
    }
    
    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: connectionHealthCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.shouldMaintainConnection else { return }
            self.performHealthCheck()
        }
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    private func performHealthCheck() {
        checkKeepAliveTimeout()
        sendKeepAlive()
        
        if let startTime = connectionStartTime {
            let connectionDuration = Date().timeIntervalSince(startTime)
            let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
            
            NSLog("SignalingClient: Health check - Duration: \(Int(connectionDuration))s, Last message: \(Int(timeSinceLastMessage))s ago")
            
            if timeSinceLastMessage > messageTimeout && shouldMaintainConnection {
                NSLog("SignalingClient: No recent activity - triggering reconnection")
                handleConnectionFailure()
            }
        }
    }
    
    private func checkKeepAliveTimeout() {
        let timeSinceLastPong = Date().timeIntervalSince(lastPongReceived)
        if timeSinceLastPong > messageTimeout && shouldMaintainConnection {
            NSLog("SignalingClient: Keep-alive timeout (\(Int(timeSinceLastPong))s) - triggering reconnection")
            handleConnectionFailure()
        }
    }
    
    // MARK: - Connection Failure Handling
    private func handleConnectionFailure() {
        NSLog("SignalingClient: Handling connection failure (manual: \(isManualDisconnect), should maintain: \(shouldMaintainConnection))")
        
        let wasConnected = isConnected
        cleanupConnection()
        stopConnectionTimeout()
        
        if wasConnected && !isManualDisconnect {
            delegate?.signalingClientDidDisconnect(self)
        }
        
        // Only attempt reconnection if not manually disconnected and should maintain connection
        if !isManualDisconnect && shouldMaintainConnection && reconnectAttempts < maxReconnectAttempts {
            scheduleReconnect()
        } else if reconnectAttempts >= maxReconnectAttempts {
            NSLog("SignalingClient: Max reconnection attempts reached (\(maxReconnectAttempts)) - stopping")
            shouldMaintainConnection = false
        }
    }
    
    private func scheduleReconnect() {
        reconnectAttempts += 1
        
        let baseDelay = min(Double(reconnectAttempts) * 3.0, 30.0)
        let jitter = Double.random(in: 0...3.0)
        let delay = baseDelay + jitter
        
        NSLog("SignalingClient: Scheduling reconnect attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(Int(delay))s")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.shouldMaintainConnection && !self.isManualDisconnect else { return }
            NSLog("SignalingClient: Executing scheduled reconnection")
            self.connect()
        }
    }
    
    // MARK: - Message Handling
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.lastMessageTime = Date()
                self?.handleWebSocketMessage(message)
                self?.receiveMessage() // Continue listening
                
            case .failure(let error):
                NSLog("SignalingClient: Failed to receive message: \(error.localizedDescription)")
                self?.handleConnectionFailure()
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
            
            NSLog("SignalingClient: Received message type: \(messageType)")
            
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
            case "broadcaster_disconnected":
                NSLog("SignalingClient: Broadcaster disconnected notification received")
                // Don't disconnect, just notify delegate
            default:
                NSLog("SignalingClient: Unknown message type: \(messageType)")
            }
            
        } catch {
            NSLog("SignalingClient: Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        NSLog("SignalingClient: Received binary message of \(data.count) bytes")
    }
    
    // MARK: - Specific Message Handlers
    private func handleConnectedMessage(_ json: [String: Any]?) {
        isConnected = true
        reconnectAttempts = 0
        reconnectTimer?.invalidate()
        stopConnectionTimeout()
        
        lastPongReceived = Date()
        lastMessageTime = Date()
        startKeepAlive()
        
        if let connectionTime = connectionStartTime {
            let connectDuration = Date().timeIntervalSince(connectionTime)
            NSLog("SignalingClient: Connected successfully in \(String(format: "%.2f", connectDuration))s")
        }
        
        delegate?.signalingClientDidConnect(self)
    }
    
    private func handleSessionDescriptionMessage(_ json: [String: Any]?, type: String) {
        guard let sdp = json?["sdp"] as? String else {
            NSLog("SignalingClient: Session description missing SDP")
            return
        }
        
        let sessionType: RTCSdpType = (type == "offer") ? .offer : .answer
        let sessionDescription = RTCSessionDescription(type: sessionType, sdp: sdp)
        
        NSLog("SignalingClient: Processing \(type) with SDP length: \(sdp.count)")
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
    
    private func handlePongMessage(_ json: [String: Any]?) {
        lastPongReceived = Date()
        lastMessageTime = Date()
        NSLog("SignalingClient: Received pong - connection healthy")
    }
    
    private func handleErrorMessage(_ json: [String: Any]?) {
        let errorMessage = json?["message"] as? String ?? "Unknown signaling error"
        NSLog("SignalingClient: Server error: \(errorMessage)")
        
        let error = NSError(domain: "SignalingClientError", code: -1, userInfo: [
            NSLocalizedDescriptionKey: errorMessage
        ])
        
        delegate?.signalingClient(self, didReceiveError: error)
        
        // Don't immediately disconnect on error, schedule a health check instead
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.shouldMaintainConnection else { return }
            self.performHealthCheck()
        }
    }
    
    // MARK: - Sending Messages
    func send(sessionDescription: RTCSessionDescription) {
        let message: [String: Any] = [
            "type": sessionDescription.type == .offer ? "offer" : "answer",
            "sdp": sessionDescription.sdp,
            "sessionCode": sessionCode
        ]
        
        NSLog("SignalingClient: Sending \(sessionDescription.type == .offer ? "offer" : "answer")")
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
        let role = determineConnectionRole()
        
        let message: [String: Any] = [
            "type": "connect",
            "sessionCode": sessionCode,
            "role": role,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        NSLog("SignalingClient: Requesting connection as \(role)")
        sendMessage(message)
    }
    
    private func determineConnectionRole() -> String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        
        if bundleIdentifier.contains("Broadcast") {
            return "broadcaster"
        } else {
            return "viewer"
        }
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard isConnected || webSocket?.state == .running else {
            NSLog("SignalingClient: Cannot send message - not connected (state: \(webSocket?.state.rawValue ?? -1))")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            webSocket?.send(.string(jsonString)) { [weak self] error in
                if let error = error {
                    NSLog("SignalingClient: Failed to send message: \(error.localizedDescription)")
                    self?.handleConnectionFailure()
                } else {
                    self?.lastMessageTime = Date()
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
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        NSLog("SignalingClient: WebSocket closed with code: \(closeCode.rawValue), reason: \(reasonString)")
        
        // Only trigger failure handling if this wasn't a manual disconnect
        if !isManualDisconnect {
            handleConnectionFailure()
        }
    }
}

// MARK: - URLSessionDelegate
extension SignalingClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("SignalingClient: URLSession task completed with error: \(error.localizedDescription)")
            if !isManualDisconnect {
                handleConnectionFailure()
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        NSLog("SignalingClient: HTTP redirection attempted, blocking for security")
        completionHandler(nil)
    }
}
