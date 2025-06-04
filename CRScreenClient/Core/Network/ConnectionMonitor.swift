//  CRScreenClient/Core/Network/ConnectionMonitor.swift
//  Updated 2025-06-04 – always includes the correct port (8080/443)

import Foundation
import Combine
import Network
import SwiftUI

/// Monitors connection status to the server with ping/pong functionality
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

    // Networking helpers
    private let debugSettings: DebugSettings
    private let urlSession   : URLSession

    // ───────────────────────────────────────────────────────────── MARК: Init / Deinit
    init(debugSettings: DebugSettings) {
        self.debugSettings = debugSettings

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 5
        cfg.timeoutIntervalForResource = 10
        cfg.waitsForConnectivity       = false
        self.urlSession = URLSession(configuration: cfg)

        setupNetworkMonitoring()
        startPeriodicPing()

        Logger.info("ConnectionMonitor: initialized", to: Logger.app)
    }

    deinit {
        stopMonitoring()
        Logger.info("ConnectionMonitor: deinit", to: Logger.app)
    }

    // ───────────────────────────────────────────────────────────── MARК: Public API
    func startMonitoring() {
        Logger.info("ConnectionMonitor: startMonitoring()", to: Logger.app)
        setupNetworkMonitoring()
        startPeriodicPing()
    }

    func stopMonitoring() {
        Logger.info("ConnectionMonitor: stopMonitoring()", to: Logger.app)
        pingTimer?.invalidate()
        networkMonitor?.cancel()
        cancellables.removeAll()
    }

    func pingServerNow() { Task { await performPing() } }

    func incrementFramesSent()         { framesSentCount         += 1 }
    func incrementFramesAcknowledged() { framesAcknowledgedCount += 1 }

    func resetCounters() {
        framesSentCount        = 0
        framesAcknowledgedCount = 0
    }

    // ───────────────────────────────────────────────────────────── MARК: Private
    private func setupNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.pingServerNow()
                } else {
                    self?.connectionStatus  = .disconnected
                    self?.isServerReachable = false
                }
            }
        }
        networkMonitor?.start(queue: monitorQueue)
    }

    private func startPeriodicPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { await self?.performPing() }
        }
        Task { await performPing() } // first immediate ping
    }

    // Core ping routine
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
                } else {
                    connectionStatus  = .error("HTTP \(http.statusCode)")
                    isServerReachable = false
                    serverResponse    = "HTTP \(http.statusCode)"
                }
            }

        } catch {
            await MainActor.run {
                connectionStatus  = .error(error.localizedDescription)
                isServerReachable = false
                serverResponse    = "Connection failed: \(error.localizedDescription)"
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
                  : "35.208.133.112:8080"

        // 2. Strip any leading scheme so we can rebuild cleanly
        if let range = raw.range(of: "://") { raw = String(raw[range.upperBound...]) }

        // 3. Separate host vs port if a port was already supplied
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let host  = String(parts[0])
        let customPort = parts.count == 2 ? Int(parts[1]) : nil

        // 4. Choose defaults if no explicit port
        let secure = debugSettings.preferSecureConnection
        let port   = customPort ?? (secure ? 443 : 8080)

        // 5. Build safely with URLComponents
        var c = URLComponents()
        c.scheme = secure ? "https" : "http"
        c.host   = host
        c.port   = port
        return c.url!   // safe: all fields are valid
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
            framesAcknowledged: framesAcknowledgedCount
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
}
