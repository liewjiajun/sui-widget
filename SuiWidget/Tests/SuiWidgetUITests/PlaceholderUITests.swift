import XCTest

final class PlaceholderUITests: XCTestCase {

    /// Smoke: launching with onboarding pre-completed lands on the 4-tab shell.
    func test_appLaunches_andShowsTabView() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Portfolio"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["NFTs"].exists)
        XCTAssertTrue(app.tabBars.buttons["News"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    /// Walks every tab and captures a screenshot of each, proving each screen
    /// renders without crashing. Runs offline (empty states are valid content).
    func test_walkAllTabs_captureScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Portfolio"].waitForExistence(timeout: 10))
        attach(app, name: "01-Portfolio")

        for tab in ["NFTs", "News", "Settings"] {
            app.tabBars.buttons[tab].tap()
            // Let the tab's onAppear/loading settle.
            Thread.sleep(forTimeInterval: 1.0)
            attach(app, name: "0\(["NFTs": 2, "News": 3, "Settings": 4][tab]!)-\(tab)")
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected, "\(tab) tab should be selected")
        }

        // Drill into Settings → Wallets to prove navigation works.
        app.tabBars.buttons["Settings"].tap()
        if app.buttons["Wallets"].waitForExistence(timeout: 3) {
            app.buttons["Wallets"].tap()
            Thread.sleep(forTimeInterval: 0.8)
            attach(app, name: "05-WalletsList")
            XCTAssertTrue(app.navigationBars.firstMatch.exists)
        }
    }

    /// Walks the 3-screen onboarding flow, capturing each page. Proves the
    /// first-run experience renders end-to-end.
    func test_onboardingFlow_captureScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // Page 1 — Welcome.
        XCTAssertTrue(app.staticTexts["Sui on your screen.\nAlways."].waitForExistence(timeout: 10)
            || app.buttons["Continue"].waitForExistence(timeout: 5))
        attach(app, name: "10-Onboarding-Welcome")

        if app.buttons["Continue"].exists {
            app.buttons["Continue"].tap()
            Thread.sleep(forTimeInterval: 0.8)
            attach(app, name: "11-Onboarding-Notifications")
        }

        // Advance to add-wallet (Not now / Skip on the notifications page).
        for label in ["Not now", "Skip"] where app.buttons[label].exists {
            app.buttons[label].tap()
            break
        }
        Thread.sleep(forTimeInterval: 0.8)
        attach(app, name: "12-Onboarding-AddWallet")
    }

    /// Best-effort live path: add the Mysten `validator.sui` wallet and wait for
    /// the portfolio to populate. Network-dependent and NON-GATING — it never
    /// fails the suite (CI / offline runners must stay green); it only captures
    /// the real populated UI as screenshots when the network is available. The
    /// opt-in `LiveIntegrationTests` in SuiWidgetKit own actual live assertions.
    func test_addWallet_liveSync_captureScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        guard app.buttons["Wallets"].waitForExistence(timeout: 5) else { return }
        app.buttons["Wallets"].tap()

        // Tap the toolbar "Add wallet" affordance specifically. Both the nav-bar
        // "+" and the empty-state CTA carry the "Add wallet" label, so scope the
        // query to the navigation bar to get a single match.
        let navAdd = app.navigationBars.buttons["Add wallet"]
        if navAdd.waitForExistence(timeout: 3) {
            navAdd.tap()
        } else if app.buttons["Add wallet"].firstMatch.exists {
            app.buttons["Add wallet"].firstMatch.tap()
        } else {
            return
        }

        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 5) else {
            attach(app, name: "20-AddWallet-NoField")
            return
        }
        field.tap()
        // Trailing \n submits the field → onSubmit dismisses the keyboard, which
        // reveals the bottom "Add wallet" button (otherwise hidden behind it).
        field.typeText("0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8\n")

        // Wait for resolution feedback, then add.
        Thread.sleep(forTimeInterval: 2.0)
        attach(app, name: "21-AddWallet-Resolved")
        for label in ["Add wallet", "Finish & install widget", "Add"] {
            let button = app.buttons[label].firstMatch
            if button.exists && button.isHittable && button.isEnabled {
                button.tap()
                break
            }
        }

        // Allow the post-add sync (network) to run.
        Thread.sleep(forTimeInterval: 12.0)
        if app.tabBars.buttons["Portfolio"].exists {
            app.tabBars.buttons["Portfolio"].tap()
            Thread.sleep(forTimeInterval: 3.0)
        }
        attach(app, name: "22-Portfolio-AfterSync")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
