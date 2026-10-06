import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"

    static let storageKey = "appLanguage"

    static var current: AppLanguage {
        guard let storedValue = UserDefaults.standard.string(forKey: storageKey) else {
            return .chinese
        }
        return AppLanguage(rawValue: storedValue) ?? .chinese
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    func text(_ key: String) -> String {
        guard self == .english else { return key }
        return Self.englishTranslations[key] ?? key
    }

    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: args)
    }

    private static let englishTranslations: [String: String] = [
        "挡住单词": "Wordveil",
        "卡片设置": "Card Settings",
        "图片包含其他语言，可在卡片设置中切换；“全部”始终显示原文。": "This image contains other languages. Change the card settings to practice them; All always shows the original.",
        "母语": "Native Language",
        "学习语言": "Learning Language",
        "交换母语与学习语言": "Swap Languages",
        "每张卡片单独保存两种语言，详情页按此显示切换按钮。": "Each card saves its own language pair for the study buttons.",
        "纯汉字可能属于中文或日文。返回编辑页，长按文字可修正语言；含假名的文字会识别为日文。": "Han characters can be Chinese or Japanese. Touch and hold text in the editor to correct its language. Text with kana is identified as Japanese.",
        "纯汉字可能属于中文或日文，请确认语言。": "Han characters can be Chinese or Japanese. Please check the language.",
        "确认当前语言": "Confirm Language",
        "检查文字语言（%d）": "Review text languages (%d)",
        "文字语言": "Text Language",
        "修改文字语言": "Change Text Language",
        "日文": "Japanese",
        "日": "JP",
        "隐藏日文": "Hide Japanese",
        "只显示日文": "Show Japanese Only",
        "日文答案": "Japanese Answer",
        "未识别到文字。请尝试更清晰、光线更均匀的图片。": "No text was found. Try a clearer image with more even lighting.",
        "把一页内容，变成一次练习。": "Turn any page into a practice session.",
        "纸上内容，随手复习": "Review anything on paper, anytime",
        "新建学习卡片": "New Study Card",
        "拍照、导入、开始回忆。": "Capture, import, and start recalling.",
        "图片与 PDF": "Images & PDF",
        "离线可用": "Works Offline",
        "保存在此设备": "Saved on This Device",
        "开始第一张卡片": "Create Your First Card",
        "选择一张图片，遮住你想记住的内容。": "Choose an image and hide what you want to remember.",
        "点击新建，开始练习": "Tap New to start practicing",
        "我的卡片": "My Cards",
        "共 %d 张卡片": "%d cards",
        "语言遮挡": "Language Masks",
        "自定义": "Custom",
        "遮挡英文": "Mask English",
        "遮挡中文": "Mask Chinese",
        "轻点文字，选择要遮挡的答案。": "Tap text to choose the answers to hide.",
        "长按文字可微调遮挡位置。": "Touch and hold text to fine-tune its mask.",
        "%d 处已遮挡": "%d masked",
        "点击遮挡查看答案，再点一次重新隐藏。": "Tap a mask to reveal the answer, then tap again to hide it.",
        "已揭晓 %d / %d": "Revealed %d / %d",
        "全部文字已显示，选择“%@”或“%@”开始练习。": "All text is visible. Choose %@ or %@ to practice.",
        "只显示中文": "Show Chinese Only",
        "只显示英文": "Show English Only",
        "重新练习": "Practice Again",
        "图片无法读取，请重新选择。": "The image could not be read. Choose it again.",
        "导入失败，请确认文件已下载到本机后重试。": "Import failed. Make sure the file is downloaded to this device, then try again.",
        "保存失败，请稍后重试。": "Save failed. Try again in a moment.",
        "识别失败，请换一张清晰图片重试。": "Recognition failed. Try a clearer image.",
        "第 %d 页 / 共 %d 页": "Page %d of %d",
        "离线识别 %.1f 秒 · %d 处文字": "Offline recognition %.1f sec · %d text regions",
        "调整：%@": "Adjust: %@",
        "学习卡片 %@": "Study Card %@",
        "选择要记住的内容": "Choose What to Remember",
        "点选遮挡": "Tap to Mask",
        "显示原文": "Show Original",

        "我的学习卡片": "My Study Cards",
        "拍一张，遮住答案，随时复习。": "Capture it, hide the answers, and review anytime.",
        "拍照": "Take Photo",
        "从相册选择": "Choose Photo",
        "从文件导入": "Import File",
        "支持图片和 PDF；多页 PDF 可选择其中一页。": "Supports images and PDFs. Choose one page from a multi-page PDF.",
        "正在导入文件…": "Importing file…",
        "正在导入…": "Importing…",
        "历史卡片": "Previous Cards",
        "清空": "Clear All",
        "删除": "Delete",
        "清空历史卡片？": "Clear Previous Cards?",
        "这会永久删除所有历史卡片及原图。": "This permanently deletes all previous cards and their original images.",
        "清空失败": "Could Not Clear Cards",
        "删除卡片？": "Delete This Card?",
        "这会永久删除这张卡片及原图。": "This permanently deletes this card and its original image.",
        "删除失败": "Could Not Delete Card",
        "还没有学习卡片": "No Study Cards Yet",
        "拍照、选择图片或导入 PDF 开始制作。": "Take a photo, choose an image, or import a PDF to get started.",
        "卡片不存在": "Card Not Found",
        "无法使用相机": "Camera Unavailable",
        "请在有相机的 iPhone 或 iPad 上拍照，或从相册选择图片。": "Take a photo on an iPhone or iPad with a camera, or choose an image from Photos.",
        "无法导入": "Unable to Import",
        "请重试。": "Please try again.",

        "正在离线识别文字…": "Recognizing text offline…",
        "识别在此设备完成": "Recognition runs on this device",
        "重新识别": "Recognize Again",
        "制作卡片": "Create Card",
        "编辑遮挡": "Edit Masks",
        "取消": "Cancel",
        "完成": "Done",
        "操作失败": "Action Failed",
        "卡片的遮挡数据损坏，无法编辑。原图仍保存在本机。": "This card's mask data is damaged and cannot be edited. The original image is still saved on this device.",
        "学习卡片": "Study Card",
        "卡片名称": "Card Name",
        "隐藏英文": "Hide English",
        "隐藏中文": "Hide Chinese",
        "全部显示": "Show All",
        "点击文字切换遮挡；长按文字可调整遮挡框。": "Tap text to toggle its mask. Touch and hold to adjust the mask.",
        "点“自定义”可逐个选择文字遮挡。": "Tap Custom to choose individual text to mask.",
        "调整遮挡框": "Adjust Mask",
        "完成调整": "Finish Adjusting",
        "识别框偏移时，调整位置和尺寸。": "Adjust the position and size when a recognition box is misaligned.",
        "左": "Left",
        "右": "Right",
        "上": "Up",
        "下": "Down",
        "缩小": "Smaller",
        "放大": "Larger",
        "未识别到中英文文字。请尝试更清晰、光线更均匀的图片。": "No Chinese or English text was found. Try a clearer image with more even lighting.",
        "离线识别失败：%@": "Offline recognition failed: %@",
        "请先选择要遮挡的文字": "Choose text to hide first",
        "收起键盘": "Dismiss Keyboard",

        "遮挡数据不可用": "Mask Data Unavailable",
        "卡片数据损坏，原图仍保存在本机。": "The card data is damaged. The original image is still saved on this device.",
        "全部隐藏": "Hide All",
        "原图不可用": "Original Image Unavailable",
        "编辑": "Edit",
        "轻点查看答案": "Tap to Reveal",

        "英文答案": "English Answer",
        "中文答案": "Chinese Answer",
        "已遮挡": "Masked",
        "已显示": "Shown",
        "点击显示答案": "Tap to reveal the answer",
        "点击文字": "Tap text",
        "点击文字切换遮挡": "Tap to toggle the mask",
        "点击再次遮挡": "Tap to hide the answer again",

        "请选择图片文件或 PDF。": "Choose an image file or PDF.",
        "图片无法读取，请选择其他图片。": "The image could not be read. Choose another image.",
        "PDF 无法读取或没有可用页面，请选择其他文件。": "The PDF could not be read or has no usable pages. Choose another file.",
        "此 PDF 需要密码，请先解锁后再导入。": "This PDF requires a password. Unlock it before importing.",
        "无法读取所选页面，请选择其他页面。": "The selected page could not be read. Choose another page.",
        "文件超过 100 MB，请先压缩图片或拆分 PDF。": "The file is larger than 100 MB. Compress the image or split the PDF first.",

        "每次选择一页制作学习卡片。": "Choose one page at a time to create a study card.",
        "PDF 页面预览": "PDF Page Preview",
        "无法显示页面": "Unable to Display Page",
        "正在读取页面…": "Loading page…",
        "上一页": "Previous Page",
        "下一页": "Next Page",
        "选择 PDF 页面": "Choose PDF Page",
        "使用此页": "Use This Page",

        "好": "OK",
        "语言": "Language",
        "中": "CN",
        "英": "EN",
        "全部": "All",
        "中文": "Chinese",
        "英文": "English",
        "切换到中文": "Switch to Chinese",
        "切换到英文": "Switch to English"
    ]
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .chinese
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
