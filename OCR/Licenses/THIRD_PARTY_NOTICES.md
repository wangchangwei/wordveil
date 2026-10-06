# Third-party notices

## PaddleOCR

- Upstream: <https://github.com/PaddlePaddle/PaddleOCR>
- Vendored source: official `deploy/ios_demo` inference engine
- Pinned commit: `dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf`
- License: Apache License 2.0; full text in `OCR/PaddleOCR/LICENSE`

The PP-OCRv6_small model archives are downloaded from PaddleOCR's official
model host by `scripts/fetch_ocr_models.sh` and are fixed by SHA-256 checksums.

## Clipper / polyclipping 6.4.2

- Vendored source: `OCR/PaddleOCR/ThirdParty/Clipper1`
- License: Boost Software License 1.0; full text is included beside the source

## OpenCV XCFramework

- Package: `https://github.com/yeatse/opencv-spm.git`
- Pinned package version: `4.13.0`
- Binary source: <https://github.com/yeatse/opencv-spm/releases/download/4.13.0/opencv2.xcframework.zip>
- Binary SHA-256: `41fc3bf0f2af1660e24694a3e05d5c56e5869a133cea7084a7e262d54dd5b675`
- OpenCV source version used by the package build: `4.13.0`
- Licenses: Apache License 2.0 for both the package wrapper and OpenCV

The package release does not contain a combined third-party notices resource.
The complete package and OpenCV Apache license texts are stored separately in:

- `OCR/Licenses/opencv-spm-4.13.0-APACHE-2.0.txt`
- `OCR/Licenses/opencv-4.13.0-APACHE-2.0.txt`

The selected iOS XCFramework is a static build. Its embedded build information
identifies libjpeg-turbo 3.1.2-70, libpng 1.6.53, zlib 1.3.1, KleidiCV 0.7.0,
protobuf 3.19.1, FlatBuffers 25.9.23, ADE 0.1.2e, and a bundled libwebp source
snapshot. The OpenCV build also contains the bundled SoftFloat, quirc, MSCR
chi-table, and VASOT sources. Their complete notices are stored in
`OCR/Licenses/`:

- `libjpeg-turbo-3.1.2-70-LICENSE.md`
- `libjpeg-turbo-3.1.2-70-README.md`
- `libjpeg-turbo-3.1.2-70-README.ijg`
- `libpng-1.6.53-LICENSE.txt`
- `libpng-1.6.53-README.txt`
- `zlib-1.3.1-LICENSE.txt`
- `libwebp-opencv-4.13.0-COPYING.txt`
- `kleidicv-0.7.0-APACHE-2.0.txt`
- `softfloat-opencv-4.13.0-COPYING.txt`
- `protobuf-3.19.1-LICENSE.txt`
- `protobuf-3.19.1-README.md`
- `flatbuffers-25.9.23-LICENSE.txt`
- `ade-0.1.2e-LICENSE.txt`
- `quirc-opencv-4.13.0-LICENSE.txt`
- `mscr-chi-table-opencv-4.13.0-LICENSE.txt`
- `vasot-opencv-4.13.0-LICENSE.txt`

Where the upstream build does not expose a standalone semantic version, the
filename records the exact OpenCV `4.13.0` source snapshot from which the text
was copied.

## CocoaPods dependencies

- ONNX Runtime Objective-C 1.24.3: MIT License
- Yams 5.0.6: MIT License

Full runtime dependency notices from the ONNX Runtime `v1.24.3` tag are
included in `OCR/Licenses/ONNX-Runtime-1.24.3-ThirdPartyNotices.txt`.
SHA-256: `0e07b95f3a8d6230037707c5c4a2b554d12c4cb67369669ac255635528ffcee2`.

The exact dependency versions are fixed in `Podfile`. CocoaPods generates its
own acknowledgements and lockfile during `pod install`.
