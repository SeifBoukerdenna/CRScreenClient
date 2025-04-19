import SwiftUI
import ReplayKit
import UIKit

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
