// CRScreenClient/Features/UI/Components/ConnectionStatusView.swift
import SwiftUI
import CoreTelephony

struct ConnectionStatusView: View {
    @ObservedObject var connectionMonitor: ConnectionMonitor
    @State private var isExpanded = false
    @State private var showDetailedView = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact status indicator
            compactStatusView
            
            // Expanded details (when tapped)
            if isExpanded {
                expandedDetailsView
                    .transition(.slide)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(statusColor.opacity(0.5), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
        .sheet(isPresented: $showDetailedView) {
            DetailedConnectionView(connectionMonitor: connectionMonitor)
        }
    }
    
    // MARK: - Compact Status View
    private var compactStatusView: some View {
        HStack(spacing: 8) {
            // Status indicator circle
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(connectionMonitor.isServerReachable ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                          value: connectionMonitor.isServerReachable)
            
            // Status text
            Text(connectionMonitor.connectionStatus.displayText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // Latency
            if connectionMonitor.averageLatency > 0 {
                Text(connectionMonitor.connectionStatusViewModel.latencyText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Expand/collapse indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Expanded Details View
    private var expandedDetailsView: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Connection details grid
            VStack(spacing: 6) {
                connectionDetailRow("Server:", connectionMonitor.serverResponse)
                connectionDetailRow("Last Ping:", connectionMonitor.connectionStatusViewModel.lastPingText)
                
                // Show current endpoint being used
                connectionDetailRow("Endpoint:", getCurrentEndpoint())
                
                if connectionMonitor.framesSentCount > 0 {
                    connectionDetailRow("Frames Sent:", "\(connectionMonitor.framesSentCount)")
                    connectionDetailRow("Acknowledged:", "\(connectionMonitor.framesAcknowledgedCount)")
                    connectionDetailRow("Delivery Rate:", connectionMonitor.connectionStatusViewModel.frameDeliveryText)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Ping now button
                Button(action: {
                    connectionMonitor.pingServerNow()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Ping")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Detailed view button
                Button(action: {
                    showDetailedView = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Details")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reset counters button
                if connectionMonitor.framesSentCount > 0 {
                    Button(action: {
                        connectionMonitor.resetCounters()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Helper Views
    private func connectionDetailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func getCurrentEndpoint() -> String {
        let debugSettings = DebugSettings()
        if debugSettings.useCustomServer && !debugSettings.customServerURL.isEmpty {
            return debugSettings.customServerURL
        }
        return "34.56.170.86:8080"
    }
    
    private var statusColor: Color {
        switch connectionMonitor.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Detailed Connection View
struct DetailedConnectionView: View {
    @ObservedObject var connectionMonitor: ConnectionMonitor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [.crBlue, Color(red: 0, green: 0.1, blue: 0.3)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Connection Status Section
                        connectionStatusSection
                        
                        // Performance Metrics Section
                        performanceMetricsSection
                        
                        // Frame Delivery Section
                        frameDeliverySection
                        
                        // Server Information Section
                        serverInformationSection
                        
                        // Network Diagnostics Section
                        networkDiagnosticsSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("Connection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Connection Status", icon: "network")
            
            VStack(spacing: 12) {
                statusIndicatorCard
                
                HStack(spacing: 12) {
                    actionButton("Ping Now", icon: "arrow.clockwise", color: .blue) {
                        connectionMonitor.pingServerNow()
                    }
                    
                    actionButton("Reset Counters", icon: "arrow.counterclockwise", color: .orange) {
                        connectionMonitor.resetCounters()
                    }
                }
            }
        }
    }
    
    private var statusIndicatorCard: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 16, height: 16)
                    .scaleEffect(connectionMonitor.isServerReachable ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                              value: connectionMonitor.isServerReachable)
                
                Text(connectionMonitor.connectionStatus.displayText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let lastPing = connectionMonitor.lastPingTime {
                HStack {
                    Text("Last Contact:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: lastPing, relativeTo: Date()))
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Performance Metrics", icon: "speedometer")
            
            HStack(spacing: 12) {
                metricCard("Latency",
                          value: connectionMonitor.connectionStatusViewModel.latencyText,
                          subtitle: "Average",
                          color: latencyColor)
                
                metricCard("Server",
                          value: connectionMonitor.isServerReachable ? "Online" : "Offline",
                          subtitle: "Status",
                          color: connectionMonitor.isServerReachable ? .green : .red)
            }
        }
    }
    
    private var frameDeliverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Frame Delivery", icon: "video.fill")
            
            if connectionMonitor.framesSentCount > 0 {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        metricCard("Sent",
                                  value: "\(connectionMonitor.framesSentCount)",
                                  subtitle: "Frames",
                                  color: .blue)
                        
                        metricCard("Acknowledged",
                                  value: "\(connectionMonitor.framesAcknowledgedCount)",
                                  subtitle: "Frames",
                                  color: .green)
                    }
                    
                    // Delivery rate progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Delivery Rate")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(connectionMonitor.connectionStatusViewModel.frameDeliveryText)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        ProgressView(value: connectionMonitor.connectionStatusViewModel.frameDeliveryRate / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: deliveryRateColor))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
                }
            } else {
                Text("No frame data available")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
            }
        }
    }
    
    private var serverInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Server Information", icon: "server.rack")
            
            VStack(alignment: .leading, spacing: 12) {
                // Current server response
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status Response:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(connectionMonitor.serverResponse)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                )
                
                // Active endpoints
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Endpoints:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        endpointRow("Health Check:", getHealthEndpoint())
                        endpointRow("WebRTC Signaling:", getWebRTCEndpoint())
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                )
            }
        }
    }
    
    private func endpointRow(_ title: String, _ endpoint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.crGold)
            
            Text(endpoint)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(nil)
        }
    }
    
    private func getHealthEndpoint() -> String {
        // Get the health endpoint being used
        let debugSettings = DebugSettings()
        if debugSettings.useCustomServer && !debugSettings.customServerURL.isEmpty {
            var url = debugSettings.customServerURL
            
            // Remove protocol if present
            if url.hasPrefix("ws://") || url.hasPrefix("wss://") {
                url = String(url.dropFirst(url.hasPrefix("wss://") ? 6 : 5))
            }
            if url.hasPrefix("http://") || url.hasPrefix("https://") {
                url = String(url.dropFirst(url.hasPrefix("https://") ? 8 : 7))
            }
            
            let protocol_URL = debugSettings.preferSecureConnection ? "https://" : "http://"
            return "\(protocol_URL)\(url)/health"
        }
        return "http://34.56.170.86:8080/health"
    }
    
    private func getWebRTCEndpoint() -> String {
        // Get the WebRTC endpoint being used
        let debugSettings = DebugSettings()
        if debugSettings.useCustomServer && !debugSettings.customServerURL.isEmpty {
            var baseURL = debugSettings.customServerURL
            if !baseURL.hasPrefix("ws://") && !baseURL.hasPrefix("wss://") {
                baseURL = "ws://" + baseURL
            }
            if baseURL.hasSuffix("/") {
                baseURL = String(baseURL.dropLast())
            }
            return "\(baseURL)/ws/[session]"
        }
        return "ws://34.56.170.86:8080/ws/[session]"
    }
    
    private var networkDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Network Diagnostics", icon: "wifi")
            
            VStack(spacing: 8) {
                diagnosticRow("Network Type:", getNetworkType())
                diagnosticRow("WiFi:", isWiFiConnected() ? "Connected" : "Not Connected")
                diagnosticRow("Cellular:", isCellularConnected() ? "Available" : "Not Available")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.crGold)
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func metricCard(_ title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.7))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Computed Properties
    private var statusColor: Color {
        switch connectionMonitor.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        case .error: return .red
        case .unknown: return .gray
        }
    }
    
    private var latencyColor: Color {
        let latency = connectionMonitor.averageLatency
        if latency < 50 { return .green }
        else if latency < 150 { return .yellow }
        else { return .red }
    }
    
    private var deliveryRateColor: Color {
        let rate = connectionMonitor.connectionStatusViewModel.frameDeliveryRate
        if rate >= 90 { return .green }
        else if rate >= 70 { return .yellow }
        else { return .red }
    }
    
    // MARK: - Network Diagnostic Helpers
    private func getNetworkType() -> String {
        // This is a simplified implementation
        // You could integrate with NWPathMonitor for more detailed info
        if isWiFiConnected() { return "WiFi" }
        else if isCellularConnected() { return "Cellular" }
        else { return "Unknown" }
    }
    
    private func isWiFiConnected() -> Bool {
        // Check current network connection type
        let networkInfo = CTTelephonyNetworkInfo()
        return networkInfo.currentRadioAccessTechnology == nil
    }
    
    private func isCellularConnected() -> Bool {
        // Check if cellular is available
        let networkInfo = CTTelephonyNetworkInfo()
        return networkInfo.currentRadioAccessTechnology != nil
    }
}

// MARK: - Preview
struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let debugSettings = DebugSettings()
        let connectionMonitor = ConnectionMonitor(debugSettings: debugSettings)
        
        return VStack {
            ConnectionStatusView(connectionMonitor: connectionMonitor)
                .padding()
            
            Spacer()
        }
        .background(Color.black)
    }
}
