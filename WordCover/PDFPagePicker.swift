import SwiftUI
import UIKit

struct PDFPagePicker: View {
    @Environment(\.appLanguage) private var language
    let pdf: ImportedPDF
    let onSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var preview: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text(language.text("每次选择一页制作学习卡片。"))
                .foregroundStyle(.secondary)
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(language.text("PDF 页面预览"))
            } else if let errorMessage {
                ContentUnavailableView(language.text("无法显示页面"), systemImage: "doc.badge.ellipsis", description: Text(language.text(errorMessage)))
            } else {
                ProgressView(language.text("正在读取页面…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                Button(language.text("上一页"), systemImage: "chevron.left") { changePage(to: pageIndex - 1) }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(pageIndex == 0)
                Spacer()
                Text(language.format("第 %d 页 / 共 %d 页", pageIndex + 1, pdf.pageCount))
                    .monospacedDigit()
                    .accessibilityIdentifier("pdf-page-number")
                Spacer()
                Button(language.text("下一页"), systemImage: "chevron.right") { changePage(to: pageIndex + 1) }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(pageIndex + 1 == pdf.pageCount)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(AppTheme.separator).frame(height: 0.5).allowsHitTesting(false)
            }
        }
        .padding(16)
        .background(AppTheme.canvas)
        .navigationTitle(language.text("选择 PDF 页面"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { LanguageToggleButton() }
            ToolbarItem(placement: .cancellationAction) {
                Button(language.text("取消")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.text("使用此页")) { if let preview { onSelected(preview) } }
                    .disabled(preview == nil)
            }
        }
        .task(id: pageIndex) {
            let selectedPage = pageIndex
            do {
                let rendered = try await PDFPageRenderer.shared.render(pdf, pageIndex: selectedPage)
                guard !Task.isCancelled else { return }
                preview = rendered
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? FileImportError)?.errorDescription ?? "无法读取所选页面，请选择其他页面。"
            }
        }
    }

    private func changePage(to index: Int) {
        preview = nil
        errorMessage = nil
        pageIndex = index
    }
}
