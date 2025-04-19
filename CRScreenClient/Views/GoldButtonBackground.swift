import SwiftUI

struct GoldButtonBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.crGold)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.crBrown, lineWidth: 6)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
    }
}
