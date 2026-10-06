import SwiftUI

struct StudyView: View {
    private enum DisplayMode: Equatable { case language(BlockLanguage), all }

    let card: StudyCard
    @Environment(\.appLanguage) private var language
    @State private var revealed: Set<UUID> = []
    @State private var showingEditor = false
    @State private var image: UIImage?
    @State private var blocks: [OCRBlock] = []
    @State private var dataError = false
    @State private var hasLoaded = false
    @State private var displayMode: DisplayMode?

    private var displayedBlocks: [OCRBlock] {
        guard let displayMode else { return blocks }
        return blocks.map { block in
            var displayed = block
            switch displayMode {
            case .language(let visibleLanguage): displayed.hidden = block.language != visibleLanguage
            case .all: displayed.hidden = false
            }
            return displayed
        }
    }

    private var selectedMode: DisplayMode? {
        if let displayMode { return displayMode }
        if blocks.allSatisfy({ !$0.hidden }) { return .all }
        for visibleLanguage in card.languagePair.languages {
            if blocks.allSatisfy({ $0.hidden == ($0.language != visibleLanguage) }) {
                return .language(visibleLanguage)
            }
        }
        return nil
    }

    private var hiddenIDs: Set<UUID> { Set(displayedBlocks.filter(\.hidden).map(\.id)) }
    private var revealedCount: Int { hiddenIDs.intersection(revealed).count }

    var body: some View {
        Group {
            if dataError {
                ContentUnavailableView(language.text("遮挡数据不可用"), systemImage: "exclamationmark.triangle",
                    description: Text(language.text("卡片数据损坏，原图仍保存在本机。")))
            } else if let image {
                VStack(spacing: 16) {
                    if !hiddenIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(language.text("轻点查看答案"), systemImage: "hand.tap")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(language.format("已揭晓 %d / %d", revealedCount, hiddenIDs.count))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(AppTheme.accent)
                                    .accessibilityIdentifier("reveal-progress")
                            }
                            ProgressView(value: Double(revealedCount), total: Double(max(1, hiddenIDs.count)))
                                .accessibilityLabel(language.format("已揭晓 %d / %d", revealedCount, hiddenIDs.count))
                        }
                        .padding(.horizontal, 4)
                    }
                    MaskCanvas(
                        image: image,
                        blocks: displayedBlocks,
                        revealed: revealed,
                        onTap: { id in
                            guard hiddenIDs.contains(id) else { return }
                            if revealed.contains(id) { revealed.remove(id) }
                            else { revealed.insert(id) }
                        }
                    )
                    .padding(12)
                    .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(AppTheme.separator, lineWidth: 0.5)
                    }
                }
                .padding(16)
                .frame(maxWidth: 1100)
            } else if hasLoaded {
                ContentUnavailableView(language.text("原图不可用"), systemImage: "photo.badge.exclamationmark")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if image != nil && !dataError {
                VStack(spacing: 12) {
                    Text(hiddenIDs.isEmpty
                        ? language.format("全部文字已显示，选择“%@”或“%@”开始练习。",
                                          language.text(card.languagePair.native.shortKey),
                                          language.text(card.languagePair.target.shortKey))
                        : language.text("点击遮挡查看答案，再点一次重新隐藏。"))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        ForEach(card.languagePair.languages, id: \.self) { choice in
                            displayButton(choice.shortKey, label: choice.onlyKey, mode: .language(choice),
                                          identifier: "study-show-" + choice.rawValue)
                        }
                        displayButton("全部", label: "全部显示", mode: .all, identifier: "study-show-all")
                    }
                }
                .frame(maxWidth: 700)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(AppTheme.canvas)
                .overlay(alignment: .top) {
                    Rectangle().fill(AppTheme.separator).frame(height: 0.5).allowsHitTesting(false)
                }
            }
        }
        .navigationTitle(card.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { LanguageToggleButton() }
            ToolbarItem(placement: .primaryAction) {
                Button(language.text("编辑")) { showingEditor = true }
                    .disabled(image == nil || dataError)
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let image {
                NavigationStack {
                    EditorView(image: image, existingCard: card) { _ in
                        revealed.removeAll()
                        displayMode = nil
                        do { blocks = try card.decodedBlocks() }
                        catch { dataError = true }
                        showingEditor = false
                    }
                }
            }
        }
        .task(id: card.imageFilename) {
            do { blocks = try card.decodedBlocks() }
            catch { dataError = true }
            let filename = card.imageFilename
            image = await Task.detached(priority: .userInitiated) {
                ImageStore.thumbnail(filename, maxPixelSize: 2400)
            }.value
            hasLoaded = true
        }
    }

    private func displayButton(_ title: String, label: String, mode: DisplayMode, identifier: String) -> some View {
        Button {
            displayMode = mode
            revealed.removeAll()
        } label: {
            Text(language.text(title))
        }
        .buttonStyle(LanguageTabButtonStyle(selected: selectedMode == mode))
        .accessibilityLabel(language.text(label))
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
    }
}
