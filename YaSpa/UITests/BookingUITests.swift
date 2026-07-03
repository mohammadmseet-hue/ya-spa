import XCTest

/// Drives the real Ya Spa booking flow in a booted iOS Simulator:
/// open a massage -> pick a day -> pick a time slot -> enter details ->
/// confirm -> verify the confirmation -> verify it persisted to My Bookings.
final class BookingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testUserCanBookAMassage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]   // English + all slots available (deterministic)
        app.launch()

        shot(app, "01-Home")

        // Open the Massage catalog tab (the app launches on the Home dashboard)
        app.tabBars.buttons.element(boundBy: 1).tap()
        shot(app, "01b-Massage")

        // 1) Open a massage
        let card = app.buttons["massage-swedish"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Massage card should be on the Massage tab")
        card.tap()

        // 2) Start booking
        let book = app.buttons["book-session"]
        XCTAssertTrue(book.waitForExistence(timeout: 10), "Book button should be on the detail screen")
        shot(app, "02-Detail")
        book.tap()

        // 3) Pick the first time slot (10:00 is always available in test mode)
        let slot = app.buttons["slot-10:00"]
        XCTAssertTrue(slot.waitForExistence(timeout: 10), "Time slot grid should be shown")
        slot.tap()
        shot(app, "03-SlotPicked")

        // 3b) Choose a therapist
        let therapist = app.buttons["therapist-reem"]
        XCTAssertTrue(therapist.waitForExistence(timeout: 10), "Therapist list should be shown")
        bringIntoReach(therapist, in: app)
        therapist.tap()
        shot(app, "03b-Therapist")

        // 4) Enter details (robust to keyboard overlap + font-metric height shifts)
        fillField(app, "field-name", "Sara")
        fillField(app, "field-district", "Al Rawdah")
        shot(app, "03c-Fields")

        // dismiss keyboard so the bottom Confirm bar is reachable
        app.swipeDown()
        shot(app, "04-Details")

        // 5) Confirm — only once the form is actually valid (all fields registered)
        let confirm = app.buttons["confirm-booking"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Confirm button should exist")
        wait(for: [expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: confirm)],
             timeout: 12)
        confirm.tap()

        // 6) Confirmation appears
        let confirmed = app.staticTexts["confirmation-title"]
        XCTAssertTrue(confirmed.waitForExistence(timeout: 10), "Booking confirmation should appear")
        shot(app, "05-Confirmed")

        // 7) Done
        app.buttons["confirmation-done"].tap()

        // 8) The booking is saved and listed under My Bookings
        app.tabBars.buttons.element(boundBy: 2).tap()
        let saved = app.staticTexts["Swedish Massage"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10), "The new booking should be listed in My Bookings")
        shot(app, "06-MyBookings")
    }

    /// The Confirm button must stay disabled until a time slot and details are entered.
    func testConfirmIsBlockedUntilDetailsEntered() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        app.tabBars.buttons.element(boundBy: 1).tap()   // Massage tab

        let card = app.buttons["massage-deep"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()

        let book = app.buttons["book-session"]
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()

        let confirm = app.buttons["confirm-booking"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertFalse(confirm.isEnabled, "Confirm must be disabled before a slot + details are provided")
    }

    /// The language toggle switches the whole UI to Arabic.
    func testLanguageToggleSwitchesToArabic() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]   // starts in English
        app.launch()

        app.tabBars.buttons.element(boundBy: 1).tap()   // Massage tab
        XCTAssertTrue(app.staticTexts["Swedish Massage"].waitForExistence(timeout: 15))
        app.buttons["lang-massage"].tap()   // English mode shows the "switch to Arabic" glyph
        XCTAssertTrue(app.staticTexts["المساج السويدي"].waitForExistence(timeout: 10),
                      "Massage names should switch to Arabic after tapping the language toggle")
    }

    /// The dashboard "Book a massage" CTA opens the Massage catalog.
    func testDashboardBookOpensMassage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        let book = app.buttons["dashboard-book"]
        XCTAssertTrue(book.waitForExistence(timeout: 15), "Dashboard book CTA should exist on Home")
        book.tap()
        XCTAssertTrue(app.buttons["massage-swedish"].waitForExistence(timeout: 10),
                      "Booking CTA should open the Massage catalog")
    }

    /// All four tabs are reachable and show their content.
    func testTabsNavigate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        let tabs = app.tabBars.buttons
        XCTAssertTrue(tabs.element(boundBy: 0).waitForExistence(timeout: 15))
        tabs.element(boundBy: 1).tap()   // Massage
        XCTAssertTrue(app.buttons["massage-swedish"].waitForExistence(timeout: 10))
        tabs.element(boundBy: 2).tap()   // My bookings
        tabs.element(boundBy: 3).tap()   // Profile
        XCTAssertTrue(app.buttons["profile-language"].waitForExistence(timeout: 10))
        tabs.element(boundBy: 0).tap()   // Home
        XCTAssertTrue(app.buttons["dashboard-book"].waitForExistence(timeout: 10))
    }

    /// Tapping a therapist on a service detail opens their profile.
    func testTherapistProfileOpens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        app.tabBars.buttons.element(boundBy: 1).tap()   // Massage
        let card = app.buttons["massage-swedish"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()

        let therapist = app.buttons["therapist-profile-reem"]
        XCTAssertTrue(therapist.waitForExistence(timeout: 10), "Therapist row should be on the detail screen")
        scrollUntilHittable(therapist, in: app)
        therapist.tap()
        XCTAssertTrue(app.staticTexts["About"].waitForExistence(timeout: 10),
                      "Therapist profile should show the About section")
    }

    /// Reliably enter text into a scrollable field: bring it on-screen, focus it, type.
    private func fillField(_ app: XCUIApplication, _ id: String, _ text: String) {
        let field = app.textFields[id]
        bringIntoReach(field, in: app)
        field.tap()
        field.typeText(text)
    }

    /// Scroll a control into the comfortable middle band — clear of the nav bar (top)
    /// and the sticky book bar / keyboard (bottom) — so taps land on it, not the chrome.
    /// `isHittable` alone is unreliable here (it returns true for controls whose centre
    /// sits under the sticky bar), so we position by frame instead.
    private func bringIntoReach(_ el: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 16) {
        XCTAssertTrue(el.waitForExistence(timeout: 8), "element should exist")
        let h = app.frame.height
        var swipes = 0
        while el.frame.midY > h * 0.6 && swipes < maxSwipes {   // too low → scroll up
            app.swipeUp(); swipes += 1
        }
        swipes = 0
        while el.frame.midY < h * 0.15 && swipes < 6 {          // too high → nudge down
            app.swipeDown(); swipes += 1
        }
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 12) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
