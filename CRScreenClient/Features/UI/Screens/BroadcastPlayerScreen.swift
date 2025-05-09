// BroadcastPlayerScreen.swift
import SwiftUI
import AVKit

struct BroadcastPlayerScreen: View {
    let broadcast: BroadcastRecord
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    
    init(broadcast: BroadcastRecord) {
        self.broadcast = broadcast
        _player = State(initialValue: AVPlayer(url: broadcast.fileURL))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
            
            VStack {
                HStack {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
    }
}
