import SwiftUI
import UIKit

struct MaskCanvas: View {
    @Environment(\.appLanguage) private var language
    let image: UIImage
    let blocks: [OCRBlock]
    var revealed: Set<UUID> = []
    var showsOutlines = false
    var selectedID: UUID?
    var onTap: (UUID) -> Void
    var onAdjust: ((UUID) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 0 && geometry.size.height > 0 {
                let imageSize = image.size
                let scale = min(
                    geometry.size.width / max(imageSize.width, 1),
                    geometry.size.height / max(imageSize.height, 1)
                )
                let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: fitted.width, height: fitted.height)
                    ForEach(blocks) { block in
                        let rect = block.bounds.cgRect
                        let hitRect = MaskHitArea.rect(for: block.id, blocks: blocks, fittedSize: fitted)
                        let isMasked = block.hidden && !revealed.contains(block.id)
                        Button {
                            onTap(block.id)
                        } label: {
                            ZStack {
                                if isMasked {
                                    MaskSurface()
                                }
                                if showsOutlines || selectedID == block.id {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(
                                            selectedID == block.id ? Color.orange :
                                                (block.estimated ? Color.orange : AppTheme.ink),
                                            lineWidth: selectedID == block.id ? 3 : 1.5
                                        )
                                }
                            }
                            .frame(width: rect.width * fitted.width,
                                   height: rect.height * fitted.height)
                            .offset(x: rect.midX * fitted.width - hitRect.midX,
                                    y: rect.midY * fitted.height - hitRect.midY)
                            .frame(width: hitRect.width, height: hitRect.height)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(width: hitRect.width, height: hitRect.height)
                        .position(
                            x: hitRect.midX,
                            y: hitRect.midY
                        )
                        .accessibilityIdentifier("mask-\(block.id.uuidString)")
                        .allowsHitTesting(onAdjust != nil || block.hidden)
                        .accessibilityLabel(isMasked ? language.text(block.language.answerKey) : block.text)
                        .accessibilityValue(language.text(isMasked ? "已遮挡" : "已显示"))
                        .accessibilityHidden(onAdjust == nil && !block.hidden)
                        .accessibilityHint(language.text(onAdjust != nil
                            ? "点击文字切换遮挡"
                            : (isMasked ? "点击显示答案" : "点击再次遮挡")))
                        .accessibilityActions {
                            if let onAdjust {
                                Button(language.text("调整遮挡框")) { onAdjust(block.id) }
                                Button(language.text("修改文字语言")) { onAdjust(block.id) }
                            }
                        }
                        .contextMenu {
                            if let onAdjust {
                                Button(language.text("调整遮挡框")) { onAdjust(block.id) }
                                Button(language.text("修改文字语言")) { onAdjust(block.id) }
                            }
                        }
                    }
                }
                .frame(width: fitted.width, height: fitted.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}

private struct MaskSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(
                colors: [
                    Color(red: 0.64, green: 0.69, blue: 0.75),
                    Color(red: 0.50, green: 0.56, blue: 0.64),
                    Color(red: 0.37, green: 0.43, blue: 0.51)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(.white.opacity(0.30), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
    }
}
