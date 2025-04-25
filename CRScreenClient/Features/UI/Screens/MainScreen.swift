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
    
    @Environment(\.scenePhase) private var phase
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.crBlue, .crBlue.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Player View
                if broadcastManager.isBroadcasting {
                    videoPlayerSection
                }
                
                // Status indicators
                statusSection
                
                // Session Code
                if broadcastManager.isBroadcasting {
                    sessionCodeSection
                }
                
                // Guide
                GuideCard()
                
                // Action buttons
                actionButtonsSection
            }
            .padding(.horizontal)
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
        Group {
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
        }
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
        }
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
