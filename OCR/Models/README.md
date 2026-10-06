# Bundled OCR models

The required files are checked in. To restore them, run `./scripts/fetch_ocr_models.sh`. It downloads the pinned
PP-OCRv6_small detection and recognition archives, verifies their SHA-256
checksums, and installs the four required files here.

The Xcode app target must copy this directory as a folder reference named
`Models`, preserving `Models/det` and `Models/rec` in the application bundle.
Inference never downloads a model at runtime.

Validate the checked-in files with `cd OCR/Models && shasum -a 256 -c SHA256SUMS`.
