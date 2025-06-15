//  CRScreenClient/Core/Network/ConnectionMonitor.swift
//  OPTIMIZED VERSION - Exponential backoff, reduced frequency

import Foundation
import Combine
import Network
import SwiftUI

/// Monitors connection status with smart exponential backoff
class ConnectionMonitor: ObservableObject {

    // ───────────────────────────────────────────────────────────── MARК: Published
    @Published private(set) var isServerReachable      = false
    @Published private(set) var lastPingTime: Date?
    @Published private(set) var averageLatency: Double = 0
    @Published private(set) var connectionStatus: ConnectionStatus = .unknown
    @Published private(set) var serverResponse         = "No response"
    @Published private(set) var framesSentCount        = 0
    @Published private(set) var framesAcknowledgedCount = 0

    // ───────────────────────────────────────────────────────────── MARК: Enums
    enum ConnectionStatus {
        case unknown, connecting, connected, disconnected, error(String)

        var displayText: String {
            switch self {
            case .unknown:       "Unknown"
            case .connecting:    "Connecting…"
            case .connected:     "Connected"
            case .disconnected:  "Disconnected"
            case .error(let e):  "Error: \(e)"
            }
        }

        var color: Color {
            switch self {
            case .unknown:      .gray
            case .connecting:   .yellow
            case .connected:    .green
            case .disconnected: .red
            case .error:        .red
            }
        }
    }

    // ───────────────────────────────────────────────────────────── MARК: Private
    private var cancellables  = Set<AnyCancellable>()
    private var pingTimer     : Timer?
    private var networkMonitor: NWPathMonitor?
    private let monitorQueue  = DispatchQueue(label: "ConnectionMonitor")

    private var latencyHistory: [Double] = []
    private let maxLatencyHistory       = 10

    // OPTIMIZATION: Exponential backoff for health checks
    private var currentPingInterval: TimeInterval = 30.0  // Start at 30s instead of 10s
    private let minPingInterval: TimeInterval = 30.0     // Minimum 30s when stable
    private let maxPingInterval: TimeInterval = 300.0    // Max 5 minutes when failing
    private var consecutiveFailures: Int = 0
    private var consecutiveSuccesses: Int = 0
    private let backoffMultiplier: Double = 2.0
    
    // Networking helpers
    private let debugSettings: DebugSettings
    private let urlSession   : URLSession

    // ───────────────────────────────────────────────────────────── MARК: Init / Deinit
    init(debugSettings: DebugSettings) {
        self.debugSettings = debugSettings

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 8  // Increased from 5s
        cfg.timeoutIntervalForResource = 15 // Increased from 10s
        cfg.waitsForConnectivity       = false
        self.urlSession = URLSession(configuration: cfg)

        setupNetworkMonitoring()
        startAdaptivePing()

        Logger.info("ConnectionMonitor: initialized with adaptive ping", to: Logger.app)
    }

    deinit {
        stopMonitoring()
        Logger.info("ConnectionMonitor: deinit", to: Logger.app)
    }

    // ───────────────────────────────────────────────────────────── MARК: Public API
    func startMonitoring() {
        Logger.info("ConnectionMonitor: startMonitoring()", to: Logger.app)
        setupNetworkMonitoring()
        startAdaptivePing()
    }

    func stopMonitoring() {
        Logger.info("ConnectionMonitor: stopMonitoring()", to: Logger.app)
        pingTimer?.invalidate()
        networkMonitor?.cancel()
        cancellables.removeAll()
    }

    func pingServerNow() {
        // Reset to faster ping when user manually requests
        currentPingInterval = minPingInterval
        Task { await performPing() }
    }

    func incrementFramesSent()         { framesSentCount         += 1 }
    func incrementFramesAcknowledged() { framesAcknowledgedCount += 1 }

    func resetCounters() {
        framesSentCount        = 0
        framesAcknowledgedCount = 0
    }

    // ───────────────────────────────────────────────────────────── MARК: OPTIMIZED Private Methods
    private func setupNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    // Network restored - reset backoff and ping immediately
                    self?.resetBackoff()
                    self?.pingServerNow()
                } else {
                    self?.connectionStatus  = .disconnected
                    self?.isServerReachable = false
                }
            }
        }
        networkMonitor?.start(queue: monitorQueue)
    }

    private func startAdaptivePing() {
        pingTimer?.invalidate()
        
        Logger.info("ConnectionMonitor: Starting adaptive ping with \(currentPingInterval)s interval", to: Logger.app)
        
        pingTimer = Timer.scheduledTimer(withTimeInterval: currentPingInterval, repeats: true) { [weak self] _ in
            Task { await self?.performPing() }
        }
        Task { await performPing() } // First immediate ping
    }

    // OPTIMIZATION: Adaptive backoff logic
    private func handlePingSuccess() {
        consecutiveFailures = 0
        consecutiveSuccesses += 1
        
        // After 3 consecutive successes, we can slow down pings
        if consecutiveSuccesses >= 3 && currentPingInterval < maxPingInterval {
            let newInterval = min(currentPingInterval * 1.5, maxPingInterval)
            if newInterval != currentPingInterval {
                currentPingInterval = newInterval
                Logger.info("ConnectionMonitor: Slowing ping to \(currentPingInterval)s (stable connection)", to: Logger.app)
                restartPingTimer()
            }
        }
    }
    
    private func handlePingFailure() {
        consecutiveSuccesses = 0
        consecutiveFailures += 1
        
        // Exponential backoff on failures, but cap it
        if consecutiveFailures >= 2 {
            let newInterval = min(currentPingInterval * backoffMultiplier, maxPingInterval)
            if newInterval != currentPingInterval {
                currentPingInterval = newInterval
                Logger.info("ConnectionMonitor: Backing off ping to \(currentPingInterval)s (failures: \(consecutiveFailures))", to: Logger.app)
                restartPingTimer()
            }
        }
    }
    
    private func resetBackoff() {
        currentPingInterval = minPingInterval
        consecutiveFailures = 0
        consecutiveSuccesses = 0
    }
    
    private func restartPingTimer() {
        pingTimer?.invalidate()
        startAdaptivePing()
    }

    // Core ping routine with adaptive behavior
    private func performPing() async {
        let start = Date()
        await MainActor.run { self.connectionStatus = .connecting }

        do {
            let healthURL = buildBaseURL().appendingPathComponent("health")
            
           
            Logger.debug("ConnectionMonitor: pinging \(healthURL)", to: Logger.app)
            

            let (data, response) = try await urlSession.data(from: healthURL)

            let latency = Date().timeIntervalSince(start) * 1000
            await MainActor.run {
                lastPingTime = Date()
                updateLatency(latency)

                guard let http = response as? HTTPURLResponse else { return }

                if http.statusCode == 200 {
                    connectionStatus  = .connected
                    isServerReachable = true
                    serverResponse    = parseHealthJSON(data) ?? "Server OK"
                    handlePingSuccess() // OPTIMIZATION: Handle success
                } else {
                    connectionStatus  = .error("HTTP \(http.statusCode)")
                    isServerReachable = false
                    serverResponse    = "HTTP \(http.statusCode)"
                    handlePingFailure() // OPTIMIZATION: Handle failure
                }
            }

        } catch {
            await MainActor.run {
                connectionStatus  = .error(error.localizedDescription)
                isServerReachable = false
                serverResponse    = "Connection failed: \(error.localizedDescription)"
                handlePingFailure() // OPTIMIZATION: Handle failure
            }
        }
    }

    private func parseHealthJSON(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let sessions   = dict["active_sessions"]   as? Int ?? 0
        let broadcasters = dict["total_broadcasters"] as? Int ?? 0
        let viewers      = dict["total_viewers"]      as? Int ?? 0
        return "Sessions: \(sessions), Broadcasters: \(broadcasters), Viewers: \(viewers)"
    }

    private func updateLatency(_ newLatency: Double) {
        latencyHistory.append(newLatency)
        if latencyHistory.count > maxLatencyHistory { latencyHistory.removeFirst() }
        averageLatency = latencyHistory.reduce(0,+) / Double(latencyHistory.count)
    }

    // ───────────────────────────────────────────────────────────── MARК: URL helpers
    /// Returns an **absolute URL** containing scheme, host, and the correct port.
    private func buildBaseURL() -> URL {
        // 1. Start with either the custom value or default host
        var raw = debugSettings.useCustomServer && !debugSettings.customServerURL.isEmpty
                  ? debugSettings.customServerURL
                  : "api.tormentor.dev:443"

        // 2. Strip any leading scheme so we can rebuild cleanly
        if let range = raw.range(of: "://") { raw = String(raw[range.upperBound...]) }

        // 3. Separate host vs port if a port was already supplied
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let host  = String(parts[0])
        let customPort = parts.count == 2 ? Int(parts[1]) : nil

        // 4. Choose defaults if no explicit port
        let secure = debugSettings.preferSecureConnection
        let port   = customPort ?? (secure ? 443 : 443)

        // 5. Build safely with URLComponents
        var c = URLComponents()
        c.scheme = secure ? "https" : "http"
        c.host   = host
        c.port   = port
        return c.url!
    }

    // Exposed to UI so ConnectionStatusView can show the endpoint
    var baseEndpointForDisplay: String { buildBaseURL().absoluteString }
}

// ──────────────────────────────────────────────────────────────────────────
extension ConnectionMonitor {
    var connectionStatusViewModel: ConnectionStatusViewModel {
        ConnectionStatusViewModel(
            status: connectionStatus,
            isReachable: isServerReachable,
            latency: averageLatency,
            lastPing: lastPingTime,
            serverInfo: serverResponse,
            framesSent: framesSentCount,
            framesAcknowledged: framesAcknowledgedCount,
            pingInterval: currentPingInterval // OPTIMIZATION: Show current interval
        )
    }
}

struct ConnectionStatusViewModel {
    let status: ConnectionMonitor.ConnectionStatus
    let isReachable: Bool
    let latency: Double
    let lastPing: Date?
    let serverInfo: String
    let framesSent: Int
    let framesAcknowledged: Int
    let pingInterval: TimeInterval // OPTIMIZATION: Added ping interval

    var latencyText: String { latency > 0 ? String(format: "%.0f ms", latency) : "—" }

    var lastPingText: String {
        guard let lastPing else { return "Never" }
        let f = DateFormatter(); f.timeStyle = .medium; return f.string(from: lastPing)
    }

    var frameDeliveryRate: Double {
        guard framesSent > 0 else { return 0 }
        return Double(framesAcknowledged) / Double(framesSent) * 100
    }

    var frameDeliveryText: String { String(format: "%.1f %%", frameDeliveryRate) }
    
    // OPTIMIZATION: Show ping interval in UI
    var pingIntervalText: String {
        if pingInterval >= 60 {
            return String(format: "%.0fm", pingInterval / 60)
        } else {
            return String(format: "%.0fs", pingInterval)
        }
    }
}
