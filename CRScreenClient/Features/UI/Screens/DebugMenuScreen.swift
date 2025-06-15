import SwiftUI

struct DebugMenuScreen: View {
    @ObservedObject var debugSettings: DebugSettings
    @Environment(\.dismiss) private var dismiss
    @State private var isResetAlertShown = false
    
    // For server URL input field
    @State private var serverURL: String
    @State private var customPort: String
    @State private var isURLValid = true
    @State private var urlValidationMessage = ""
    
    init(debugSettings: DebugSettings) {
        self.debugSettings = debugSettings
        // Initialize state with current values
        _serverURL = State(initialValue: debugSettings.customServerURL)
        _customPort = State(initialValue: debugSettings.customPort)
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.15, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with debug icon
                    HStack {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                        
                        Text("Debug Menu")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .padding(.top, 4)
                    }
                    .padding(.top, 30)
                    
                    // Settings Sections
                    securitySettingsSection
                    serverSettingsSection
                    connectionSettingsSection
                    recordingSettingsSection
                    debugFeatureTogglesSection
                    
                    // Reset button
                    Button(action: {
                        isResetAlertShown = true
                    }) {
                        Text("Reset All Debug Settings")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ClashRoyaleButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .alert("Reset Debug Settings", isPresented: $isResetAlertShown) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            debugSettings.resetToDefaults()
                            serverURL = debugSettings.customServerURL
                            customPort = debugSettings.customPort
                            validateURL()
                        }
                    } message: {
                        Text("Are you sure you want to reset all debug settings to their default values? Watermark will remain enabled for security.")
                    }
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
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
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitle("Debug Menu", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .onAppear {
            validateURL()
        }
    }
    
    // MARK: - Security Settings Section (NEW - FIRST SECTION)
    
    private var securitySettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section Header
            sectionHeader(icon: "shield.fill", title: "Security & Protection")
            
            // Settings Box with warning styling
            VStack(spacing: 16) {
                // Watermark toggle with warning
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("App Watermark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: $debugSettings.showWatermark)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ SECURITY WARNING:")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("Disabling the watermark removes leak protection from this beta build. The watermark prevents unauthorized distribution and helps track usage.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Contact: @royaltrainer_dev • contact@royaltrainer.com")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.crGold)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Current watermark status
                    HStack {
                        Image(systemName: debugSettings.showWatermark ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .foregroundColor(debugSettings.showWatermark ? .green : .red)
                        
                        Text("Watermark Status: \(debugSettings.showWatermark ? "ACTIVE" : "DISABLED")")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(debugSettings.showWatermark ? .green : .red)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(debugSettings.showWatermark ? Color.green : Color.red, lineWidth: 2)
                    )
            )
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Other Sections (Keep existing sections but add them here...)
    
    private var serverSettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section Header
            sectionHeader(icon: "network", title: "Server Configuration")
            
            // Settings Box with Clash Royale styling
            VStack(spacing: 16) {
                // Toggle for using custom server
                Toggle(isOn: $debugSettings.useCustomServer) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Custom Server")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enable this to connect to your own WebRTC signaling server instead of the default")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .crGold))
                
                // Server URL input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    TextField("api.tormentor.dev or myserver.com", text: $serverURL)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    debugSettings.useCustomServer ?
                                    (isURLValid ? Color.crGold.opacity(0.7) : Color.red.opacity(0.7)) :
                                    Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .foregroundColor(.white)
                        .disabled(!debugSettings.useCustomServer)
                        .opacity(debugSettings.useCustomServer ? 1.0 : 0.6)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                        .onChange(of: serverURL) { newValue in
                            debugSettings.customServerURL = newValue
                            validateURL()
                        }
                    
                    // URL validation message
                    if debugSettings.useCustomServer && !urlValidationMessage.isEmpty {
                        HStack {
                            Image(systemName: isURLValid ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundColor(isURLValid ? .green : .orange)
                            Text(urlValidationMessage)
                                .font(.system(size: 13))
                                .foregroundColor(isURLValid ? .green : .orange)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // Port configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Port (optional):")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    TextField("443", text: $customPort)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(debugSettings.useCustomServer ? Color.crGold.opacity(0.7) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                        .disabled(!debugSettings.useCustomServer)
                        .opacity(debugSettings.useCustomServer ? 1.0 : 0.6)
                        .keyboardType(.numberPad)
                        .onChange(of: customPort) { newValue in
                            debugSettings.customPort = newValue
                        }
                }
                
                // Display current effective URLs
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Configuration:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        urlDisplayRow("WebRTC:", debugSettings.effectiveWebRTCURL)
                        urlDisplayRow("HTTP:", debugSettings.effectiveServerURL)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.2))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.bottom, 10)
        }
    }
    
    private var connectionSettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section Header
            sectionHeader(icon: "wifi", title: "Connection Settings")
            
            // Settings Box
            VStack(spacing: 16) {
                // Secure connection preference
                Toggle(isOn: $debugSettings.preferSecureConnection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prefer Secure Connection")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Use WSS (secure WebSocket) and HTTPS when possible")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .crGold))
                
                // Connection status info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection Information:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        connectionInfoRow("Protocol:", debugSettings.preferSecureConnection ? "Secure (WSS/HTTPS)" : "Standard (WS/HTTP)")
                        connectionInfoRow("Port:", customPort.isEmpty ? "Default (443)" : customPort)
                        connectionInfoRow("Status:", debugSettings.useCustomServer ? "Custom Server" : "Default Server")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.bottom, 10)
        }
    }
    
    private var recordingSettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section Header
            sectionHeader(icon: "video.fill", title: "Recording Settings")
            
            // Settings Box with Clash Royale styling
            VStack(spacing: 16) {
                // Toggle for disabling video preview
                Toggle(isOn: $debugSettings.disableVideoPreview) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disable Video Preview")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Hides the video player during broadcasting to save resources")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .crGold))
                
                // Toggle for disabling local recording
                Toggle(isOn: $debugSettings.disableLocalRecording) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disable Local Recording")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("ENABLED: No video recording, broadcast-only mode for optimal performance")
                            .font(.system(size: 14))
                            .foregroundColor(.crGold) // Use gold color to indicate this is the recommended setting
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .crGold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.bottom, 10)
        }
    }
    
    private var debugFeatureTogglesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section Header
            sectionHeader(icon: "gearshape.fill", title: "Debug Features")
            
            // Settings Box with Clash Royale styling
            VStack(spacing: 16) {
                // Toggle for debug mode
                Toggle(isOn: $debugSettings.debugModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Debug Mode")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enables additional debug logging and features throughout the app")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .crGold))
                
                // Information about current build and configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Information:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        statusRow(title: "Build Type:", value: "Debug", icon: "hammer.fill")
                        statusRow(title: "App Version:", value: getAppVersionString(), icon: "app.badge.fill")
                        statusRow(title: "Device:", value: UIDevice.current.model, icon: "iphone")
                        statusRow(title: "iOS Version:", value: UIDevice.current.systemVersion, icon: "apple.logo")
                        statusRow(title: "WebRTC:", value: Constants.FeatureFlags.enableWebRTC ? "Enabled" : "Disabled", icon: "network")
                        statusRow(title: "Watermark:", value: debugSettings.showWatermark ? "ACTIVE" : "DISABLED", icon: "shield.fill")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                )
                
                // Server configuration summary
                if debugSettings.debugModeEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Server Configuration:")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.crGold)
                        
                        let config = debugSettings.getServerConfiguration()
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(config.keys.sorted()), id: \.self) { key in
                                if let value = config[key] {
                                    configRow(key: key, value: "\(value)")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.crGold)
            
            Text(title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .padding(.horizontal, 20)
    }
    
    private func urlDisplayRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.crGold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func connectionInfoRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func statusRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.crGold)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(title == "Watermark:" ? (value == "ACTIVE" ? .green : .red) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func configRow(key: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(key.replacingOccurrences(of: "effective", with: "").capitalized + ":")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.crGold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateURL() {
        let validation = debugSettings.validateServerURL()
        isURLValid = validation.isValid
        urlValidationMessage = validation.message
    }
    
    private func getAppVersionString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
