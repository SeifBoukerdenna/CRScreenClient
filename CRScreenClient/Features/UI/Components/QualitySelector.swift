import SwiftUI

struct QualitySelector: View {
    @Binding var selectedQuality: StreamQuality
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Stream Quality Settings")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
                .padding(.top, 30)
                .padding(.bottom, 20)
            
            // Option Selection Box
            VStack(spacing: 0) {
                Text("Stream Quality")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                
                // Option Buttons
                VStack(spacing: 1) {
                    ForEach(StreamQuality.allCases) { quality in
                        QualityOptionButton(
                            quality: quality,
                            isSelected: selectedQuality == quality,
                            action: { selectedQuality = quality }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.crNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.crGold, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            
            // Info Icons section
            VStack(spacing: 16) {
                qualityInfoRow(
                    icon: "bolt.fill",
                    title: "Low Quality",
                    description: "Prioritizes minimum latency with reduced image quality. Best for gameplay and fast reaction times.",
                    color: .blue
                )
                
                qualityInfoRow(
                    icon: "align.horizontal.center",
                    title: "Medium Quality",
                    description: "Balanced option with good image quality and reasonable latency. Good for most use cases.",
                    color: .crGold
                )
                
                qualityInfoRow(
                    icon: "4k.tv",
                    title: "High Quality",
                    description: "Prioritizes visual clarity with the highest resolution possible. May have increased latency.",
                    color: .crPurple
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.crNavy.opacity(0.5))
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Done button
            Button(action: {
                dismiss()
            }) {
                Text("DONE")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color.crBrown)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.crGold)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.crBrown, lineWidth: 3)
                    )
            }
            .buttonStyle(ClashRoyaleButtonStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [.crBlue, Color(red: 0, green: 0.15, blue: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func qualityInfoRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct QualityOptionButton: View {
    let quality: StreamQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(quality.title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(isSelected ? quality.color : .white)
                
                Spacer()
                
                Text(quality.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.yellow)
                        .padding(.leading, 8)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? quality.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
