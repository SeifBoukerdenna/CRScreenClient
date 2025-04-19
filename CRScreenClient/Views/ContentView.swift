import SwiftUI

struct ContentView: View {
    @StateObject private var bm = BroadcastManager()
    @State private var broadcastButton: UIButton?
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.crBlue, .crBlue.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // LIVE / OFFLINE pills
                HStack(spacing: 12) {
                    CapsuleLabel(
                        text: bm.isBroadcasting ? "LIVE" : "OFFLINE",
                        color: bm.isBroadcasting ? .red : .gray
                    )
                    if bm.isBroadcasting {
                        CapsuleLabel(
                            text: timeString(bm.elapsed),
                            color: .crGold.opacity(0.9)
                        )
                    }
                }

                // Session Code only when live
                if bm.isBroadcasting {
                    VStack(spacing: 6) {
                        Text("Session Code")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        Text(bm.code)
                            .font(.system(
                                size: 48,
                                weight: .heavy,
                                design: .monospaced
                            ))
                            .foregroundColor(.white)
                    }
                }

                // Guide only when offline
                if !bm.isBroadcasting {
                    GuideCard()
                }

                // Start/Stop button
                Button(action: toggleBroadcast) {
                    VStack(spacing: 8) {
                        Image(systemName: bm.isBroadcasting
                              ? "stop.fill"
                              : "dot.radiowaves.left.and.right")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .foregroundColor(.white)
                        Text(bm.isBroadcasting ? "Stop Broadcasting"
                                               : "Start Broadcasting")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                    .background(GoldButtonBackground())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
        .background(
            BroadcastPickerHelper(
                extensionID: "com.elmelz.CRScreenClient.Broadcast",
                broadcastButton: $broadcastButton
            )
            .frame(width: 0, height: 0)
        )
        .onChange(of: phase) { new in
            if new == .background { bm.stopIfNeeded() }
        }
    }

    private func toggleBroadcast() {
        if !bm.isBroadcasting { bm.prepareNewCode() }
        broadcastButton?.sendActions(for: .touchUpInside)
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d",
               Int(t) / 3600, Int(t) / 60 % 60, Int(t) % 60)
    }
}
