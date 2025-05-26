import SwiftUI
import AVKit
import ReplayKit
import Combine

struct MainScreen: View {
    @StateObject private var broadcastManager = BroadcastManager()
    @StateObject private var pipManager = PiPManager()
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
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.1, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Top bar with settings button and debug button
                topBarSection
                
                // Video player section - demo video or broadcast status
                videoPlayerSection
                
                // Status indicators
                statusSection
                
                // Session Code
                if broadcastManager.isBroadcasting {
                    sessionCodeSection
                    GuideCard()
                }
                
                // Quality selector button (before broadcast)
                if !broadcastManager.isBroadcasting {
                    qualityButton
                }
                
                // Action buttons
                actionButtonsSection
                
                // Version number at bottom
                Text(appVersion)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 8)
                    .onTapGesture(count: 5) {
                        debugSettings.debugModeEnabled = true
                        showDebugMenu = true
                    }
            }
            .padding(.horizontal)
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
    }
    
    // MARK: - View Components
    
    private var topBarSection: some View {
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
    }
    
    private var videoPlayerSection: some View {
        VStack(spacing: 8) {
            if broadcastManager.isBroadcasting && !debugSettings.disableVideoPreview {
                // Show broadcast status when this device is broadcasting
                broadcastStatusView
                
            } else if broadcastManager.isBroadcasting && debugSettings.disableVideoPreview {
                // Show placeholder when video is disabled
                Text("Video Preview Disabled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
                    .padding(.top, 10)
                    
            } else {
                // When not broadcasting, add some space
                Spacer().frame(height: 20)
            }
        }
    }
    
    private var broadcastStatusView: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.crBlue.opacity(0.3), .crNavy.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 200)
                .cornerRadius(Constants.UI.cornerRadius)
                .overlay(
                    VStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundColor(.crGold)
                        
                        Text("Broadcasting Active")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Screen is being streamed via WebRTC")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Session: \(broadcastManager.code)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.crGold)
                            .padding(.top, 8)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .stroke(Color.crGold, lineWidth: 2)
                )
                .padding(.horizontal)
            
            qualityIndicator
        }
    }
    
    private var qualityIndicator: some View {
        HStack(spacing: 4) {
            let quality = broadcastManager.qualityLevel
            Image(systemName: quality.icon)
                .font(.system(size: 16))
                .foregroundColor(quality.color)
            
            Text("Streaming Quality: ")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Text(quality.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(quality.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Capsule()
                        .strokeBorder(broadcastManager.qualityLevel.color.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var statusSection: some View {
        HStack(spacing: 12) {
            CapsuleLabel(
                text: broadcastManager.isBroadcasting ? "LIVE" : "OFFLINE",
                color: broadcastManager.isBroadcasting ? .red : .gray
            )
            if broadcastManager.isBroadcasting {
                CapsuleLabel(
                    text: BroadcastService.shared.formatTimeString(broadcastManager.elapsed),
                    color: .crGold.opacity(0.9)
                )
                
                CapsuleLabel(
                    text: "WebRTC",
                    color: .green
                )
            }
            
            // Show debug indicator if debug mode is enabled
            if debugSettings.debugModeEnabled && broadcastManager.isBroadcasting {
                CapsuleLabel(
                    text: "DEBUG",
                    color: .red.opacity(0.7)
                )
            }
        }
    }
    
    private var sessionCodeSection: some View {
        VStack(spacing: 6) {
            Text("Session Code")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            Text(broadcastManager.code)
                .font(.system(
                    size: 48,
                    weight: .heavy,
                    design: .monospaced
                ))
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.crGold.opacity(0.5), lineWidth: 2)
                        .blur(radius: 4)
                        .opacity(0.7)
                        .mask(
                            Text(broadcastManager.code)
                                .font(.system(
                                    size: 48,
                                    weight: .heavy,
                                    design: .monospaced
                                ))
                                .foregroundColor(.white)
                        )
                )
        }
    }
    
    private var qualityButton: some View {
        Button(action: {
            showQualitySettings = true
        }) {
            HStack(spacing: 8) {
                let quality = broadcastManager.qualityLevel
                Image(systemName: quality.icon)
                    .font(.system(size: 18))
                    .foregroundColor(quality.color)
                
                Text("Quality: \(quality.title)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(Color.crNavy.opacity(0.7))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [broadcastManager.qualityLevel.color, broadcastManager.qualityLevel.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(ClashRoyaleButtonStyle())
        .padding(.top, -8)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Start/Stop button
            Button(action: toggleBroadcast) {
                VStack(spacing: 8) {
                    Image(systemName: broadcastManager.isBroadcasting
                          ? "stop.fill"
                          : "dot.radiowaves.left.and.right")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                        .foregroundColor(.white)
                    Text(broadcastManager.isBroadcasting ? "Stop Broadcasting"
                                           : "Start Broadcasting")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 24)
                .background(GoldButtonBackground())
            }
            .buttonStyle(.plain)
            
            // Recent Broadcasts button (only when not broadcasting)
            if !broadcastManager.isBroadcasting {
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
            }
        }
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
    }
    
    private func handlePhaseChange(_ newValue: ScenePhase) {
        if newValue == .background {
            broadcastManager.stopIfNeeded()
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
