// RecentBroadcastsScreen.swift
import SwiftUI
import AVKit

struct RecentBroadcastsScreen: View {
    // Accept storage manager from parent
    let storageManager: BroadcastStorageManager
    
    @State private var selectedBroadcast: BroadcastRecord?
    @State private var isUploading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [.crBlue, Color(red: 0, green: 0.1, blue: 0.3)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    if storageManager.broadcasts.isEmpty {
                        emptyStateView
                    } else {
                        broadcastsList
                    }
                }
                .navigationTitle("Recent Broadcasts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
                .fullScreenCover(item: $selectedBroadcast) { broadcast in
                    BroadcastPlayerScreen(broadcast: broadcast)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.fill")
                .font(.system(size: 60))
                .foregroundColor(.crGold)
            
            Text("No Recent Broadcasts")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your recent broadcasts will appear here")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var broadcastsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(storageManager.broadcasts) { broadcast in
                    BroadcastListItem(
                        broadcast: broadcast,
                        isUploading: isUploading,
                        onPlay: {
                            selectedBroadcast = broadcast
                        },
                        onDelete: {
                            storageManager.deleteBroadcast(broadcast)
                        },
                        onSend: {
                            isUploading = true
                            storageManager.sendToServer(broadcast) { success in
                                isUploading = false
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
}

struct BroadcastListItem: View {
    let broadcast: BroadcastRecord
    let isUploading: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onSend: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.crGold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(broadcast.formattedDate)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        Label(broadcast.formattedDuration, systemImage: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Label(broadcast.formattedFileSize, systemImage: "internaldrive")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: onPlay) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.crBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.crGold)
                    )
                }
                .buttonStyle(ClashRoyaleButtonStyle())
                
                Button(action: { showDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.7))
                    )
                }
                .buttonStyle(ClashRoyaleButtonStyle())
                .alert("Delete Broadcast", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) { onDelete() }
                } message: {
                    Text("Are you sure you want to delete this broadcast? This action cannot be undone.")
                }
                
                Button(action: onSend) {
                    HStack {
                        Image(systemName: isUploading ? "arrow.clockwise" : "arrow.up.to.line")
                        Text(isUploading ? "Sending..." : "Send")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.crPurple)
                    )
                }
                .buttonStyle(ClashRoyaleButtonStyle())
                .disabled(isUploading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.crNavy.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.crGold.opacity(0.5), lineWidth: 2)
                )
        )
    }
}
