// SettingsScreen.swift
import SwiftUI


struct SettingsScreen: View {
    @ObservedObject var storageManager: BroadcastStorageManager
    @State private var maxBroadcasts: Int
    @Environment(\.dismiss) private var dismiss
    var appVersion: String
    
    // Range of allowed values for max broadcasts
    private let broadcastRangeOptions = [5, 10, 15, 20, 25, 30]
    
    init(storageManager: BroadcastStorageManager, appVersion: String = "v0.1 (1)") {
        self.storageManager = storageManager
        self.appVersion = appVersion
        // Initialize state with current value from UserDefaults
        let savedMax = UserDefaults.standard.integer(forKey: "maxBroadcasts")
        _maxBroadcasts = State(initialValue: savedMax > 0 ? savedMax : 10)
    }
    
    var body: some View {
        ZStack {
            // Background gradient like Clash Royale
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.15, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text("Settings")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .padding(.top, 30)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 2)
                    
                    // Storage Settings Section
                    settingsSection
                    
                    // About Section
                    aboutSection
                    
                    // Version Info - now using the automatic version from project
                    versionInfo
                    
                    Spacer(minLength: 30)
                    
                    // Done button with Clash Royale style
                    Button(action: {
                        // Save settings and update manager
                        UserDefaults.standard.set(maxBroadcasts, forKey: "maxBroadcasts")
                        storageManager.refreshBroadcasts()
                        dismiss()
                    }) {
                        Text("DONE")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Color.crBrown)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.crGold)
                                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.crBrown, lineWidth: 3)
                            )
                    }
                    .buttonStyle(ClashRoyaleButtonStyle())
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
    
    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Header with gold icon
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.crGold)
                
                Text("Storage Settings")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Settings Box with Clash Royale styling
            VStack(spacing: 16) {
                HStack {
                    Text("Maximum Recent Broadcasts")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Picker with Clash Royale styling
                    Picker("", selection: $maxBroadcasts) {
                        ForEach(broadcastRangeOptions, id: \.self) { number in
                            Text("\(number)").tag(number)
                                .foregroundColor(.white)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .background(
                        Capsule()
                            .fill(Color.crNavy.opacity(0.7))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.crGold.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .padding(.trailing, 8)
                }
                
                // Help Text
                Text("Sets how many recent broadcast recordings to keep. When this limit is reached, oldest recordings will be automatically deleted to free up space.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 8)
                
                // Current Storage Stats with Clash Royale styling
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tv.fill")
                                .foregroundColor(.crGold)
                            Text("Current Broadcasts:")
                                .foregroundColor(.white.opacity(0.9))
                            Text("\(storageManager.broadcasts.count)")
                                .foregroundColor(.crGold)
                                .fontWeight(.bold)
                        }
                        
                        if let oldestBroadcast = storageManager.broadcasts.last {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.crGold)
                                Text("Oldest Recording:")
                                    .foregroundColor(.white.opacity(0.9))
                                Text(oldestBroadcast.formattedDate)
                                    .foregroundColor(.crGold)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .font(.system(size: 15))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 20)
    }
    
    private var aboutSection: some View {
        VStack(spacing: 0) {
            // About header with gold icon
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.crGold)
                
                Text("About Royal Trainer")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // About Box with Clash Royale styling
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.crGold)
                    .padding(.top, 8)
                
                Text("Royal Trainer")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.crGold)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                
                Text("Broadcast your games and share your gameplay with coaches and friends. Improve your skills with real-time feedback and strategy analysis.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Feature list
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "dot.radiowaves.left.and.right", text: "Screen Broadcasting")
                    featureRow(icon: "pip.enter", text: "Picture-in-Picture Support")
                    featureRow(icon: "tv.fill", text: "Recording Management")
                    featureRow(icon: "dial.min", text: "Adjustable Stream Quality")
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                )
                .padding(.bottom, 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 12)
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.crGold)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text("Royal Trainer \(appVersion)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text("© 2025 Elmelz")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 20)
    }
}
