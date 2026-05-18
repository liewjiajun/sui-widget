import SwiftUI
import WidgetKit

@main
public struct SuiWidgetBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        SuiWidgetWidget()
        SuiLockScreenWidget()
    }
}
