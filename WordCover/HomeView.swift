import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct ImageDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct HomeView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \StudyCard.createdAt, order: .reverse) private var cards: [StudyCard]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var draft: ImageDraft?
    @State private var showingCamera = false
    @State private var pendingCameraImage: UIImage?
    @State private var showingCameraUnavailable = false
    @State private var errorMessage: String?
    @State private var path: [UUID] = []
    @State private var pendingCardID: UUID?
    @State private var showingFileImporter = false
    @State private var isImporting = false
    @State private var pdfDraft: ImportedPDF?
    @State private var pendingPDFImage: UIImage?
    @State private var showingClearConfirmation = false
    @State private var showingClearError = false
    @State private var revealedCardID: UUID?
    @State private var cardPendingDeletion: StudyCard?
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.text("我的学习卡片"))
                            .font(.largeTitle.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(language.text("把一页内容，变成一次练习。"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    importPanel
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.text("历史卡片"))
                                .font(.title3.weight(.semibold))
                                .accessibilityAddTraits(.isHeader)
                            Text(language.format("共 %d 张卡片", cards.count))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !cards.isEmpty {
                            Button(language.text("清空"), role: .destructive) {
                                showingClearConfirmation = true
                            }
                            .font(.subheadline)
                            .accessibilityIdentifier("clear-history")
                            .disabled(isImporting)
                        }
                    }
                    if cards.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 38, weight: .light))
                                .foregroundStyle(AppTheme.accent)
                                .accessibilityHidden(true)
                            Text(language.text("开始第一张卡片")).font(.headline)
                            Text(language.text("选择一张图片，遮住你想记住的内容。"))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                    } else {
                        LazyVGrid(columns: horizontalSizeClass == .compact
                                  ? [GridItem(.flexible())]
                                  : [GridItem(.adaptive(minimum: 340), spacing: 28)], spacing: 0) {
                            ForEach(cards) { card in
                                SwipeableCardRow(
                                    card: card,
                                    revealedCardID: $revealedCardID,
                                    onDelete: { requestDelete(card) }
                                )
                            }
                        }
                        .disabled(isImporting)
                    }
                }
                .frame(maxWidth: 940, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Wordveil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { LanguageToggleButton() } }
            .navigationDestination(for: UUID.self) { id in
                if let card = cards.first(where: { $0.id == id }) {
                    StudyView(card: card)
                } else {
                    ContentUnavailableView(language.text("卡片不存在"), systemImage: "exclamationmark.triangle")
                }
            }
            .sheet(item: $draft, onDismiss: {
                if let pendingCardID {
                    path.append(pendingCardID)
                    self.pendingCardID = nil
                }
            }) { item in
                NavigationStack {
                    EditorView(image: item.image) { card in
                        pendingCardID = card.id
                        draft = nil
                    }
                }
            }
            .sheet(item: $pdfDraft, onDismiss: {
                if let pendingPDFImage {
                    self.pendingPDFImage = nil
                    draft = ImageDraft(image: pendingPDFImage)
                }
            }) { pdf in
                NavigationStack {
                    PDFPagePicker(pdf: pdf) { image in
                        pendingPDFImage = image
                        pdfDraft = nil
                    }
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image, .pdf]) { result in
                switch result {
                case .success(let url):
                    isImporting = true
                    Task {
                        defer { isImporting = false }
                        do {
                            let imported = try await Task.detached(priority: .userInitiated) {
                                try FileImport.load(url)
                            }.value
                            switch imported {
                            case .image(let image): draft = ImageDraft(image: image)
                            case .pdf(let pdf): pdfDraft = pdf
                            }
                        } catch {
                            errorMessage = (error as? FileImportError)?.errorDescription ?? "导入失败，请确认文件已下载到本机后重试。"
                        }
                    }
                case .failure(let error): errorMessage = (error as? FileImportError)?.errorDescription ?? "导入失败，请确认文件已下载到本机后重试。"
                }
            }
            .fullScreenCover(isPresented: $showingCamera, onDismiss: {
                if let pendingCameraImage {
                    self.pendingCameraImage = nil
                    isImporting = true
                    Task {
                        defer { isImporting = false }
                        let normalized = await Task.detached(priority: .userInitiated) {
                            ImageStore.normalized(pendingCameraImage)
                        }.value
                        draft = ImageDraft(image: normalized)
                    }
                }
            }) {
                CameraPicker { image in
                    pendingCameraImage = image
                }
                .ignoresSafeArea()
            }
            .alert(language.text("无法使用相机"), isPresented: $showingCameraUnavailable) {
                Button(language.text("好"), role: .cancel) {}
            } message: {
                Text(language.text("请在有相机的 iPhone 或 iPad 上拍照，或从相册选择图片。"))
            }
            .alert(language.text("无法导入"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(language.text("好"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(language.text(errorMessage ?? "请重试。"))
            }
            .alert(language.text("清空历史卡片？"), isPresented: $showingClearConfirmation) {
                Button(language.text("取消"), role: .cancel) {}
                Button(language.text("清空"), role: .destructive) { clearHistory() }
            } message: {
                Text(language.text("这会永久删除所有历史卡片及原图。"))
            }
            .alert(language.text("清空失败"), isPresented: $showingClearError) {
                Button(language.text("好"), role: .cancel) {}
            } message: {
                Text(language.text("请重试。"))
            }
            .alert(language.text("删除卡片？"), isPresented: $showingDeleteConfirmation) {
                Button(language.text("取消"), role: .cancel) { cardPendingDeletion = nil }
                Button(language.text("删除"), role: .destructive) { deletePendingCard() }
            } message: {
                Text(language.text("这会永久删除这张卡片及原图。"))
            }
            .alert(language.text("删除失败"), isPresented: $showingDeleteError) {
                Button(language.text("好"), role: .cancel) {}
            } message: {
                Text(language.text("请重试。"))
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                guard !isImporting else { selectedPhoto = nil; return }
                isImporting = true
                Task {
                    defer { isImporting = false }
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        let normalized = await Task.detached(priority: .userInitiated) {
                            ImageStore.normalized(image)
                        }.value
                        draft = ImageDraft(image: normalized)
                    } catch {
                        errorMessage = (error as? FileImportError)?.errorDescription ?? "导入失败，请确认文件已下载到本机后重试。"
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.text("新建学习卡片"))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Label(language.text("离线可用"), systemImage: "checkmark.circle")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
            Divider()
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
                else { showingCameraUnavailable = true }
            } label: {
                ImportRowLabel(title: language.text("拍照"), symbol: "camera")
            }
            Divider()
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ImportRowLabel(title: language.text("从相册选择"), symbol: "photo")
            }
            Divider()
            Button { showingFileImporter = true } label: {
                ImportRowLabel(title: language.text("从文件导入"), symbol: "doc")
            }
            .accessibilityIdentifier("import-file")
            Divider()
            Text(language.text("支持图片和 PDF；多页 PDF 可选择其中一页。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            if isImporting {
                ProgressView(language.text("正在导入…"))
                    .font(.subheadline)
                    .padding(.top, 12)
                    .accessibilityIdentifier("import-progress")
            }
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
    }

    private func clearHistory() {
        do {
            revealedCardID = nil
            try CardLibrary.clearHistory(cards, in: modelContext)
        } catch {
            showingClearError = true
        }
    }

    private func requestDelete(_ card: StudyCard) {
        revealedCardID = nil
        cardPendingDeletion = card
        showingDeleteConfirmation = true
    }

    private func deletePendingCard() {
        guard let cardPendingDeletion else { return }
        do {
            try CardLibrary.deleteCard(cardPendingDeletion, in: modelContext)
            self.cardPendingDeletion = nil
        } catch {
            self.cardPendingDeletion = nil
            showingDeleteError = true
        }
    }

}

private struct SwipeableCardRow: View {
    @Environment(\.appLanguage) private var language
    let card: StudyCard
    @Binding var revealedCardID: UUID?
    let onDelete: () -> Void
    @GestureState private var dragTranslation: CGFloat = 0

    private let deleteActionWidth: CGFloat = 88

    private var isRevealed: Bool { revealedCardID == card.id }

    private var horizontalOffset: CGFloat {
        let startingOffset = isRevealed ? -deleteActionWidth : 0
        return min(0, max(-deleteActionWidth, startingOffset + dragTranslation))
    }

    var body: some View {
        NavigationLink(value: card.id) {
            CardTile(card: card)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label(language.text("删除"), systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: deleteActionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("delete-card-\(card.id.uuidString)")
            .offset(x: deleteActionWidth)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
        }
        .offset(x: horizontalOffset)
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture)
        .accessibilityAction(named: Text(language.text("删除")), onDelete)
        .animation(.easeOut(duration: 0.2), value: isRevealed)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -deleteActionWidth * 0.3 {
                    revealedCardID = card.id
                } else if value.translation.width > deleteActionWidth * 0.3 {
                    revealedCardID = nil
                }
            }
    }
}

private struct CardTile: View {
    @Environment(\.appLanguage) private var language
    let card: StudyCard
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "doc.text")
                        .font(.title2.weight(.ultraLight))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 68, height: 80)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(AppTheme.separator, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title).font(.headline).lineLimit(2)
                Text(language.text(card.languagePair.native.nameKey) + " → " + language.text(card.languagePair.target.nameKey))
                    .font(.caption).foregroundStyle(.secondary)
                Text(card.createdAt.formatted(.dateTime.year().month(.abbreviated).day().locale(language.locale)))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.regular))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.separator).frame(height: 0.5).allowsHitTesting(false)
        }
        .task(id: card.imageFilename) {
            let filename = card.imageFilename
            thumbnail = await Task.detached(priority: .utility) {
                ImageStore.thumbnail(filename)
            }.value
        }
    }
}

private struct ImportRowLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title).font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.regular))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
    }
}
