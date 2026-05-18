import SwiftUI

/// The "pixel lift" shadow — a solid black offset rectangle behind the card.
/// Use on app-screen cards (not widgets).
public struct PixelLift: ViewModifier {
    public var radius: CGFloat = 4
    public var offset: CGFloat = 2
    public var opacity: Double = 0.18

    public func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(opacity))
                .offset(x: offset, y: offset)
        }
    }
}

public extension View {
    /// Applies the pixel-lift shadow effect. Use on app-screen cards only.
    func pixelLift(radius: CGFloat = 4, offset: CGFloat = 2, opacity: Double = 0.18) -> some View {
        modifier(PixelLift(radius: radius, offset: offset, opacity: opacity))
    }
}
