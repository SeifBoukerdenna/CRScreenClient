import SwiftUI
import ReplayKit

struct ContentView: View {
    @State private var broadcastButton: UIButton? = nil
    @State private var isBroadcasting = false

    var body: some View {
        VStack(spacing: 32) {
            Text(isBroadcasting ? "🔴 Broadcasting…" : "⚫️ Not Broadcasting")
                .font(.headline)

            Button(action: {
                // 1) fire the picker
                broadcastButton?.sendActions(for: .touchUpInside)
                // 2) flip our local state so the label updates
                isBroadcasting.toggle()
            }) {
                HStack {
                    Image(systemName: isBroadcasting ? "stop.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                    Text(isBroadcasting ? "Stop Streaming" : "Start Streaming")
                        .font(.title2)
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        //  Invisible helper that captures the RP picker button
        .background(
            BroadcastPickerHelper(
                extensionID: "com.elmelz.CRScreenClient.CRScreenClientBroadcast",
                broadcastButton: $broadcastButton
            )
            .frame(width: 0, height: 0)
        )
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

        // Capture the internal UIButton once it’s laid out
        DispatchQueue.main.async {
            if let btn = picker.subviews.compactMap({ $0 as? UIButton }).first {
                broadcastButton = btn
            }
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
