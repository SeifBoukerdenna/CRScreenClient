import SwiftUI

struct GuideCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Welcome, Chief!")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.crGold)
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            Text("Open")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            Text("royaltrainer.com")
                .font(.headline)
                .foregroundColor(.crPurple)
                .underline()
            Text("Enter your 4‑digit code above to connect")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.crNavy.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.crGold, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        .padding(.bottom, 12)
    }
}
