import SwiftUI
import ReplayKit

extension Color {
    static let crBlue   = Color(red: 0/255,   green: 114/255, blue: 206/255)
    static let crGold   = Color(red: 255/255, green: 215/255, blue:   0/255)
    static let crBrown  = Color(red: 107/255, green:  73/255, blue:  36/255)
}


struct ContentView: View {
    @State private var broadcastButton: UIButton? = nil
    @State private var isBroadcasting = false

    var body: some View {
        ZStack {
            // Royale blue background with slight vignette
            LinearGradient(
                colors: [Color.crBlue, Color.crBlue.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Status badge
                Text(isBroadcasting ? "LIVE" : "OFFLINE")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isBroadcasting ? Color.red : Color.gray.opacity(0.6))
                    )

                // Big CR‑style button
                Button(action: toggleBroadcast) {
                    VStack(spacing: 8) {
                        Image(systemName: isBroadcasting ? "stop.fill" : "dot.radiowaves.left.and.right")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .foregroundColor(.white)

                        Text(isBroadcasting ? "Stop Broadcasting" : "Start Broadcasting")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.crGold)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.crBrown, lineWidth: 6)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        // hidden Broadcast‑picker helper
        .background(
            BroadcastPickerHelper(
                extensionID: "com.elmelz.CRScreenClient.CRScreenClientBroadcast",
                broadcastButton: $broadcastButton
            )
            .frame(width: 0, height: 0)
        )
    }

    private func toggleBroadcast() {
        broadcastButton?.sendActions(for: .touchUpInside)
        isBroadcasting.toggle()
    }
}

/// UIViewRepresentable to expose the RPSystemBroadcastPickerView’s UIButton
struct BroadcastPickerHelper: UIViewRepresentable {
    let extensionID: String
    @Binding var broadcastButton: UIButton?

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = extensionID
        picker.showsMicrophoneButton = false

        DispatchQueue.main.async {
            if let btn = picker.subviews.compactMap({ $0 as? UIButton }).first {
                broadcastButton = btn
            }
        }
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
