import SwiftUI

extension View {
    /// Applies a gold border with shadow to any view
    func goldBorder(width: CGFloat = 2, cornerRadius: CGFloat = 12) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.crGold, lineWidth: width)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    /// Applies standard app styling for cards
    func cardStyle(background: Color = .crNavy.opacity(0.75), borderColor: Color = .crGold) -> some View {
        self.padding(Constants.UI.defaultPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(borderColor, lineWidth: Constants.UI.buttonBorderWidth)
            )
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}
