// CRScreenClient/Features/UI/Screens/MainScreen.swift
import SwiftUI
import AVKit
import ReplayKit
import Combine

struct MainScreen: View {
    @StateObject private var broadcastManager = BroadcastManager()
    @StateObject private var pipManager = PiPManager()
    @StateObject private var connectionMonitor: ConnectionMonitor
    @State private var broadcastButton: UIButton?
    @State private var player = AVPlayer()
    @State private var isVideoPrepared = false
    @State private var shouldSetupVideo = false
    @State private var showQualitySettings = false
    @State private var showRecentBroadcasts = false
    @State private var showSettings = false
    @State private var showBroadcastSavedToast = false
    
    // Debug-related state
    @State private var showDebugMenu = false
    @EnvironmentObject private var appEnvironment: AppEnvironment
    private var debugSettings: DebugSettings {
        appEnvironment.debugSettings
    }
    
    // Get app version and build number from Info.plist
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
    @Environment(\.scenePhase) private var phase
    
    // Initialize connection monitor with debug settings
    init() {
        let debugSettings = DebugSettings()
        _connectionMonitor = StateObject(wrappedValue: ConnectionMonitor(debugSettings: debugSettings))
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.1, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if broadcastManager.isBroadcasting {
                // Clean Broadcasting Layout
                broadcastingView
            } else {
                // Pre-broadcast Layout
                defaultView
            }
            
            // Toast notification for saved broadcast
            if showBroadcastSavedToast {
                broadcastSavedToast
            }
        }
        .gesture(
            TapGesture(count: 3)
                .onEnded {
                    debugSettings.debugModeEnabled = true
                    showDebugMenu = true
                }
        )
        .background(
            BroadcastPickerHelper(
                extensionID: Constants.Broadcast.extensionID,
                broadcastButton: $broadcastButton
            )
            .frame(width: 0, height: 0)
        )
        .onAppear(perform: handleAppear)
        .onChange(of: phase) { _, newValue in
            handlePhaseChange(newValue)
        }
        .onChange(of: broadcastManager.isBroadcasting) { _, isNowBroadcasting in
            handleBroadcastStateChange(isNowBroadcasting)
        }
        .onChange(of: broadcastManager.lastRecordingURL) { _, url in
            handleNewRecording(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .frameSentToServer)) { _ in
            connectionMonitor.incrementFramesSent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .frameAcknowledgedByServer)) { _ in
            connectionMonitor.incrementFramesAcknowledged()
        }
        .sheet(isPresented: $showQualitySettings) {
            QualitySelector(selectedQuality: $broadcastManager.qualityLevel)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsScreen(storageManager: broadcastManager.storageManager, appVersion: appVersion)
            }
        }
        .fullScreenCover(isPresented: $showRecentBroadcasts) {
            RecentBroadcastsScreen(storageManager: broadcastManager.storageManager)
        }
        .sheet(isPresented: $showDebugMenu) {
            NavigationView {
                DebugMenuScreen(debugSettings: debugSettings)
            }
        }
    }
    
    // MARK: - Broadcasting View (Clean & Focused)
    
    private var broadcastingView: some View {
        VStack(spacing: 24) {
            // Minimal top bar - just connection status
            HStack {
                ConnectionStatusView(connectionMonitor: connectionMonitor)
                    .scaleEffect(0.9)
                
                Spacer()
                
                // Settings - smaller and less prominent
                settingsButton
                    .scaleEffect(0.8)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Central broadcast status
            VStack(spacing: 20) {
                // Live indicator with session code
                VStack(spacing: 12) {
                    // Prominent LIVE indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                        
                        Text("LIVE")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.red)
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(BroadcastService.shared.formatTimeString(broadcastManager.elapsed))
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    // Session code - large and prominent
                    VStack(spacing: 8) {
                        Text("Session Code")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(broadcastManager.code)
                            .font(.system(size: 56, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(4)
                            .overlay(
                                // Subtle glow effect
                                Text(broadcastManager.code)
                                    .font(.system(size: 56, weight: .black, design: .monospaced))
                                    .foregroundColor(.crGold)
                                    .blur(radius: 8)
                                    .opacity(0.3)
                            )
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.crGold.opacity(0.8), .crGold.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                }
                
                // Simplified guide card
                simplifiedGuideCard
                
                // Quality indicator - compact
                compactQualityIndicator
            }
            
            Spacer()
            
            // Stop button - prominent but clean
            stopBroadcastButton
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Default View (Not Broadcasting)
    
    private var defaultView: some View {
        VStack(spacing: 20) {
            // Full top bar when not broadcasting
            HStack {
                Spacer()
                
                // Settings button
                Button(action: { showSettings = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                        Text("Settings")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.crNavy.opacity(0.8))
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.crGold, .crGold.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 3)
                    )
                }
                .buttonStyle(ClashRoyaleButtonStyle())
                
                // Debug menu button
                if debugSettings.debugModeEnabled {
                    Spacer().frame(width: 8)
                    
                    Button(action: { showDebugMenu = true }) {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.crNavy.opacity(0.7))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.red.opacity(0.5), lineWidth: 1.5)
                                    )
                            )
                    }
                }
                
                Spacer()
            }
            .padding(.top, 8)
            
            // Connection Monitor (always visible at top)
            ConnectionStatusView(connectionMonitor: connectionMonitor)
                .padding(.horizontal)
            
            Spacer()
            
            // Status section
            HStack(spacing: 12) {
                CapsuleLabel(text: "OFFLINE", color: .gray)
            }
            
            // Start broadcasting button
            Button(action: toggleBroadcast) {
                VStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                        .foregroundColor(.white)
                    Text("Start Broadcasting")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 24)
                .background(GoldButtonBackground())
            }
            .buttonStyle(.plain)
            
            // Recent Broadcasts button
            Button(action: {
                broadcastManager.storageManager.refreshBroadcasts()
                showRecentBroadcasts = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                    Text("Recent Broadcasts")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Color.crPurple)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.crPurpleLight, .crPurple.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 3)
                )
            }
            .buttonStyle(ClashRoyaleButtonStyle())
            
            // Version number at bottom
            Text(appVersion)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 8)
                .onTapGesture(count: 5) {
                    debugSettings.debugModeEnabled = true
                    showDebugMenu = true
                }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Component Views
    
    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var simplifiedGuideCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.crGold)
                
                Text("Welcome, Chief!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.crGold)
            }
            
            VStack(spacing: 8) {
                Text("Open")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("royaltrainer.com")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.crPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.crPurple.opacity(0.6), lineWidth: 1)
                            )
                    )
                
                Text("Enter your 4‑digit code above")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.crNavy.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.crGold.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var compactQualityIndicator: some View {
        HStack(spacing: 6) {
            let quality = broadcastManager.qualityLevel
            Image(systemName: quality.icon)
                .font(.system(size: 14))
                .foregroundColor(quality.color)
            
            Text(quality.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(quality.color)
            
            Text("Quality")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.2))
                .overlay(
                    Capsule()
                        .strokeBorder(broadcastManager.qualityLevel.color.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var stopBroadcastButton: some View {
        Button(action: toggleBroadcast) {
            HStack(spacing: 12) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text("Stop Broadcasting")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .red.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
            )
        }
        .buttonStyle(ClashRoyaleButtonStyle())
    }
    
    private var broadcastSavedToast: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("Broadcast saved")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 20)
        }
        .zIndex(100)
        .transition(.opacity)
    }
    
    // MARK: - Event Handlers
    
    private func handleAppear() {
        // Check initial state
        if broadcastManager.isBroadcasting && !isVideoPrepared && !debugSettings.disableVideoPreview {
            shouldSetupVideo = true
        }
        
        // Start connection monitoring
        connectionMonitor.startMonitoring()
    }
    
    private func handlePhaseChange(_ newValue: ScenePhase) {
        if newValue == .background {
            broadcastManager.stopIfNeeded()
            connectionMonitor.stopMonitoring()
        } else if newValue == .active {
            connectionMonitor.startMonitoring()
        }
    }
    
    private func handleBroadcastStateChange(_ isNowBroadcasting: Bool) {
        if Constants.FeatureFlags.enableDebugLogging {
            print("Broadcast state changed: \(isNowBroadcasting ? "started" : "stopped")")
        }
        
        if isNowBroadcasting {
            // Only setup video if preview is not disabled in debug settings
            if !debugSettings.disableVideoPreview {
                shouldSetupVideo = true
                isVideoPrepared = false
            }
            
            // Reset connection counters when starting broadcast
            connectionMonitor.resetCounters()
        } else {
            resetVideoState()
            
            // When broadcasting stops, refresh the broadcasts list after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Force refreshing broadcasts list after broadcast ended")
                }
                broadcastManager.storageManager.refreshBroadcasts()
            }
        }
    }
    
    private func handleNewRecording(_ url: URL?) {
        if let url = url {
            if Constants.FeatureFlags.enableDebugLogging {
                print("New recording available: \(url.lastPathComponent)")
            }
            
            // Show toast notification
            withAnimation {
                showBroadcastSavedToast = true
            }
            
            // Hide toast after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showBroadcastSavedToast = false
                }
            }
        }
    }
    
    private func toggleBroadcast() {
        // Pass debug settings to broadcast extension
        if debugSettings.useCustomServer && !debugSettings.customServerURL.isEmpty {
            UserDefaults(suiteName: Constants.Broadcast.groupID)?.set(
                debugSettings.useCustomServer,
                forKey: "debug_useCustomServer"
            )
            UserDefaults(suiteName: Constants.Broadcast.groupID)?.set(
                debugSettings.customServerURL,
                forKey: "debug_customServerURL"
            )
        }
        
        UserDefaults(suiteName: Constants.Broadcast.groupID)?.set(
            debugSettings.disableLocalRecording,
            forKey: "debug_disableLocalRecording"
        )
        
        BroadcastService.shared.toggleBroadcast(
            using: broadcastButton,
            manager: broadcastManager
        )
    }
    
    private func resetVideoState() {
        // Stop and clean up player
        player.pause()
        player.replaceCurrentItem(with: nil)
        isVideoPrepared = false
        
        // Stop PiP if active
        if pipManager.isPiPActive {
            pipManager.stopPiP()
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let frameSentToServer = Notification.Name("frameSentToServer")
    static let frameAcknowledgedByServer = Notification.Name("frameAcknowledgedByServer")
}
