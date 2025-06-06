// SettingsScreen.swift
import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var storageManager: BroadcastStorageManager
    @State private var maxBroadcasts: Int
    @Environment(\.dismiss) private var dismiss
    var appVersion: String
    
    // Enhanced streaming controls
    @State private var frameRatio: Double = 1.0 // 1:1, 1:2, 1:3, etc.
    @State private var imageQuality: Double = 0.6 // 0.1 to 1.0
    @State private var customBitrate: Double = 800000 // Custom bitrate in bps
    @State private var resolutionScale: Double = 0.8 // 0.1 to 1.0
    
    // Frame ratio options for picker
    private let frameRatioOptions: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
    private let broadcastRangeOptions = [5, 10, 15, 20, 25, 30]
    
    init(storageManager: BroadcastStorageManager, appVersion: String = "v0.1 (1)") {
        self.storageManager = storageManager
        self.appVersion = appVersion
        
        let savedMax = UserDefaults.standard.integer(forKey: "maxBroadcasts")
        _maxBroadcasts = State(initialValue: savedMax > 0 ? savedMax : 10)
        
        // Load custom streaming settings
        _frameRatio = State(initialValue: UserDefaults.standard.double(forKey: "customFrameRatio") > 0 ? UserDefaults.standard.double(forKey: "customFrameRatio") : 1.0)
        _imageQuality = State(initialValue: UserDefaults.standard.double(forKey: "customImageQuality") > 0 ? UserDefaults.standard.double(forKey: "customImageQuality") : 0.6)
        _customBitrate = State(initialValue: UserDefaults.standard.double(forKey: "customBitrate") > 0 ? UserDefaults.standard.double(forKey: "customBitrate") : 800000)
        _resolutionScale = State(initialValue: UserDefaults.standard.double(forKey: "customResolutionScale") > 0 ? UserDefaults.standard.double(forKey: "customResolutionScale") : 0.8)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.15, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .padding(.top, 30)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 2)
                    
                    // Enhanced Streaming Controls Section
                    streamingControlsSection
                    
                    // About Section
                    aboutSection
                    
                    // Version Info
                    versionInfo
                    
                    Spacer(minLength: 30)
                    
                    // Done button
                    Button(action: saveSettingsAndDismiss) {
                        Text("SAVE SETTINGS")
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
    
    // MARK: - Enhanced Streaming Controls Section
    
    private var streamingControlsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "video.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.crGold)
                
                Text("Streaming Controls")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            VStack(spacing: 20) {
                // Frame Rate Control
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Frame Processing Ratio")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("1:\(Int(frameRatio))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.crGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.crNavy.opacity(0.7))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.crGold.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Slider(value: $frameRatio, in: 1...60, step: 1) {
                        Text("Frame Ratio")
                    } minimumValueLabel: {
                        Text("1:1")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    } maximumValueLabel: {
                        Text("1:60")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accentColor(.crGold)
                    
                    Text("Send every \(Int(frameRatio)) frame\(frameRatio > 1 ? "s" : "") (Higher = Lower CPU usage)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Image Quality Control
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Image Compression Quality")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(imageQuality * 100))%")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.crPurple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.crNavy.opacity(0.7))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.crPurple.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Slider(value: $imageQuality, in: 0.1...1.0, step: 0.05) {
                        Text("Image Quality")
                    } minimumValueLabel: {
                        Text("10%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    } maximumValueLabel: {
                        Text("100%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accentColor(.crPurple)
                    
                    Text("Higher quality = Larger file sizes and more bandwidth")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Resolution Scale Control
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Resolution Scale")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(resolutionScale * 100))%")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.crNavy.opacity(0.7))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Slider(value: $resolutionScale, in: 0.3...1.0, step: 0.05) {
                        Text("Resolution Scale")
                    } minimumValueLabel: {
                        Text("30%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    } maximumValueLabel: {
                        Text("100%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accentColor(.blue)
                    
                    Text("Scales the output resolution (Lower = Better performance)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Custom Bitrate Control
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Video Bitrate")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(formatBitrate(customBitrate))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.crNavy.opacity(0.7))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Slider(value: $customBitrate, in: 200000...2000000, step: 100000) {
                        Text("Bitrate")
                    } minimumValueLabel: {
                        Text("200k")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    } maximumValueLabel: {
                        Text("2M")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accentColor(.green)
                    
                    Text("Controls video quality and bandwidth usage")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Real-time Preview Info
                VStack(spacing: 8) {
                    Text("Current Settings Preview")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.crGold)
                    
                    HStack(spacing: 16) {
                        VStack {
                            Text("Effective FPS")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text("~\(Int(30 / frameRatio))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Quality Level")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text(getQualityDescription())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Est. Bandwidth")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text(formatBitrate(customBitrate))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.vertical, 12)
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
    

    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(spacing: 0) {
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
            
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.crGold)
                    .padding(.top, 8)
                
                Text("Royal Trainer")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.crGold)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                
                Text("Broadcast your games with customizable quality settings. Fine-tune frame rates, compression, and resolution for optimal performance.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "dot.radiowaves.left.and.right", text: "Real-time Screen Broadcasting")
                    featureRow(icon: "slider.horizontal.3", text: "Advanced Quality Controls")
                    featureRow(icon: "tv.fill", text: "Recording Management")
                    featureRow(icon: "speedometer", text: "Performance Optimization")
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
    
    // MARK: - Helper Methods
    
    private func saveSettingsAndDismiss() {
        // Save all settings
        UserDefaults.standard.set(maxBroadcasts, forKey: "maxBroadcasts")
        UserDefaults.standard.set(frameRatio, forKey: "customFrameRatio")
        UserDefaults.standard.set(imageQuality, forKey: "customImageQuality")
        UserDefaults.standard.set(customBitrate, forKey: "customBitrate")
        UserDefaults.standard.set(resolutionScale, forKey: "customResolutionScale")
        
        // Save to app group for broadcast extension access
        let groupDefaults = UserDefaults(suiteName: "group.com.elmelz.crcoach")
        groupDefaults?.set(frameRatio, forKey: "customFrameRatio")
        groupDefaults?.set(imageQuality, forKey: "customImageQuality")
        groupDefaults?.set(customBitrate, forKey: "customBitrate")
        groupDefaults?.set(resolutionScale, forKey: "customResolutionScale")
        
        storageManager.refreshBroadcasts()
        dismiss()
    }
    
    private func formatBitrate(_ bitrate: Double) -> String {
        if bitrate >= 1000000 {
            return String(format: "%.1f Mbps", bitrate / 1000000)
        } else {
            return String(format: "%.0f Kbps", bitrate / 1000)
        }
    }
    
    private func getQualityDescription() -> String {
        switch imageQuality {
        case 0.8...1.0:
            return "Excellent"
        case 0.6..<0.8:
            return "High"
        case 0.4..<0.6:
            return "Medium"
        case 0.2..<0.4:
            return "Low"
        default:
            return "Basic"
        }
    }
}
