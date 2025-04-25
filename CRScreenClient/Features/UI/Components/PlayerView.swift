import SwiftUI
import AVKit

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer
    var onLayerCreated: ((AVPlayerLayer) -> Void)?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if layer already exists
        if let existingLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            existingLayer.player = player
        } else {
            // Create new player layer
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = uiView.bounds
            playerLayer.videoGravity = .resizeAspect
            uiView.layer.addSublayer(playerLayer)
            
            // Notify that layer was created
            onLayerCreated?(playerLayer)
            
            // Add observer for layout changes using KVO
            uiView.layer.addObserver(context.coordinator, forKeyPath: "bounds", options: .new, context: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PlayerView
        
        init(_ parent: PlayerView) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "bounds", let layer = (object as? CALayer)?.sublayers?.first as? AVPlayerLayer {
                if let bounds = (object as? CALayer)?.bounds {
                    layer.frame = bounds
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        uiView.layer.removeObserver(coordinator, forKeyPath: "bounds")
    }
}
