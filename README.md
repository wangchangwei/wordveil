# Wordveil · 挡住单词

一款纯本地的 iPhone / iPad 学习卡片 App：拍照、选择图片或导入 PDF 页面，离线识别中文、英文和日文，按每张卡片的母语 / 学习语言遮挡文字并点击查看答案。

## 开发环境

- iOS 17 或更新版本，iPhone 和 iPad
- Xcode 16 或更新版本
- CocoaPods

模型文件已包含在 OCR/Models，App 运行时不下载模型，也不调用 OCR 服务。第一次开发构建请在仓库根目录运行 pod install，然后打开生成的 WordCover.xcworkspace。在 Xcode 中选择 WordCover scheme 和模拟器构建。真机运行需在 Signing & Capabilities 中设置自己的 Development Team 和 bundle identifier。相机需在真机测试；模拟器可用相册导入。

OpenCV 使用 `yeatse/opencv-spm` 的固定版本 4.13.0，由 Xcode 的 Swift Package Manager 获取，包含真机 arm64 和模拟器 arm64 / x86_64 库片。开发环境首次安装依赖需要联网；安装后的 App 内置模型，使用时无需联网。OCR 的准确率、耗时和相机最终验收仍应以真机为准。

## 使用

1. 在首页拍照、从相册选择单张图片，或点击「从文件导入」选择图片 / PDF。PDF 先预览、选择一页，再点击「使用此页」，等待离线识别完成。
2. 编辑页点击「卡片设置」，分别选择母语与学习语言，默认中文 → 英文；支持中文、英文、日文两两组合和交换顺序。设置页「完成」应用到草稿，「取消」或下滑关闭会丢弃本次设置，卡片需点击编辑页「完成」后保存。
3. 点击对应的「隐藏英文 / 中文 / 日文」批量制作遮挡；也可直接点击任意识别框切换该处遮挡，自动转为自定义模式。
4. 如果文字框的位置不准，长按文字并选择「调整遮挡框」，再使用方向和缩放按钮调整；调整时保留原来的遮挡状态。
5. 保存卡片，学习页按母语、学习语言顺序提供两个语言按钮和「全部」。例如中英文为「中 / 英 / 全部」，中日为「中 / 日 / 全部」；选择一种语言时显示该语言，遮挡其余已识别文字，「全部」显示原文。点击遮挡可临时揭晓，再次点击恢复；可随时返回编辑遮挡。

英文单词框使用图像中的列间空隙细分 PaddleOCR 的文本区域；找不到可靠间隙时会用估算位置并显示黄色边框，供用户调整。中文按连续文字区域处理。当前不提供对 OCR 漏识文字手绘新增遮挡框。

文件导入支持 JPEG、PNG、HEIC 等系统可解码图片及 PDF，每次选择一个文件。PDF 每次选一页创建卡片，页面包含扫描图片或可选择文字均会交给 PaddleOCR 识别。文件最大 100 MB；超过 4096 像素的图片会缩小，PDF 页面渲染至最长边 2400 像素，之后保存渲染图和遮挡数据，不依赖原 PDF。密码保护的 PDF 需要先解锁。暂不支持 Word、PowerPoint 等其他文档。

文件访问使用系统选择器授予的临时权限，读取结束即释放；卡片原图目录不对「文件」App 开放。导入和翻页渲染在后台完成；PDF 渲染串行执行，快速翻页时丢弃过期结果。无需新增依赖。

## 界面与语言

界面使用 Apple 原生风格：系统字体、SF Symbols 线性图标、动态黑白灰配色。首页导入和卡片列表用细分隔线组织内容；编辑页采用轻描边按钮；学习页使用下划线标记当前显示语言。照片保留原色，遮挡使用不透底的蓝灰渐变与轻微高光边缘，不确定位置提示保持清晰可见。支持系统深色外观与动态字体。

- 首页集中提供拍照、相册和文件导入；历史卡片以紧凑图文行显示缩略图与本地化日期，iPhone 单列、iPad 宽屏采用多列布局。
- 历史卡片区可点「清空」并确认，批量删除所有已保存卡片及其本机原图；取消时保留卡片。
- 首页、编辑页、PDF 选页和学习页右上角都有地球图标 +「EN / 中」按钮，立即切换中文 / English。首次默认中文，选择会保存在本机，重启后恢复。
- 切换语言保留正在编辑的标题、遮挡、PDF 页码和学习中的答案显隐状态。卡片名称、照片内容和 OCR 原文保持原样。
- 编辑页突出当前遮挡模式和数量；单击切换遮挡，长按菜单进入调框。调框操作替换模式面板，横屏或大字体时底部控件可滚动。
- 学习页按卡片语言组合提供按钮，例如「中 / 英 / 全部」或「中 / 日 / 全部」（英文界面为 CN / EN / JP / All 中对应的三个按钮），按要显示的语言切换；再次点击同一语言按钮会收起已揭晓的答案。临时显示模式不会覆盖保存的遮挡，重新打开卡片仍使用已保存的设置。有遮挡时显示揭晓进度。界面适配深色外观，并为遮挡、语言和调整按钮提供 VoiceOver 描述。
- 系统相册、文件选择器、相机与权限弹窗遵循 iOS 的语言设置。相机权限说明及 App 系统名称已提供中文、英文资源；App 内按钮只切换本 App 页面语言。

### 卡片语言与日文识别

每张卡片独立保存语言组合；旧卡片自动默认中文 → 英文。卡片语言与 App 界面语言是两套设置，切换中文 / English 界面不会改变学习内容的语言组合。

继续使用内置 PP-OCRv6_small，无新增模型或在线接口。[固定上游版本的模型说明](https://github.com/PaddlePaddle/PaddleOCR/blob/dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf/docs/version3.x/algorithm/PP-OCRv6/PP-OCRv6.en.md)明确包含日文。

日文按连续汉字 / 假名区域遮挡，不进行日语词法分词。中日组合中的纯汉字无法仅凭字形可靠区分，因此会提示检查语言，默认归中文；可点击「检查文字语言」，或长按文字 →「修改文字语言」修正并保存。修正保留原有位置和遮挡，也不会因更换语言组合而丢失。图片含组合以外的第三种语言时保留真实分类，可更换卡片语言组合练习，或用「全部」和点按揭晓查看原文。

日文测试图片可用 `swift scripts/create_japanese_fixture.swift Tests/Fixtures/chinese-japanese.png` 重建。

## 项目结构

- WordCover/：SwiftUI 页面、SwiftData 卡片和遮挡交互
- WordCover/AppLanguage.swift：中英文文案、语言和地区格式
- WordCover/AppTheme.swift：页面配色、按钮样式和语言切换控件
- OCR/：PaddleOCR 官方 iOS 推理核心、模型及 App 接口
- scripts/fetch_ocr_models.sh：按固定 SHA-256 重新获取模型
- scripts/generate_xcode_project.py：按当前源码重新生成 Xcode 项目
- THIRD_PARTY_NOTICES.md：第三方组件和许可说明

本项目自有代码使用 MIT License；OCR 源码、模型和其他第三方组件继续遵循各自许可证，详见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

完整许可文本随 App 打包在 Licenses 目录中，包括 OpenCV 静态库中的组件以及 ONNX Runtime 的第三方声明。

PaddleOCR 源码固定在 dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf，模型文件已通过脚本校验。依赖由 Podfile.lock 和 WordCover.xcworkspace/xcshareddata/swiftpm/Package.resolved 固定。

重新生成工程时运行 `python3 scripts/generate_xcode_project.py`，随后运行 `pod install` 恢复依赖配置。日常开发直接打开 workspace，无需重新生成。真机签名设置应保留在 Xcode 中；重新生成会覆盖工程设置。

## 自动测试

Xcode 的 Product → Test 会运行单元测试与界面测试。单元测试使用随测试打包的真实中英文图片调用 PaddleOCR，另外检查分词框、边界调整及 SwiftData 持久化。

界面测试需要先将 Tests/Fixtures/bilingual.png 加入目标模拟器相册。命令行示例（用 `xcrun simctl list devices available` 找到设备 UUID）：

```sh
xcrun simctl boot <设备UUID> # 已启动的模拟器可以跳过此行
xcrun simctl bootstatus <设备UUID> -b
cp Tests/Fixtures/bilingual.png /tmp/wordcover-bilingual.png
xcrun simctl addmedia <设备UUID> /tmp/wordcover-bilingual.png
xcodebuild -workspace WordCover.xcworkspace -scheme WordCover \
  -derivedDataPath /tmp/WordCoverBuild \
  -destination 'platform=iOS Simulator,id=<设备UUID>' build-for-testing
xcrun simctl install <设备UUID> /tmp/WordCoverBuild/Build/Products/Debug-iphonesimulator/WordCover.app
bash scripts/prepare_import_tests.sh <设备UUID>
xcodebuild -workspace WordCover.xcworkspace -scheme WordCover \
  -derivedDataPath /tmp/WordCoverBuild \
  -destination 'platform=iOS Simulator,id=<设备UUID>' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test-without-building
```

测试覆盖实际相册和 Files 图片导入、PDF 翻页选择、导入失败和取消重试、语言遮挡、点击显隐、卡片保存、重启后恢复及再次编辑。新增的双语流程还检查错误提示翻译、切换中保留草稿 / PDF 页码 / 答案状态、语言重启恢复和编辑页横屏。测试截图保存在 Xcode 测试结果中。模拟器不具备真实相机，不能替代飞行模式下的真机验收。

文件测试材料位于系统 Files 的「我的 iPhone / iPad → ImportSamples」，由脚本直接准备模拟器数据，不改变生产 App 的文件访问设置。PDF / HEIC 测试材料已包含在 Tests/Fixtures；可运行 `swift scripts/create_import_fixtures.swift` 重新生成。

测试图片通过临时目录导入，避免模拟器服务读取受系统保护的 Documents 工作目录时阻塞。

## 本次验证（2026-10-04）

环境：Xcode 27.0（27A266a），Apple Silicon，App 最低部署版本 iOS 17。

| 验证 | 结果 |
| --- | --- |
| iPhone 17 / iOS 26.4 模拟器 | 25 项单元测试及 5 项完整界面流程通过，共 30 项，无失败或跳过 |
| iPad A16 / iOS 26.4 模拟器 | 同样 30 项测试通过，无失败或跳过 |
| iOS arm64 Release 构建 | 通过；构建时关闭签名，真机运行需配置 Development Team |
| Xcode Debug 模拟器静态分析 | 成功；上游 Clipper 有 1 处未使用赋值警告（clipper.cpp:3904） |
| 四个打包模型文件 | SHA256SUMS 校验通过 |

界面流程使用真实系统相册、系统 Files 选择器和 PaddleOCR，检查图片文件导入、PDF 来回翻页后选择第二页、损坏图片提示、取消 PDF 后重试、英文/中文遮挡、点击答案、全部显隐、卡片保存、重启恢复、自定义点选和长按调框。单元测试另覆盖真实 HEIC、JPEG EXIF 方向、图片降采样、读取大小限制、PDF 四种旋转与非零裁剪区域、越界页码及渲染取消。测试图覆盖中英对照表及混合句子；尚未使用真实课本照片验收。

同一测试图在本机 Debug 模拟器中的 OCR 耗时约 3.9～12.4 秒（含模型加载，受系统负载影响）。当前无法据此判断真机是否达到 3～5 秒。此机器仅连接了模拟器，真机拍照、飞行模式、12MP 教材照片准确率及真机峰值内存仍待验证。可在 Xcode Instruments 的 Allocations / Time Profiler 中记录这些指标。

后续的定向模拟器验证还覆盖语言组合设置、旧 SwiftData 数据迁移、中文 / 英文 / 全部显示模式，以及重启后恢复。中日语言设置和学习流程在 iPhone 17、iPad A16（iOS 26.4）通过；显示模式流程也分别在两种设备上通过。32 项单元测试涵盖日文分类、旧 OCR JSON 兼容、真实中日样例识别及语言组合持久化。

这份验证记录来自本机模拟器；仓库不包含本机测试日志、截图或 `.xcresult` 结果包。最后一次键盘工具栏精简后的 iPad 定向测试因 CoreSimulator 无法启动测试 runner 而未能执行，不计为通过。iPad 横屏旋转也仍有未解决的模拟器验证缺口。本项目尚未做真机拍照、断网、真实教材照片或峰值内存验收。

静态分析记录到上游 Clipper 的一处未使用赋值警告；SwiftUI 长按菜单曾出现视图层级警告，未导致测试失败。对文字边界不确定时，App 会显示黄色提示供用户检查和手动调整。

## 验收清单

- iPhone 与 iPad：中英混排、单词表、教材照片的识别与遮挡对齐
- 断网：拍照或导入后仍可识别、保存和学习
- 自定义：单词点选、框位置调整、保存后再次编辑
- 学习：单个及全部显隐、关闭再打开卡片后数据保留
- 异常：无识别结果、相机不可用、图片导入失败
- 真机：记录首次和后续 OCR 耗时与内存占用，评估 3～5 秒体验目标
- 真机：用至少一张 4032×3024 教材照片检查 1600 像素 OCR 缩放后的准确率、峰值内存与遮挡位置

不依赖 Xcode 的分词间隙检查可运行：swiftc WordCover/WordGapLocator.swift Tests/WordGapLocatorCheck.swift -o /tmp/wordcover-gap-check && /tmp/wordcover-gap-check。
