import XCTest

final class PlaceholderUITests: XCTestCase {
    func test_appLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["App Group handshake"].waitForExistence(timeout: 5))
    }
}
