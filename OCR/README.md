# Offline PaddleOCR integration

This directory vendors the inference core from PaddleOCR's official
`deploy/ios_demo` at commit
`dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf`. The app-facing API is:

```swift
let lines = try await OCRService.recognize(image)
```

Each `OCRLine.rect` is normalized to `[0, 1]`, uses a top-left origin, and
matches the UIImage's displayed orientation.

## One-time setup

The checked-in Xcode project already includes the source files, bridge header,
ARC, native search paths, models, licenses, and the pinned OpenCV Swift Package.
For normal development, run `pod install` and open `WordCover.xcworkspace`.
The following documents the integration settings if rebuilding the project:

1. To restore missing models, run `./scripts/fetch_ocr_models.sh` while online. The script verifies the
   pinned PP-OCRv6_small archives before installing them.
2. Run `pod install`, then open the generated `.xcworkspace`.
3. Add `OCR/OCR-Bridging-Header.h` as `SWIFT_OBJC_BRIDGING_HEADER`.
4. Compile `OCR/OCRService.swift`, all files in `OCR/PaddleOCR/Engine`, and
   `OCR/PaddleOCR/ThirdParty/Clipper1` in the WordCover target.
5. Add header search paths for `OCR/PaddleOCR/Engine` and
   `OCR/PaddleOCR/ThirdParty/Clipper1`, plus
   `$(PODS_ROOT)/onnxruntime-objc/objectivec` and
   `$(PODS_ROOT)/onnxruntime-objc/objectivec/include`.
6. Copy `OCR/Models` into the app bundle as a folder reference named `Models`.

Match the official sample's native build settings: Swift 5 language mode,
`CLANG_CXX_LANGUAGE_STANDARD = gnu++20`, and linker flag
`-Wl,-no_warn_duplicate_libraries`.

The only network operations are the explicit developer setup commands above.
The application itself performs detection and recognition entirely on device.
