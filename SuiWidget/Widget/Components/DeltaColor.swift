import SwiftUI
import SuiWidgetKit

/// Maps a 24h percent delta to the brand up/down/flat color.
///
/// Centralised here so every widget view (Small / Medium / Large / ExtraLarge,
/// plus any future sizes) shares the same threshold and color choice without
/// duplicating a private helper.
public func suiDeltaColor(_ percent: Double) -> Color {
    if percent > 0.05 { return SuiColor.up }
    if percent < -0.05 { return SuiColor.down }
    return SuiColor.flat
}
