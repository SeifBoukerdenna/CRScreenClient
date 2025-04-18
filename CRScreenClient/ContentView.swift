import SwiftUI
import ReplayKit

struct ContentView: View {
    @State private var broadcastButton: UIButton?
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 32) {
            Text("Clash Royale AI Coach")
                .font(.title)
                .bold()

            // Big tappable SwiftUI button
            Button(action: {
                print("📡 Start Streaming tapped")
                showAlert = true
                broadcastButton?.sendActions(for: .touchUpInside)
            }) {
                VStack {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                    Text("Start Streaming")
                        .font(.headline)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()

        }
        .alert("Streaming Started",
               isPresented: $showAlert,
               actions: {
                   Button("OK", role: .cancel) {}
               },
               message: {
                   Text("Your screen broadcast is now live.")
               }
        )
        .padding()

        // Hidden picker to get its UIButton reference
        BroadcastPickerHelper(
            broadcastExtensionID: "com.elmelz.CRScreenClient.CRScreenClientBroadcast",
            broadcastButton: $broadcastButton
        )
        .frame(width: 0, height: 0)      // collapse to zero
        .clipped()                       // ensure it really disappears
        .allowsHitTesting(false)         // so it never intercepts touches
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 14 Pro")
    }
}

// MARK: – BroadcastPickerHelper

/// A tiny UIViewRepresentable that embeds RPSystemBroadcastPickerView
/// purely to capture its internal UIButton and hand it back via a Binding.
struct BroadcastPickerHelper: UIViewRepresentable {
    let broadcastExtensionID: String
    @Binding var broadcastButton: UIButton?

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = broadcastExtensionID
        picker.showsMicrophoneButton = false

        // Delay until layout so the subviews exist
        DispatchQueue.main.async {
            if let btn = picker.subviews.compactMap({ $0 as? UIButton }).first {
                broadcastButton = btn
            }
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        // no-op
    }
}
