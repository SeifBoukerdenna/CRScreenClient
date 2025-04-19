import SwiftUI
import ReplayKit
import Combine

// MARK: – Palette
extension Color {
    static let crBlue  = Color(red:   0/255, green: 114/255, blue: 206/255)
    static let crGold  = Color(red: 255/255, green: 215/255, blue:   0/255)
    static let crBrown = Color(red: 107/255, green:  73/255, blue:  36/255)
}

// MARK: – Broadcast manager (no iOS‑18‑missing symbols)
final class BroadcastManager: ObservableObject {
    @Published private(set) var isBroadcasting = false
    @Published private(set) var elapsed: TimeInterval = 0
    
    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    
    private var startDate: Date? {
        UserDefaults(suiteName: groupID)?
            .object(forKey: kStartedAtKey) as? Date
    }
    private var timer: AnyCancellable?
    
    init() {
        refreshState()
        timer = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }
    
    // Called when host app goes background – no programmatic stop on iOS‑18 SDK
    func stopIfNeeded() { /* noop until Apple re‑exposes API */ }
    
    private func tick() {
        refreshState()
        // if the extension hasn't saved its date yet, fall back to now
        if isBroadcasting, startDate == nil {
            let now = Date()
            UserDefaults(suiteName: groupID)?
                .set(now, forKey: kStartedAtKey)
            elapsed = 0                   // start at 00:00, no freeze
        } else if let s = startDate {
            elapsed = Date().timeIntervalSince(s)
        }
    }
    private func refreshState() {
        // LIVE if the extension has stored a start date in the shared container
        isBroadcasting = startDate != nil
        if !isBroadcasting { elapsed = 0 }
    }
}

// MARK: – SwiftUI UI
struct ContentView: View {
    @StateObject private var bm = BroadcastManager()
    @State private var broadcastButton: UIButton?
    @Environment(\.scenePhase) private var phase
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.crBlue, .crBlue.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                HStack(spacing: 12) {
                    CapsuleLabel(text: bm.isBroadcasting ? "LIVE" : "OFFLINE",
                                 color: bm.isBroadcasting ? .red : .gray)
                    if bm.isBroadcasting {
                        CapsuleLabel(text: timeString(bm.elapsed),
                                     color: .crGold.opacity(0.9))
                    }
                }
                Button(action: toggleBroadcast) {
                    VStack(spacing: 8) {
                        Image(systemName: bm.isBroadcasting
                              ? "stop.fill"
                              : "dot.radiowaves.left.and.right")
                            .resizable().scaledToFit().frame(height: 50)
                            .foregroundColor(.white)
                        Text(bm.isBroadcasting ? "Stop Broadcasting"
                                               : "Start Broadcasting")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 36).padding(.vertical, 24)
                    .background(GoldButtonBackground())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            BroadcastPickerHelper(
                extensionID: "com.elmelz.CRScreenClient.Broadcast",
                broadcastButton: $broadcastButton
            )
            .frame(width: 0, height: 0)
        )
        .onChange(of: phase) { if phase == .background { bm.stopIfNeeded() } }

    }
    
    private func toggleBroadcast() {
        broadcastButton?.sendActions(for: .touchUpInside)
    }
    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d",
               Int(t) / 3600, Int(t) / 60 % 60, Int(t) % 60)
    }
}

private struct CapsuleLabel: View {
    let text: String; let color: Color
    var body: some View {
        Text(text).font(.system(size: 18, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 18).padding(.vertical, 6)
            .background(Capsule().fill(color))
    }
}

private struct GoldButtonBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.crGold)
            .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.crBrown, lineWidth: 6))
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
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
            broadcastButton = picker.subviews
                .compactMap { $0 as? UIButton }
                .first
        }
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
