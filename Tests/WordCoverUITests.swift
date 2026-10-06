import XCTest

final class WordCoverUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLanguageSwitchPersistsAndKeepsPDFDraftAndStudyState() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["language-toggle"].waitForExistence(timeout: 15))
        if app.buttons["language-toggle"].value as? String == "English" { app.buttons["language-toggle"].tap() }
        attachScreenshot(app, name: "home-chinese-redesign")
        app.buttons["language-toggle"].tap()
        XCTAssertTrue(app.staticTexts["My Study Cards"].exists)
        XCTAssertTrue(app.buttons["Choose Photo"].exists)
        XCTAssertTrue(app.buttons["Import File"].exists)
        attachScreenshot(app, name: "home-english-redesign")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["language-toggle"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["language-toggle"].value as? String, "English")

        selectFile(app, named: "broken-image")
        XCTAssertTrue(app.alerts["Unable to Import"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.alerts.staticTexts["The image could not be read. Choose another image."].exists)
        app.alerts.buttons["OK"].tap()
        selectFile(app, named: "import-lesson")
        XCTAssertTrue(app.staticTexts["Page 1 of 2"].waitForExistence(timeout: 15))
        app.buttons["Next Page"].tap()
        XCTAssertTrue(app.staticTexts["Page 2 of 2"].exists)
        visibleButton(app, identifier: "language-toggle").tap()
        XCTAssertTrue(app.staticTexts["第 2 页 / 共 2 页"].exists, "Changing language must preserve the selected PDF page")
        visibleButton(app, identifier: "language-toggle").tap()
        let usePage = app.buttons["Use This Page"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: usePage)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        attachScreenshot(app, name: "pdf-english-redesign")
        usePage.tap()
        XCTAssertTrue(app.buttons["Hide English"].waitForExistence(timeout: 120))
        let title = app.textFields["card-title"]
        title.tap()
        if let current = title.value as? String {
            title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        let cardName = "Language " + UUID().uuidString.prefix(6)
        title.typeText(cardName)
        app.buttons["Hide English"].tap()
        XCTAssertTrue(app.buttons["Hide English"].isSelected)
        let masked = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == 'Masked'")).firstMatch
        XCTAssertTrue(masked.exists)
        let maskID = masked.identifier
        visibleButton(app, identifier: "language-toggle").tap()
        XCTAssertTrue(app.buttons["隐藏英文"].exists)
        XCTAssertEqual(title.value as? String, cardName)
        XCTAssertEqual(app.buttons[maskID].value as? String, "已遮挡")
        visibleButton(app, identifier: "language-toggle").tap()
        attachScreenshot(app, name: "editor-english-redesign")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["editor-save"].isHittable)
        XCTAssertTrue(app.buttons["Hide English"].isHittable)
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 10), .completed)
        app.buttons["Hide English"].tap()
        let landscapeImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscapeImage.name = "editor-english-landscape"
        landscapeImage.lifetime = .keepAlways
        add(landscapeImage)
        XCUIDevice.shared.orientation = .portrait
        // A tap after a language preset must still work and move into custom mode.
        app.buttons[maskID].tap()
        XCTAssertEqual(app.buttons[maskID].value as? String, "Shown")
        XCTAssertTrue(app.buttons["Custom"].isSelected)
        app.buttons[maskID].tap()
        XCTAssertEqual(app.buttons[maskID].value as? String, "Masked")
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        app.buttons[maskID].tap()
        XCTAssertEqual(app.buttons[maskID].value as? String, "Shown")
        XCTAssertTrue(app.staticTexts["reveal-progress"].label.hasPrefix("Revealed 1 /"))
        attachScreenshot(app, name: "study-english-redesign")
        visibleButton(app, identifier: "language-toggle").tap()
        XCTAssertEqual(app.buttons[maskID].value as? String, "已显示")
        XCTAssertTrue(app.staticTexts["reveal-progress"].label.hasPrefix("已揭晓 1 /"))
        visibleButton(app, identifier: "language-toggle").tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[cardName].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["language-toggle"].value as? String, "English")
        app.staticTexts[cardName].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons[maskID].value as? String, "Masked")
        visibleButton(app, identifier: "language-toggle").tap()
    }

    @MainActor
    func testFileImageImportSaveRevealAndReopen() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        selectFile(app, named: "import-image")
        XCTAssertTrue(app.buttons["隐藏英文"].waitForExistence(timeout: 120), app.debugDescription)
        XCTAssertTrue(app.buttons["apple"].firstMatch.exists)
        let cardName = "File " + UUID().uuidString.prefix(6)
        saveAndVerifyReopening(app, cardName: cardName)
        let chinese = app.buttons["study-show-chinese"]
        let english = app.buttons["study-show-english"]
        let all = app.buttons["study-show-all"]
        XCTAssertTrue(chinese.waitForExistence(timeout: 5))
        chinese.tap()
        XCTAssertTrue(chinese.isSelected)
        let englishAnswers = app.buttons.matching(NSPredicate(format: "label == '英文答案' AND value == '已遮挡'"))
        let chineseAnswers = app.buttons.matching(NSPredicate(format: "label == '中文答案' AND value == '已遮挡'"))
        let englishCount = englishAnswers.count
        XCTAssertGreaterThan(englishCount, 0)
        XCTAssertEqual(chineseAnswers.count, 0)
        let answer = app.buttons[englishAnswers.firstMatch.identifier]
        answer.tap()
        XCTAssertEqual(answer.value as? String, "已显示")
        chinese.tap()
        XCTAssertEqual(answer.value as? String, "已遮挡")
        english.tap()
        XCTAssertTrue(english.isSelected)
        XCTAssertEqual(englishAnswers.count, 0)
        XCTAssertGreaterThan(chineseAnswers.count, 0)
        visibleButton(app, identifier: "language-toggle").tap()
        XCTAssertTrue(english.isSelected, "App language must not reset which text is visible")
        XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format: "label == 'Chinese Answer' AND value == 'Masked'")).count, 0)
        visibleButton(app, identifier: "language-toggle").tap()
        all.tap()
        XCTAssertTrue(all.isSelected)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).count, 0)
        chinese.tap()
        XCTAssertEqual(englishAnswers.count, englishCount)
        attachScreenshot(app, name: "study-show-chinese")
        english.tap()
        attachScreenshot(app, name: "study-show-english")
        all.tap()
        attachScreenshot(app, name: "study-show-all")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[cardName].waitForExistence(timeout: 15))
        app.staticTexts[cardName].tap()
        XCTAssertTrue(chinese.waitForExistence(timeout: 10))
        XCTAssertEqual(englishAnswers.count, englishCount, "Study display choices must not overwrite the saved masks")
    }

    @MainActor
    func testCardLanguagePairDefaultsJapaneseAndPersists() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        selectFile(app, named: "chinese-japanese")
        XCTAssertTrue(app.buttons["隐藏英文"].waitForExistence(timeout: 120))
        let settings = app.buttons["card-language-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertEqual(app.buttons["native-language"].value as? String, "中文")
        XCTAssertEqual(app.buttons["target-language"].value as? String, "英文")
        app.buttons["target-language"].tap()
        app.buttons["日文"].tap()
        app.buttons["card-settings-cancel"].tap()
        XCTAssertTrue(app.buttons["隐藏英文"].exists)
        settings.tap()
        XCTAssertEqual(app.buttons["target-language"].value as? String, "英文")
        app.buttons["target-language"].tap()
        app.buttons["日文"].tap()
        app.buttons["swap-card-languages"].tap()
        XCTAssertEqual(app.buttons["native-language"].value as? String, "日文")
        XCTAssertEqual(app.buttons["target-language"].value as? String, "中文")
        app.buttons["swap-card-languages"].tap()
        attachScreenshot(app, name: "card-language-settings")
        visibleButton(app, identifier: "language-toggle").tap()
        XCTAssertEqual(app.buttons["native-language"].value as? String, "Chinese")
        XCTAssertEqual(app.buttons["target-language"].value as? String, "Japanese")
        attachScreenshot(app, name: "card-language-settings-english")
        visibleButton(app, identifier: "language-toggle").tap()
        app.buttons["card-settings-done"].tap()
        XCTAssertTrue(app.buttons["隐藏日文"].waitForExistence(timeout: 5))
        app.buttons["隐藏日文"].tap()
        // Han-only Japanese needs an explicit language correction.
        let cat = app.buttons["猫"].firstMatch
        XCTAssertTrue(cat.exists)
        cat.press(forDuration: 1.2)
        app.buttons["调整遮挡框"].tap()
        app.buttons["block-language"].tap()
        app.buttons["日文"].tap()
        app.buttons["完成调整"].tap()
        app.buttons["隐藏日文"].tap()
        let title = app.textFields["card-title"]
        title.tap()
        if let current = title.value as? String {
            title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        let name = "Japanese " + UUID().uuidString.prefix(6)
        title.typeText(name)
        app.buttons["editor-save"].tap()
        let chinese = app.buttons["study-show-chinese"]
        let japanese = app.buttons["study-show-japanese"]
        XCTAssertTrue(japanese.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["study-show-english"].exists)
        chinese.tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == '日文答案' AND value == '已遮挡'")).count, 4)
        japanese.tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == '中文答案' AND value == '已遮挡'")).count, 4)
        attachScreenshot(app, name: "study-show-japanese")
        app.buttons["study-show-all"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).count, 0)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 15))
        app.staticTexts[name].tap()
        XCTAssertTrue(japanese.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == '日文答案' AND value == '已遮挡'")).count, 4)
        app.buttons["编辑"].tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertEqual(app.buttons["native-language"].value as? String, "中文")
        XCTAssertEqual(app.buttons["target-language"].value as? String, "日文")
        app.buttons["target-language"].tap()
        app.buttons["英文"].tap()
        app.buttons["card-settings-done"].tap()
        app.buttons["取消"].tap()
        XCTAssertTrue(japanese.waitForExistence(timeout: 10), "Cancelling the editor must discard language settings")
        XCTAssertFalse(app.buttons["study-show-english"].exists)
    }

    @MainActor
    func testPDFFilePageSelectionSaveAndReopen() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        selectFile(app, named: "import-lesson")
        XCTAssertTrue(app.staticTexts["选择 PDF 页面"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["第 1 页 / 共 2 页"].exists)
        XCTAssertFalse(app.buttons["上一页"].isEnabled)
        app.buttons["下一页"].tap()
        XCTAssertTrue(app.staticTexts["第 2 页 / 共 2 页"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["下一页"].isEnabled)
        app.buttons["上一页"].tap()
        app.buttons["下一页"].tap()
        let usePage = app.buttons["使用此页"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: usePage)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        attachScreenshot(app, name: "pdf-page-selection")
        usePage.tap()
        XCTAssertTrue(app.buttons["隐藏英文"].waitForExistence(timeout: 120), app.debugDescription)
        XCTAssertTrue(app.buttons["apple"].firstMatch.exists, "OCR must use page 2, not the cover page")
        XCTAssertFalse(app.buttons["hello"].firstMatch.exists)
        saveAndVerifyReopening(app, cardName: "PDF " + UUID().uuidString.prefix(6))
        attachScreenshot(app, name: "pdf-study")
    }

    @MainActor
    func testFileImportErrorAndPDFCancellationAllowRetry() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        selectFile(app, named: "broken-image")
        XCTAssertTrue(app.alerts["无法导入"].waitForExistence(timeout: 15), app.debugDescription)
        app.alerts.buttons["好"].tap()
        selectFile(app, named: "import-lesson")
        XCTAssertTrue(app.staticTexts["选择 PDF 页面"].waitForExistence(timeout: 15))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["从文件导入"].waitForExistence(timeout: 10))
        selectFile(app, named: "import-image")
        XCTAssertTrue(app.buttons["隐藏英文"].waitForExistence(timeout: 120))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["从文件导入"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testClearHistoryRequiresConfirmationAndPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        selectFile(app, named: "import-image")
        XCTAssertTrue(app.buttons["隐藏英文"].waitForExistence(timeout: 120))
        let title = "Clear History " + UUID().uuidString.prefix(6)
        let nameField = app.textFields["card-title"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        if let current = nameField.value as? String {
            nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        nameField.typeText(title)
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 15))

        let clear = app.buttons["clear-history"]
        XCTAssertTrue(clear.exists)
        clear.tap()
        XCTAssertTrue(app.alerts["清空历史卡片？"].waitForExistence(timeout: 5))
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts[title].exists)

        clear.tap()
        app.alerts.buttons["清空"].tap()
        XCTAssertTrue(app.staticTexts["开始第一张卡片"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts[title].exists)
        XCTAssertFalse(clear.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["开始第一张卡片"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts[title].exists)
    }

    @MainActor
    private func launchInChinese(_ app: XCUIApplication) {
        app.launch()
        let toggle = app.buttons["language-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        if toggle.value as? String == "English" { toggle.tap() }
    }

    @MainActor
    private func selectFile(_ app: XCUIApplication, named name: String) {
        XCTAssertTrue(app.buttons["import-file"].waitForExistence(timeout: 15))
        app.buttons["import-file"].tap()
        // Files remembers its last folder; navigate only when the desired file is absent.
        let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@ OR identifier BEGINSWITH %@", name, name)).firstMatch
        let samples = app.cells.matching(NSPredicate(format: "label == 'ImportSamples' OR label BEGINSWITH 'ImportSamples,'")).firstMatch
        if !file.waitForExistence(timeout: 15) {
            if !samples.exists {
                let browse = app.buttons.matching(NSPredicate(format: "label == 'Browse' OR label == '浏览'"))
                if let button = browse.allElementsBoundByIndex.first(where: { $0.isHittable }) { button.tap() }
                let local = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'On My iPhone' OR label == 'On My iPad' OR label == '我的iPhone' OR label == '我的iPad' OR label == '我的 iPhone' OR label == '我的 iPad'")).firstMatch
                XCTAssertTrue(local.waitForExistence(timeout: 10), app.debugDescription)
                local.tap()
            }
            XCTAssertTrue(samples.waitForExistence(timeout: 10), app.debugDescription)
            samples.tap()
        }
        XCTAssertTrue(file.waitForExistence(timeout: 10), app.debugDescription)
        file.tap()
    }

    @MainActor
    private func saveAndVerifyReopening(_ app: XCUIApplication, cardName: String) {
        app.buttons["隐藏英文"].tap()
        let title = app.textFields["卡片名称"]
        title.tap()
        if let current = title.value as? String {
            title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        title.typeText(cardName)
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10), app.debugDescription)
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).firstMatch
        XCTAssertTrue(first.exists)
        let mask = app.buttons[first.identifier]
        mask.tap()
        XCTAssertEqual(mask.value as? String, "已显示")
        mask.tap()
        XCTAssertEqual(mask.value as? String, "已遮挡")
        app.terminate()
        app.launch()
        let saved = app.staticTexts[cardName].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
        saved.tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).firstMatch.exists)
    }
    @MainActor
    func testImportMaskRevealSaveAndReopen() throws {
        let app = XCUIApplication()
        launchInChinese(app)
        XCTAssertTrue(app.buttons["从相册选择"].waitForExistence(timeout: 15))
        app.buttons["从相册选择"].tap()
        let photo = app.images["PXGGridLayout-Info"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30), app.debugDescription)
        // Photos' remote accessibility element can report non-hittable even
        // though its visible frame is valid; tap the center of that frame.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["隐藏英文"].waitForExistence(timeout: 120), app.debugDescription)
        app.buttons["隐藏英文"].tap()
        let title = app.textFields["卡片名称"]
        title.tap()
        if let current = title.value as? String {
            title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        let cardName = "MVP " + UUID().uuidString.prefix(6)
        title.typeText(cardName)
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10), app.debugDescription)
        let firstMasked = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).firstMatch
        XCTAssertTrue(firstMasked.exists)
        let mask = app.buttons[firstMasked.identifier]
        mask.tap()
        XCTAssertEqual(mask.value as? String, "已显示")
        mask.tap()
        XCTAssertEqual(mask.value as? String, "已遮挡")
        visibleButton(app, identifier: "study-show-all").tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).count, 0)
        app.buttons["study-show-chinese"].tap()
        XCTAssertEqual(mask.value as? String, "已遮挡")
        attachScreenshot(app, name: "study-masked")
        app.terminate()
        app.launch()
        let saved = app.staticTexts[cardName].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
        saved.tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mask-' AND value == '已遮挡'")).firstMatch.exists)
        app.buttons["编辑"].tap()
        XCTAssertTrue(app.buttons["隐藏中文"].waitForExistence(timeout: 10))
        visibleButton(app, identifier: "全部显示").tap()
        app.buttons["自定义"].tap()
        let apple = app.buttons["apple"].firstMatch
        XCTAssertTrue(apple.exists)
        let customID = apple.identifier
        let customMask = visibleButton(app, identifier: customID)
        customMask.tap()
        XCTAssertEqual(customMask.value as? String, "已遮挡")
        customMask.tap()
        XCTAssertEqual(customMask.value as? String, "已显示")
        customMask.tap()
        customMask.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["调整遮挡框"].waitForExistence(timeout: 5))
        app.buttons["调整遮挡框"].tap()
        app.buttons["右"].tap()
        app.buttons["完成调整"].tap()
        XCTAssertEqual(customMask.value as? String, "已遮挡", "Adjusting a box must preserve its mask")
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons[customID].value as? String, "已遮挡")
        app.buttons["编辑"].tap()
        XCTAssertTrue(app.buttons["隐藏中文"].waitForExistence(timeout: 10))
        app.buttons["隐藏中文"].tap()
        app.buttons["editor-save"].tap()
        XCTAssertTrue(app.buttons["study-show-chinese"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "study-chinese-masked")
    }

    @MainActor
    private func visibleButton(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        let buttons = app.buttons.matching(identifier: identifier)
        return buttons.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? buttons.firstMatch
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
