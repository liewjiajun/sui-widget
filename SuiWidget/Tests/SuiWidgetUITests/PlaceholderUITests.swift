import XCTest

final class PlaceholderUITests: XCTestCase {
    func test_appLaunches_andShowsTabView() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // The Portfolio tab should be selected by default.
        XCTAssertTrue(app.tabBars.buttons["Portfolio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["NFTs"].exists)
        XCTAssertTrue(app.tabBars.buttons["News"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
