import SwiftUI

struct GoldButtonBackground: View {
    var body: some View {
        ZStack {
            // Base shape with shadow
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.crGold,
                            Color(red: 1, green: 0.85, blue: 0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Inner highlight
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .padding(3)
                        .blur(radius: 1)
                )
                .overlay(
                    // Border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.crBrown, lineWidth: 6)
                )
            
            // Bottom inner shadow
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.crBrown.opacity(0.7), lineWidth: 4)
                .blur(radius: 2)
                .mask(
                    Rectangle()
                        .frame(height: 15)
                        .frame(maxWidth: .infinity)
                        .offset(y: 22)
                )
            
            // Top shine effect
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.3)
                    )
                )
                .padding(6)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 6)
    }
}

// MARK: - Preview
struct GoldButtonBackground_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue.opacity(0.5).ignoresSafeArea()
            
            VStack {
                Text("Start Broadcasting")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                    .background(GoldButtonBackground())
            }
        }
    }
}
