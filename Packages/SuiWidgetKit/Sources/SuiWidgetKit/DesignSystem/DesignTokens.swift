import SwiftUI

public enum SuiColor {
    public static let suiBlue = Color(hex: "#4DA2FF")
    public static let suiDeep = Color(hex: "#1F6BB5")
    public static let suiTint = Color(hex: "#9DD0FF")
    public static let suiPale = Color(hex: "#DBECFF")
    public static let paperLight = Color(hex: "#F4EDE1")
    public static let paperLightSub = Color(hex: "#EBE1CF")
    public static let paperDark = Color(hex: "#0F1418")
    public static let paperDarkSub = Color(hex: "#16202A")
    public static let inkLight = Color(hex: "#0F1418")
    public static let inkDark = Color(hex: "#F4EDE1")
    public static let up = Color(hex: "#3AA05A")
    public static let down = Color(hex: "#D6543B")
    public static let flat = Color(hex: "#888888")
    public static let coral = Color(hex: "#FF7361")
    public static let amber = Color(hex: "#F5A623")

    /// The current paper background based on color scheme (call in a View body where @Environment(\.colorScheme) is available).
    public static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? paperDark : paperLight
    }

    public static func paperSub(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? paperDarkSub : paperLightSub
    }

    public static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? inkDark : inkLight
    }
}

public enum SuiTypography {
    /// SF Pro Display, bold, tabular figures. Used for portfolio values, hero numerics.
    public static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }

    /// Pixel-art display font (VT323 — bundled in widget + app targets).
    /// Use only for hero numerics, deltas, and the SUI inline glyph caption to anchor
    /// the pixel-art brand. Body text, paragraphs, and labels MUST stay on system fonts
    /// so Dynamic Type continues to work — pixel font hurts legibility on long-form text.
    public static func pixelDisplay(_ size: CGFloat) -> Font {
        .custom("VT323-Regular", size: size)
    }

    /// SF Pro Text. Body copy.
    public static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// SF Mono. Labels, micro-captions, refresh stamps.
    public static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

public enum SuiSpacing {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 24

    public static let widgetRadius: CGFloat = 22
    public static let cardRadius: CGFloat = 12
    public static let inputRadius: CGFloat = 8
    public static let pillRadius: CGFloat = 999
}
