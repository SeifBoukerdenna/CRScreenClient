import SwiftUI
import WebRTC
import UIKit

struct WebRTCPlayerView: UIViewRepresentable {
    let webRTCManager: WebRTCManager
    var onRendererCreated: ((RTCVideoRenderer) -> Void)?
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.videoContentMode = .scaleAspectFit
        videoView.backgroundColor = .black
        
        // Create frame counting renderer
        let frameCountingRenderer = FrameCountingVideoRenderer(
            actualRenderer: videoView,
            webRTCManager: webRTCManager
        )
        
        // Set up the renderer with WebRTC manager
        webRTCManager.setVideoRenderer(frameCountingRenderer)
        
        // Notify that renderer was created
        onRendererCreated?(frameCountingRenderer)
        
        return videoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Update video content mode based on connection state
        if webRTCManager.isConnected {
            uiView.videoContentMode = .scaleAspectFit
        } else {
            uiView.videoContentMode = .scaleAspectFill
        }
    }
    
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        // Clean up renderer when view is dismantled
        // The WebRTCManager will handle cleanup
    }
}

// MARK: - WebRTC Connection Status View
struct WebRTCConnectionStatusView: View {
    @ObservedObject var webRTCManager: WebRTCManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .scaleEffect(webRTCManager.isConnected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: webRTCManager.isConnected)
            
            Text(connectionText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            if webRTCManager.isConnected {
                Text("• \(webRTCManager.receivedFrameCount) frames")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(connectionColor.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var connectionColor: Color {
        switch webRTCManager.connectionState {
        case .connected, .completed:
            return .green
        case .checking:
            return .yellow
        case .disconnected, .failed, .closed:
            return .red
        default:
            return .gray
        }
    }
    
    private var connectionText: String {
        if webRTCManager.isConnected {
            return "WebRTC Connected"
        } else {
            switch webRTCManager.connectionState {
            case .checking:
                return "Connecting..."
            case .disconnected:
                return "Disconnected"
            case .failed:
                return "Connection Failed"
            case .closed:
                return "Connection Closed"
            default:
                return "Not Connected"
            }
        }
    }
}

// MARK: - WebRTC Debug Info View
struct WebRTCDebugInfoView: View {
    @ObservedObject var webRTCManager: WebRTCManager
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showDetails.toggle() }) {
                HStack {
                    Text("WebRTC Debug Info")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                }
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    debugRow("Connection State:", webRTCManager.connectionState.description)
                    debugRow("Is Connected:", webRTCManager.isConnected ? "Yes" : "No")
                    debugRow("Frames Received:", "\(webRTCManager.receivedFrameCount)")
                    debugRow("Has Remote Track:", webRTCManager.remoteVideoTrack != nil ? "Yes" : "No")
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private func debugRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - RTCIceConnectionState Extension
extension RTCIceConnectionState {
    var description: String {
        switch self {
        case .new:
            return "New"
        case .checking:
            return "Checking"
        case .connected:
            return "Connected"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .disconnected:
            return "Disconnected"
        case .closed:
            return "Closed"
        case .count:
            return "Count"
        @unknown default:
            return "Unknown"
        }
    }
}
