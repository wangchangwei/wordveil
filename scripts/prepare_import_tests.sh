#!/bin/bash
set -euo pipefail

if [[ $# != 1 ]]; then
    echo "Usage: $0 <booted-simulator-UUID>" >&2
    exit 1
fi
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_group="$(xcrun simctl get_app_container "$1" com.apple.DocumentsApp groups | awk -F '\t' '$1 == "group.com.apple.FileProvider.LocalStorage" { print $2 }')"
if [[ -z "$task_group" ]]; then
    echo "Simulator Files storage is unavailable" >&2
    exit 1
fi
task_samples="$task_group/File Provider Storage/ImportSamples"
mkdir -p "$task_samples"
cp "$task_root/Tests/Fixtures/bilingual.png" "$task_samples/import-image.png"
cp "$task_root/Tests/Fixtures/import-lesson.pdf" "$task_samples/import-lesson.pdf"
cp "$task_root/Tests/Fixtures/chinese-japanese.png" "$task_samples/chinese-japanese.png"
# A malformed image verifies that the picker can return a file the decoder rejects.
echo "Not a real PNG" > "$task_samples/broken-image.png"
echo "File import fixtures ready in On My iPhone/iPad > ImportSamples"
