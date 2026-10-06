import SwiftData
import SwiftUI
import UIKit

struct EditorView: View {
    private enum EditorMode { case language, custom }
    let image: UIImage
    var existingCard: StudyCard?
    var onSaved: (StudyCard) -> Void

    @Environment(\.appLanguage) private var language
    @FocusState private var titleFocused: Bool
    @State private var presetLanguage: BlockLanguage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var blocks: [OCRBlock] = []
    @State private var selectedID: UUID?
    @State private var isRecognizing = false
    @State private var errorMessage: String?
    @State private var recognitionSeconds: Double?
    @State private var hasLoaded = false
    @State private var mode: EditorMode = .custom
    @State private var controlsHeight: CGFloat = 280
    @State private var languagePair = CardLanguagePair()
    @State private var showingLanguageSettings = false

    private var selectedIndex: Int? { blocks.firstIndex { $0.id == selectedID } }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if isRecognizing {
                    VStack(spacing: 20) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityHidden(true)
                        ProgressView(language.text("正在离线识别文字…"))
                        Text(language.text("识别在此设备完成"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MaskCanvas(
                        image: image,
                        blocks: blocks,
                        showsOutlines: mode == .custom,
                        selectedID: selectedID,
                        onTap: { id in
                            mode = .custom
                            presetLanguage = nil
                            titleFocused = false
                            selectedID = nil
                            if let index = blocks.firstIndex(where: { $0.id == id }) {
                                blocks[index].hidden.toggle()
                            }
                        },
                        onAdjust: { id in
                            titleFocused = false
                            selectedID = id
                            presetLanguage = nil
                            mode = .custom
                        }
                    )
                    .padding(12)
                    .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(AppTheme.separator, lineWidth: 0.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    if let recognitionSeconds {
                        Text(language.format("离线识别 %.1f 秒 · %d 处文字", recognitionSeconds, blocks.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if blocks.isEmpty && existingCard == nil {
                        Button(language.text("重新识别")) {
                            Task { await recognize() }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 8)
                    }
                }
            }
            .background(AppTheme.surface)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isRecognizing {
                    // Keep the input in one view tree when the keyboard changes available height.
                    ScrollView {
                        controls
                            .background {
                                GeometryReader { panel in
                                    Color.clear.preference(key: EditorControlsHeight.self, value: panel.size.height)
                                }
                            }
                    }
                    .accessibilityIdentifier("editor-controls")
                    .onPreferenceChange(EditorControlsHeight.self) { controlsHeight = $0 }
                    .frame(height: max(0, min(controlsHeight, geometry.size.height * 0.55)))
                    .background(AppTheme.canvas)
                    .overlay(alignment: .top) {
                        Rectangle().fill(AppTheme.separator).frame(height: 0.5).allowsHitTesting(false)
                    }
                }
            }
        }
        .navigationTitle(language.text(existingCard == nil ? "制作卡片" : "编辑遮挡"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { LanguageToggleButton() }
            ToolbarItem(placement: .cancellationAction) {
                Button(language.text("取消")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.text("完成"), action: save)
                    .accessibilityIdentifier("editor-save")
                    .disabled(isRecognizing || blocks.isEmpty)
            }
        }
        .alert(language.text("操作失败"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(language.text("好"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(language.text(errorMessage ?? "请重试。"))
        }
        .sheet(isPresented: $showingLanguageSettings) {
            CardLanguageSettings(languagePair: $languagePair)
        }
        .onChange(of: languagePair) { _, newPair in
            for index in blocks.indices where blocks[index].languageIsManual != true {
                blocks[index].language = TextSegmentation.classify(text: blocks[index].text, languagePair: newPair)
                blocks[index].languageNeedsReview = TextSegmentation.needsLanguageReview(text: blocks[index].text, languagePair: newPair)
            }
            selectedID = nil
            presetLanguage = nil
            mode = .custom
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            if let existingCard {
                title = existingCard.title
                languagePair = existingCard.languagePair
                do {
                    blocks = try existingCard.decodedBlocks()
                } catch {
                    errorMessage = "卡片的遮挡数据损坏，无法编辑。原图仍保存在本机。"
                }
            } else {
                title = language.format("学习卡片 %@", Date.now.formatted(.dateTime.month().day().locale(language.locale)))
                await recognize()
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil.line").foregroundStyle(AppTheme.accent)
                TextField(language.text("卡片名称"), text: $title)
                    .font(.subheadline.weight(.medium))
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { titleFocused = false }
                    .accessibilityIdentifier("card-title")
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.separator).frame(height: 0.5).allowsHitTesting(false)
            }
            Button {
                titleFocused = false
                showingLanguageSettings = true
            } label: {
                HStack {
                    Label(language.text("卡片设置"), systemImage: "slider.horizontal.3")
                    Spacer()
                    Text(language.text(languagePair.native.nameKey) + " → " + language.text(languagePair.target.nameKey))
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.subheadline)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("card-language-settings")
            if blocks.contains(where: { !languagePair.languages.contains($0.language) }) {
                Text(language.text("图片包含其他语言，可在卡片设置中切换；“全部”始终显示原文。"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text(language.text("选择要记住的内容")).font(.subheadline.weight(.semibold))
                Spacer()
                Text(language.format("%d 处已遮挡", blocks.filter(\.hidden).count))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityIdentifier("mask-count")
            }
            if let index = selectedIndex {
                adjustment(for: index)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    modeButton(languagePair.target.hideKey, icon: "character.book.closed", selected: mode == .language && presetLanguage == languagePair.target) {
                        setHidden(for: languagePair.target)
                    }
                    modeButton(languagePair.native.hideKey, icon: "character.book.closed", selected: mode == .language && presetLanguage == languagePair.native) {
                        setHidden(for: languagePair.native)
                    }
                    modeButton("自定义", icon: "hand.tap", selected: mode == .custom) {
                        mode = .custom
                        selectedID = nil
                        presetLanguage = nil
                    }
                    modeButton("全部显示", icon: "eye", selected: mode == .language && presetLanguage == nil && blocks.allSatisfy { !$0.hidden }) {
                        for index in blocks.indices { blocks[index].hidden = false }
                        selectedID = nil
                        presetLanguage = nil
                        mode = .language
                    }
                }
                if let firstUnreviewed = blocks.first(where: { $0.languageNeedsReview == true }) {
                    Button {
                        titleFocused = false
                        selectedID = firstUnreviewed.id
                        mode = .custom
                        presetLanguage = nil
                    } label: {
                        Label(language.format("检查文字语言（%d）", blocks.filter { $0.languageNeedsReview == true }.count), systemImage: "character.magnify")
                            .font(.caption)
                    }
                    .accessibilityIdentifier("review-block-languages")
                }
                Text(language.text("点击文字切换遮挡；长按文字可调整遮挡框。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 700)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.canvas)
    }

    private func modeButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            titleFocused = false
            action()
        } label: {
            Label(language.text(title), systemImage: icon)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(StudyButtonStyle(selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func adjustment(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language.format("调整：%@", blocks[index].text)).lineLimit(1)
                    .font(.subheadline.bold())
                Spacer()
                Button(language.text("完成调整")) { selectedID = nil }
                    .font(.caption)
            }
            Text(language.text("识别框偏移时，调整位置和尺寸。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(language.text("文字语言"), selection: Binding(
                get: { blocks[index].language },
                set: {
                    blocks[index].language = $0
                    blocks[index].languageNeedsReview = false
                    blocks[index].languageIsManual = true
                }
            )) {
                ForEach(BlockLanguage.allCases, id: \.self) { choice in
                    Text(language.text(choice.nameKey)).tag(choice)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("block-language")
            if blocks[index].languageNeedsReview == true {
                Text(language.text("纯汉字可能属于中文或日文，请确认语言。"))
                    .font(.caption).foregroundStyle(.secondary)
                Button(language.text("确认当前语言")) {
                    blocks[index].languageNeedsReview = false
                    blocks[index].languageIsManual = true
                }
                .font(.caption)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                adjustButton("左", systemImage: "arrow.left", index: index, dx: -0.005)
                adjustButton("右", systemImage: "arrow.right", index: index, dx: 0.005)
                adjustButton("上", systemImage: "arrow.up", index: index, dy: -0.005)
                adjustButton("下", systemImage: "arrow.down", index: index, dy: 0.005)
                adjustButton("缩小", systemImage: "minus", index: index, dw: -0.005, dh: -0.005)
                adjustButton("放大", systemImage: "plus", index: index, dw: 0.005, dh: 0.005)
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
    }

    private func adjustButton(
        _ title: String,
        systemImage: String,
        index: Int,
        dx: Double = 0,
        dy: Double = 0,
        dw: Double = 0,
        dh: Double = 0
    ) -> some View {
        Button {
            blocks[index].bounds.move(dx: dx, dy: dy)
            blocks[index].bounds.resize(dw: dw, dh: dh)
            blocks[index].estimated = false
        } label: {
            Label(language.text(title), systemImage: systemImage).labelStyle(.iconOnly)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel(language.text(title))
    }

    private func setHidden(for language: BlockLanguage) {
        for index in blocks.indices {
            blocks[index].hidden = blocks[index].language == language
        }
        selectedID = nil
        presetLanguage = language
        mode = .language
    }

    private func recognize() async {
        isRecognizing = true
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let lines = try await OCRService.recognize(image)
            let sourceImage = image
            let pair = languagePair
            let segmented = await Task.detached(priority: .userInitiated) {
                TextSegmentation.blocks(from: lines, image: sourceImage, languagePair: pair)
            }.value
            try Task.checkCancellation()
            blocks = segmented
            recognitionSeconds = CFAbsoluteTimeGetCurrent() - start
            if blocks.isEmpty {
                errorMessage = "未识别到文字。请尝试更清晰、光线更均匀的图片。"
            }
        } catch is CancellationError {
            isRecognizing = false
            return
        } catch {
            errorMessage = "识别失败，请换一张清晰图片重试。"
        }
        isRecognizing = false
    }

    private func save() {
        do {
            let cardTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existingCard {
                let previousTitle = existingCard.title
                let previousData = existingCard.blocksData
                let previousPair = existingCard.languagePair
                do {
                    existingCard.title = cardTitle.isEmpty ? language.text("学习卡片") : cardTitle
                    try existingCard.setBlocks(blocks)
                    existingCard.languagePair = languagePair
                    try modelContext.save()
                } catch {
                    existingCard.title = previousTitle
                    existingCard.blocksData = previousData
                    existingCard.languagePair = previousPair
                    throw error
                }
                onSaved(existingCard)
            } else {
                let id = UUID()
                let filename = try ImageStore.save(image, id: id)
                let card: StudyCard
                do {
                    card = try StudyCard(
                        id: id,
                        title: cardTitle.isEmpty ? language.text("学习卡片") : cardTitle,
                        imageFilename: filename,
                        blocks: blocks,
                        languagePair: languagePair
                    )
                } catch {
                    ImageStore.remove(filename)
                    throw error
                }
                do {
                    modelContext.insert(card)
                    try modelContext.save()
                    onSaved(card)
                } catch {
                    modelContext.delete(card)
                    ImageStore.remove(filename)
                    throw error
                }
            }
        } catch {
            errorMessage = "保存失败，请稍后重试。"
        }
    }
}

private struct EditorControlsHeight: PreferenceKey {
    static var defaultValue: CGFloat = 280

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CardLanguageSettings: View {
    @Binding var languagePair: CardLanguagePair
    @State private var draft: CardLanguagePair

    init(languagePair: Binding<CardLanguagePair>) {
        self._languagePair = languagePair
        self._draft = State(initialValue: languagePair.wrappedValue)
    }
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(language.text("母语"), selection: Binding(
                        get: { draft.native },
                        set: { draft = CardLanguagePair(native: $0, target: draft.target) }
                    )) {
                        ForEach(BlockLanguage.allCases.filter { $0 != draft.target }, id: \.self) { choice in
                            Text(language.text(choice.nameKey)).tag(choice)
                        }
                    }
                    .accessibilityIdentifier("native-language")
                    .accessibilityValue(language.text(draft.native.nameKey))
                    Picker(language.text("学习语言"), selection: Binding(
                        get: { draft.target },
                        set: { draft = CardLanguagePair(native: draft.native, target: $0) }
                    )) {
                        ForEach(BlockLanguage.allCases.filter { $0 != draft.native }, id: \.self) { choice in
                            Text(language.text(choice.nameKey)).tag(choice)
                        }
                    }
                    .accessibilityIdentifier("target-language")
                    .accessibilityValue(language.text(draft.target.nameKey))
                    Button {
                        draft = CardLanguagePair(native: draft.target, target: draft.native)
                    } label: {
                        Label(language.text("交换母语与学习语言"), systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityIdentifier("swap-card-languages")
                } footer: {
                    Text(language.text("每张卡片单独保存两种语言，详情页按此显示切换按钮。"))
                }
                if draft.languages.contains(.japanese) && draft.languages.contains(.chinese) {
                    Section {
                        Text(language.text("纯汉字可能属于中文或日文。返回编辑页，长按文字可修正语言；含假名的文字会识别为日文。"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .pickerStyle(.menu)
            .scrollContentBackground(.hidden)
            .background(AppTheme.canvas)
            .navigationTitle(language.text("卡片设置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { LanguageToggleButton() }
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("取消")) { dismiss() }
                        .accessibilityIdentifier("card-settings-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("完成")) {
                        languagePair = draft
                        dismiss()
                    }
                        .accessibilityIdentifier("card-settings-done")
                }
            }
        }
    }
}
