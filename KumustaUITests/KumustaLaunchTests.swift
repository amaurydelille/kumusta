import XCTest

@MainActor
final class KumustaLaunchTests: XCTestCase {
    func testGoalLessonsOfferLevelsAndOpenExistingLessonFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "mainApp", "-kumusta.appearance", "light"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Speak naturally with family"].waitForExistence(timeout: 8))
        let continueLesson = app.buttons["goalCurriculumContinue"]
        XCTAssertTrue(continueLesson.waitForExistence(timeout: 8))
        captureSettled("Goal recommendations", app: app)
        app.buttons["goalCurriculumLevel"].tap()
        app.buttons["Advanced"].tap()
        XCTAssertTrue(continueLesson.exists)
        continueLesson.tap()
        XCTAssertTrue(app.staticTexts["Hear the situation first"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Natural speed"].exists)
        captureSettled("Goal lesson flow", app: app)
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchShowsOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "firstLaunch"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Hi there! I’m Tuko."].waitForExistence(timeout: 5))
    }

    func testOnboardingBuildsPersonalizedPlanWithoutListeningDemo() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "firstLaunch", "-kumusta.appearance", "light"]
        app.launch()
        app.buttons["Continue"].tap()
        let nameField = app.textFields["First name or nickname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Alex")
        app.buttons["Continue"].firstMatch.tap()
        // No accent step: Kumusta teaches one Tagalog.
        XCTAssertFalse(app.buttons["Use this accent"].exists)
        tapButton(containing: "Talk with family", in: app)
        tapButton(containing: "I can handle basics", in: app)
        XCTAssertTrue(app.staticTexts["What can you repeat most days?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["First name or nickname"].exists)
        XCTAssertFalse(app.staticTexts["Can you catch the meaning?"].exists)
        tapButton(containing: "7 min", in: app)
        XCTAssertTrue(app.staticTexts["Making this yours"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Listening"].exists)
        XCTAssertTrue(app.staticTexts["Speaking"].exists)
        XCTAssertTrue(app.staticTexts["Daily rhythm"].exists)
        capture("Plan building", app: app)
        // The welcome lesson and paywall that follow are covered by
        // testOnboardingWelcomeLessonMatchesLevelAndLeadsToPaywall.
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    /// The level-specific welcome lesson and the comparison screen
    /// run right before the paywall; skipping the lesson still reaches both.
    func testOnboardingWelcomeLessonMatchesLevelAndLeadsToPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "firstLaunch", "-kumusta.appearance", "light"]
        app.launch()

        app.buttons["Continue"].tap()
        let nameField = app.textFields["First name or nickname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Alex")
        // The keyboard's return key is also labelled Continue.
        app.buttons["Continue"].firstMatch.tap()
        tapButton(containing: "Talk with family", in: app)
        tapButton(containing: "I can handle basics", in: app)
        tapButton(containing: "7 minutes a day", in: app)

        // Plan building runs for a few seconds, then the merienda lesson opens.
        XCTAssertTrue(app.staticTexts["From words to real replies"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Pabili po ng dalawang turon"].exists, "Intermediate lesson expected")
        captureSettled("Welcome lesson intro", app: app)

        tapButton(containing: "LET", in: app)
        XCTAssertTrue(app.staticTexts["At the counter, call them Kuya or Ate"].waitForExistence(timeout: 5))
        captureSettled("Welcome lesson teach", app: app)

        app.buttons["Close lesson"].tap()
        XCTAssertTrue(app.staticTexts["Wait, don’t go!"].waitForExistence(timeout: 5))
        app.buttons["SKIP THE LESSON"].tap()

        // "On your own vs With Kumusta" comes before the paywall.
        XCTAssertTrue(app.staticTexts["YOUR NEXT 30 DAYS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "On your own, it levels off")).firstMatch.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 2.5)
        capture("Comparison", app: app)
        tapButton(containing: "SEE MY PLAN", in: app)

        // Preview dependencies intentionally have no live subscription SDK key.
        XCTAssertTrue(app.staticTexts["RevenueCat isn’t configured"].waitForExistence(timeout: 10))
    }

    func testFirstLessonRecordingKeepsTheWholeTake() {
        let app = XCUIApplication()
        // Step 5 of the First Steps lesson is "Say hello".
        app.launchArguments = ["-UITestScenario", "firstLesson", "-FirstLessonStep", "5"]
        app.launch()

        let record = app.buttons["Start recording"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        // Let the autoplayed phrase start, so stopping it races the microphone.
        Thread.sleep(forTimeInterval: 0.3)
        record.tap()
        let stop = app.buttons["Stop recording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(stop.exists, "The take stopped on its own")
        stop.tap()
        let tooQuick = app.staticTexts["That was a little too quick. Try the full phrase once more."]
        XCTAssertFalse(tooQuick.waitForExistence(timeout: 3))
    }

    private func tapButton(containing text: String, in app: XCUIApplication) {
        let button = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        let match = button.exists ? button : app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 8), "Missing button containing \(text)")
        match.tap()
    }

    private func captureSettled(_ name: String, app: XCUIApplication) {
        // Wait for the screen spring to settle before taking layout evidence.
        Thread.sleep(forTimeInterval: 1)
        capture(name, app: app)
    }

    func testAppearancePersistsAndCoreTabsSupportDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "mainApp"]
        app.launch()
        app.buttons["Profile"].tap()
        let dark = app.buttons["appearance-dark"]
        let profileScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(profileScrollView.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0 ..< 12 where !dark.exists {
            profileScrollView.swipeUp()
        }
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        XCTAssertTrue(dark.isSelected)
        capture("Dark profile", app: app)
        app.terminate()
        app.launch()
        app.buttons["Profile"].tap()
        let persistedDark = app.buttons["appearance-dark"]
        let relaunchedProfileScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(relaunchedProfileScrollView.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0 ..< 12 where !persistedDark.exists {
            relaunchedProfileScrollView.swipeUp()
        }
        XCTAssertTrue(persistedDark.waitForExistence(timeout: 5))
        XCTAssertTrue(persistedDark.isSelected)
        for tab in ["Today", "Practice", "Words"] {
            app.buttons[tab].tap()
            capture("Dark \(tab)", app: app)
        }
        app.buttons["Profile"].tap()
        app.buttons["appearance-light"].tap()
        XCTAssertTrue(app.buttons["appearance-light"].isSelected)
        capture("Light profile", app: app)
        app.buttons["appearance-system"].tap()
        XCTAssertTrue(app.buttons["appearance-system"].isSelected)
        app.buttons["appearance-dark"].tap()
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCoreReferenceTabsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "mainApp"]
        app.launch()

        app.buttons["Practice"].tap()
        XCTAssertTrue(app.staticTexts["Listen like you’re there"].waitForExistence(timeout: 5))

        app.buttons["Words"].tap()
        XCTAssertTrue(app.staticTexts["Words"].waitForExistence(timeout: 5))

        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["PROFILE"].waitForExistence(timeout: 5))
    }

    func testAccountDeletionIsAvailableAndCompletesFromProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "mainApp"]
        app.launch()

        app.buttons["Profile"].tap()
        let deleteAccount = app.buttons["delete-account"]
        let profileScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(profileScrollView.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0 ..< 12 where !deleteAccount.exists {
            profileScrollView.swipeUp()
        }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 5), app.debugDescription)
        deleteAccount.tap()

        XCTAssertTrue(app.buttons["Delete account permanently"].waitForExistence(timeout: 5))
        let deletionNotice = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Apple subscription'")
        ).firstMatch
        XCTAssertTrue(
            deletionNotice.waitForExistence(timeout: 5),
            app.debugDescription
        )
        app.buttons["Delete account permanently"].tap()

        XCTAssertTrue(
            app.staticTexts["Tagalog you can actually use."].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    func testLessonCompletionShowsAdaptiveCheckIn() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestScenario",
            "mainApp",
            "-ResetLessonEducation",
            "-ResetSavedLessonWords",
            "-ResetLessonJourney"
        ]
        app.launch()

        let lessonCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'today' AND label CONTAINS[c] 'lesson'")
        ).firstMatch
        XCTAssertTrue(lessonCard.waitForExistence(timeout: 5))
        lessonCard.tap()

        XCTAssertTrue(app.staticTexts["Your 7-minute plan has 7 complete rounds."].waitForExistence(timeout: 5))
        if app.buttons["Got it"].exists {
            app.buttons["Got it"].tap()
        }

        for round in 1 ... 7 {
            XCTAssertTrue(app.staticTexts["Round \(round) of 7"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Natural speed"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["I caught the situation"].waitForExistence(timeout: 5))
            app.buttons["I caught the situation"].tap()
            if round == 3 || round == 5 {
                XCTAssertTrue(app.buttons["Check my choice"].waitForExistence(timeout: 5))
                XCTAssertEqual(
                    app.buttons.matching(
                        NSPredicate(format: "label BEGINSWITH[c] 'Listen to response:'")
                    ).count,
                    0
                )

                let wrongChoice = app.buttons[
                    round == 3
                        ? "Go straight to the intersection, then turn right."
                        : "The speaker is asking you to slow down."
                ]
                XCTAssertTrue(wrongChoice.waitForExistence(timeout: 5))
                wrongChoice.tap()
                app.buttons["Check my choice"].tap()
                XCTAssertTrue(app.buttons["Next word"].waitForExistence(timeout: 5))
                app.buttons["Next word"].tap()
            } else {
                XCTAssertTrue(
                    app.buttons["Say the whole request"].waitForExistence(timeout: 5),
                    app.debugDescription
                )

                if round == 1 {
                    let word = app.buttons["Cho, give / let"]
                    XCTAssertTrue(word.waitForExistence(timeout: 5))
                    word.tap()
                    XCTAssertTrue(app.staticTexts["IN THIS SENTENCE"].waitForExistence(timeout: 5))
                    app.buttons["Add to Vocabulary"].tap()
                    XCTAssertTrue(app.buttons["Added to Vocabulary"].waitForExistence(timeout: 5))
                    app.buttons["Close word card"].tap()
                }

                app.buttons["Say the whole request"].tap()
            }
            XCTAssertTrue(app.staticTexts["REPEAT THIS LINE"].waitForExistence(timeout: 5))
            XCTAssertTrue(
                app.staticTexts["Repeat the Tagalog line below exactly. You’re copying the line, not answering it."].exists
            )
            let continueTitle = round == 7
                ? "Finish without recording"
                : "Continue to round \(round + 1) without recording"
            if round < 7 {
                XCTAssertFalse(app.buttons["Finish today’s session"].exists)
            }
            XCTAssertTrue(app.buttons[continueTitle].waitForExistence(timeout: 5))
            app.buttons[continueTitle].tap()
        }

        XCTAssertTrue(app.staticTexts["Quick tune-up"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["How was the level?"].exists)
        XCTAssertTrue(app.staticTexts["How was the voice pace?"].exists)
        XCTAssertTrue(app.staticTexts["Guide the next lesson"].exists)
        XCTAssertFalse(app.buttons["Tune my next session"].isEnabled)
        app.buttons["Too easy"].tap()
        XCTAssertFalse(app.buttons["Tune my next session"].isEnabled)
        app.buttons["Too fast"].tap()
        app.buttons["Add a lesson topic"].tap()
        let topicField = app.textViews["Optional next lesson topic"]
        XCTAssertTrue(topicField.waitForExistence(timeout: 5))
        topicField.tap()
        topicField.typeText("Renewing my papers")
        XCTAssertTrue(app.buttons["Tune my next session"].isEnabled)
        app.buttons["Tune my next session"].tap()
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 5))
        if app.buttons["Maybe later"].exists {
            app.buttons["Maybe later"].tap()
        }
        app.buttons["Back to today"].tap()
        for _ in 0 ..< 4 {
            let keepGoing = app.buttons["Keep going"]
            guard keepGoing.waitForExistence(timeout: 1) else { break }
            keepGoing.tap()
        }
        app.buttons["Profile"].tap()
        let lessonHistory = app.staticTexts["Lesson history"]
        let profileScrollView = app.scrollViews.firstMatch
        for _ in 0 ..< 8 where !lessonHistory.exists {
            profileScrollView.swipeUp()
        }
        XCTAssertTrue(lessonHistory.waitForExistence(timeout: 5), app.debugDescription)
    }

    func testWordGymCompletionStaysIndependentFromLessonGeneration() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "mainApp", "-ResetWordReviewState"]
        app.launch()
        app.buttons["Words"].tap()

        let gotIt = app.buttons["Got it, review in 4 days"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        for index in 0..<4 {
            gotIt.tap()
            if index < 3 {
                XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
            }
        }
        XCTAssertTrue(app.staticTexts["Word gym complete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Quick tune-up"].exists)
        XCTAssertFalse(app.buttons["Tune my next session"].exists)
    }

    func testDailyReviewRunsFromTodayToCompletion() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScenario", "mainApp", "-SeedDueReviews", "-kumusta.appearance", "light"]
        app.launch()

        let start = app.buttons["dailyReviewStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), app.debugDescription)
        captureSettled("Daily review card", app: app)
        start.tap()

        var captured: Set<String> = []
        func captureOnce(_ name: String) {
            guard captured.insert(name).inserted else { return }
            captureSettled(name, app: app)
        }

        let done = app.staticTexts["Memory refreshed!"]
        let check = app.buttons["CHECK"]
        let continueButton = app.buttons["CONTINUE"]
        for _ in 0..<40 where !done.exists {
            if app.staticTexts["What does this mean?"].waitForExistence(timeout: 1)
                || app.staticTexts["Choose the Tagalog"].exists {
                let kind = app.staticTexts["What does this mean?"].exists ? "Listen" : "Pick"
                captureOnce("\(kind) question")
                app.buttons.matching(identifier: "reviewChoice").firstMatch.tap()
                check.tap()
                captureOnce("\(kind) feedback")
            } else if app.staticTexts["Build it in Tagalog"].exists {
                captureOnce("Build question")
                for _ in 0..<16 where !check.isEnabled {
                    let tiles = app.buttons.matching(identifier: "reviewTile").allElementsBoundByIndex
                    guard let tile = tiles.first(where: { $0.isEnabled && $0.isHittable }) else { break }
                    tile.tap()
                }
                captureOnce("Build filled")
                check.tap()
                if !continueButton.waitForExistence(timeout: 2) {
                    captureOnce("Build mistakes")
                    app.buttons["Show me the answer"].tap()
                }
                captureOnce("Build feedback")
            } else if app.staticTexts["Say it in Tagalog"].exists {
                captureOnce("Speak question")
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "I don")).firstMatch.tap()
                captureOnce("Speak feedback")
            }
            if continueButton.waitForExistence(timeout: 3), !done.exists {
                continueButton.tap()
            }
        }

        XCTAssertTrue(done.waitForExistence(timeout: 8), app.debugDescription)
        captureSettled("Review complete", app: app)
        continueButton.tap()
        // Today now confirms the review, or offers the rest of a backlog.
        let reviewDone = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Review done"))
            .firstMatch
        XCTAssertTrue(reviewDone.waitForExistence(timeout: 5) || start.exists, app.debugDescription)
        captureSettled("Today after review", app: app)
    }
}
