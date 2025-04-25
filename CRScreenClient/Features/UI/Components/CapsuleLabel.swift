import SwiftUI

struct CapsuleLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }
}
