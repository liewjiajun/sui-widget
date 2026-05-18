import SwiftUI
import WidgetKit

@main
public struct SuiWidgetBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        SuiWidgetWidget()
        // Lock Screen widgets get registered in Task 7.
    }
}
