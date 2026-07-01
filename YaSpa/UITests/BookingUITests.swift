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
        scrollUntilHittable(therapist, in: app)
        therapist.tap()

        // 4) Enter details
        let name = app.textFields["field-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Name field should exist")
        scrollUntilHittable(name, in: app)
        name.tap()
        name.typeText("Sara")

        let district = app.textFields["field-district"]
        scrollUntilHittable(district, in: app)
        district.tap()
        district.typeText("Al Rawdah")

        // dismiss keyboard so the bottom Confirm bar is fully hittable
        app.swipeDown()
        shot(app, "04-Details")

        // 5) Confirm
        let confirm = app.buttons["confirm-booking"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Confirm button should exist")
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

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
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
