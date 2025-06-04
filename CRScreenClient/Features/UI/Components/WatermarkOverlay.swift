// CRScreenClient/Features/UI/Components/WatermarkOverlay.swift
import SwiftUI
import UIKit

class WatermarkManager: ObservableObject {
    static let shared = WatermarkManager()
    @Published var debugSettings: DebugSettings?
    
    private init() {}
    
    func configure(with settings: DebugSettings) {
        self.debugSettings = settings
    }
}

struct WatermarkOverlay: View {
    @ObservedObject var debugSettings: DebugSettings
    @State private var randomPositions: [(x: Double, y: Double, rotation: Double)] = []
    @State private var deviceInfo: String = ""
    @State private var animationOffset: Double = 0
    
    var body: some View {
        if debugSettings.showWatermark {
            ZStack {
                // Random positioned watermarks
                randomWatermarkPattern
                
                // Device info watermark (center)
                deviceInfoWatermark
                
                // Moving watermarks
                animatedWatermarkPattern
            }
            .allowsHitTesting(false)
            .opacity(0.35) // Much more prominent
            .onAppear {
                generateRandomPositions()
                generateDeviceInfo()
                startAnimation()
            }
        }
    }
    
    private var randomWatermarkPattern: some View {
        GeometryReader { geometry in
            ZStack {
                // Generate 20-25 random watermarks
                ForEach(Array(randomPositions.enumerated()), id: \.offset) { index, position in
                    watermarkText(variant: index % 4)
                        .position(
                            x: geometry.size.width * position.x,
                            y: geometry.size.height * position.y
                        )
                        .rotationEffect(.degrees(position.rotation))
                }
            }
        }
    }
    
    private var deviceInfoWatermark: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Text("🔒 BETA BUILD 🔒")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                
                Text(deviceInfo)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("@royaltrainer_dev")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                
                Text("contact@royaltrainer.com")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.red.opacity(0.8), lineWidth: 2)
                    )
            )
            .position(
                x: geometry.size.width * 0.5,
                y: geometry.size.height * 0.5
            )
        }
    }
    
    private var animatedWatermarkPattern: some View {
        GeometryReader { geometry in
            ZStack {
                // 5 moving watermarks
                ForEach(0..<5, id: \.self) { index in
                    watermarkText(variant: index + 5)
                        .position(
                            x: geometry.size.width * (0.2 + Double(index) * 0.15 + animationOffset * 0.1),
                            y: geometry.size.height * (0.15 + Double(index) * 0.15 + animationOffset * 0.05)
                        )
                        .rotationEffect(.degrees(animationOffset * 30 + Double(index * 72)))
                        .opacity(0.2)
                }
            }
        }
    }
    
    private func watermarkText(variant: Int) -> some View {
        VStack(spacing: 2) {
            // Alternate between different warning messages
            switch variant % 4 {
            case 0:
                Text("⚠️ BETA BUILD ⚠️")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                Text("DO NOT DISTRIBUTE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)
            case 1:
                Text("@royaltrainer_dev")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                Text("contact@royaltrainer.com")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            case 2:
                Text("🚫 UNAUTHORIZED 🚫")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                Text("USAGE PROHIBITED")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)
            default:
                Text("ROYAL TRAINER BETA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("INTERNAL BUILD")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.5))
                .blur(radius: 0.5)
        )
    }
    
    private func generateRandomPositions() {
        randomPositions = []
        
        // Generate 20-25 truly random positions
        for _ in 0..<Int.random(in: 5...15) {
            let position = (
                x: Double.random(in: 0.05...0.95),
                y: Double.random(in: 0.05...0.95),
                rotation: Double.random(in: -90...90)
            )
            randomPositions.append(position)
        }
        
        // Ensure corners are always covered
        randomPositions.append((x: 0.9, y: 0.1, rotation: -15))
        randomPositions.append((x: 0.1, y: 0.9, rotation: 15))
        randomPositions.append((x: 0.9, y: 0.9, rotation: -15))
        randomPositions.append((x: 0.1, y: 0.1, rotation: 15))
    }
    
    private func generateDeviceInfo() {
        let device = UIDevice.current
        let uuid = device.identifierForVendor?.uuidString ?? "UNKNOWN-UUID"
        let shortUUID = String(uuid.prefix(8))
        
        // Get more detailed device info
        let modelName = getDeviceModelName()
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "MM/dd HH:mm"
        }.string(from: Date())
        
        deviceInfo = """
        \(modelName)
        iOS \(device.systemVersion)
        UUID: \(shortUUID)
        \(timestamp)
        """
    }
    
    private func getDeviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Map common identifiers to readable names
        switch identifier {
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        default:
            if identifier.contains("iPhone") { return "iPhone" }
            if identifier.contains("iPad") { return "iPad" }
            return UIDevice.current.model
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: true)) {
            animationOffset = 1.0
        }
    }
}

// Extension for DateFormatter
extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

// MARK: - Wrapper View for Entire App
struct WatermarkedAppView<Content: View>: View {
    let content: Content
    @ObservedObject var debugSettings: DebugSettings
    
    init(debugSettings: DebugSettings, @ViewBuilder content: () -> Content) {
        self.debugSettings = debugSettings
        self.content = content()
        
        // Configure global watermark manager
        WatermarkManager.shared.configure(with: debugSettings)
    }
    
    var body: some View {
        ZStack {
            // Main app content
            content
            
            // Watermark overlay on top
            WatermarkOverlay(debugSettings: debugSettings)
        }
    }
}
