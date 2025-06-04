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
    @State private var deviceInfo: String = ""
    @State private var animationOffset: Double = 0
    
    var body: some View {
        if debugSettings.showWatermark {
            ZStack {
                // Repeating grid pattern like stock photos
                repeatingWatermarkGrid
            }
            .allowsHitTesting(false)
            .opacity(0.4) // Very prominent
            .onAppear {
                generateDeviceInfo()
                startAnimation()
            }
        }
    }
    
    private var repeatingWatermarkGrid: some View {
        GeometryReader { geometry in
            let watermarkWidth: CGFloat = 200
            let watermarkHeight: CGFloat = 120
            let spacing: CGFloat = 80
            
            let columns = Int((geometry.size.width + spacing) / (watermarkWidth + spacing)) + 2
            let rows = Int((geometry.size.height + spacing) / (watermarkHeight + spacing)) + 2
            
            ZStack {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { column in
                        let isEvenRow = row % 2 == 0
                        let xOffset = isEvenRow ? 0 : watermarkWidth / 2
                        
                        watermarkPattern
                            .position(
                                x: CGFloat(column) * (watermarkWidth + spacing) + watermarkWidth/2 + xOffset + animationOffset * 10,
                                y: CGFloat(row) * (watermarkHeight + spacing) + watermarkHeight/2 + animationOffset * 5
                            )
                            .rotationEffect(.degrees(-25 + animationOffset * 2))
                    }
                }
            }
        }
    }
    
    private var watermarkPattern: some View {
        VStack(spacing: 3) {
            Text("🔒 BETA BUILD 🔒")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.red)
            
            Text(deviceInfo)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("@royaltrainer_dev")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
            
            Text("contact@royaltrainer.com")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.orange)
            
            Text("DO NOT DISTRIBUTE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.red)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.red.opacity(0.7), lineWidth: 1)
                )
        )
    }
    
    private func watermarkText(variant: Int) -> some View {
        // Removed - no longer needed
        EmptyView()
    }
    
    private func generateRandomPositions() {
        // Removed - no longer needed
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
