import SwiftUI

struct GuideCard: View {
    var body: some View {
        VStack(spacing: 8) {
            // Title
            Text("Welcome, Chief!")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.crGold)
                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 2)
            
            // Crown icon
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(.crGold)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            
            // Text with royal style
            Text("Open")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text("royaltrainer.com")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.crPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.crPurple, .crPurpleLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            Text("Enter your 4‑digit code above to connect")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.crNavy.opacity(0.9),
                                Color.crNavy.opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Wooden texture effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.1),
                                Color.clear,
                                Color.black.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.7)
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.crGold, .crGold.opacity(0.7), .crGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
            }
        )
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 6)
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }
}

struct GuideCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue.opacity(0.5).ignoresSafeArea()
            GuideCard()
        }
    }
}
