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
                // Player View
                if broadcastManager.isBroadcasting {
                    videoPlayerSection
                }
                
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
            }
            .padding(.horizontal)
            .sheet(isPresented: $showQualitySettings) {
                QualitySelector(selectedQuality: $broadcastManager.qualityLevel)
                    .interactiveDismissDisabled()
            }
        }
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
        .onChange(of: shouldSetupVideo) { _, shouldSetup in
            handleSetupVideoChange(shouldSetup)
        }
    }
    
    // MARK: - View Components
    
    private var videoPlayerSection: some View {
        VStack(spacing: 0) {
            if isVideoPrepared {
                PlayerView(player: player) { layer in
                    if Constants.FeatureFlags.enablePictureInPicture {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            pipManager.setup(with: layer)
                        }
                    }
                }
                .frame(height: 200)
                .cornerRadius(Constants.UI.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .stroke(Color.crGold, lineWidth: 2)
                )
                .padding(.horizontal)
            } else {
                // Loading placeholder
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 200)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                            .stroke(Color.crGold, lineWidth: 2)
                    )
                    .padding(.horizontal)
            }
            
            // Quality indicator during broadcast
            if broadcastManager.isBroadcasting {
                qualityIndicator
                    .padding(.top, 6)
            }
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
                            .strokeBorder(broadcastManager.qualityLevel.color.opacity(0.5), lineWidth: 1)
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
            
            // PiP Button - only show if feature flag is enabled
            if Constants.FeatureFlags.enablePictureInPicture &&
               broadcastManager.isBroadcasting &&
               isVideoPrepared {
                Button(action: {
                    pipManager.togglePiP()
                }) {
                    Label(
                        pipManager.isPiPActive ? "Exit Picture-in-Picture" : "Enter Picture-in-Picture",
                        systemImage: pipManager.isPiPActive ? "pip.exit" : "pip.enter"
                    )
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.crPurple)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                }
                .disabled(!pipManager.isPiPPossible)
                .opacity(pipManager.isPiPPossible ? 1.0 : 0.5)
                .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleAppear() {
        if broadcastManager.isBroadcasting && !isVideoPrepared {
            shouldSetupVideo = true
        }
    }
    
    private func handlePhaseChange(_ newValue: ScenePhase) {
        if newValue == .background {
            broadcastManager.stopIfNeeded()
        }
    }
    
    private func handleBroadcastStateChange(_ isNowBroadcasting: Bool) {
        if isNowBroadcasting {
            shouldSetupVideo = true
            isVideoPrepared = false
        } else {
            resetVideoState()
        }
    }
    
    private func handleSetupVideoChange(_ shouldSetup: Bool) {
        if shouldSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                VideoService.setupDemoVideo(
                    player: player,
                    useLocalOnly: Constants.FeatureFlags.useLocalVideoOnly
                ) {
                    isVideoPrepared = true
                }
                shouldSetupVideo = false
            }
        }
    }
    
    private func toggleBroadcast() {
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
