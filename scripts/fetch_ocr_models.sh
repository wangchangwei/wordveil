#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODEL_ROOT="${PROJECT_ROOT}/OCR/Models"
BASE_URL="https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0"

DET_ARCHIVE="PP-OCRv6_small_det_onnx_infer.tar"
REC_ARCHIVE="PP-OCRv6_small_rec_onnx_infer.tar"
DET_SHA256="d218f6fbf0f1c23d2161bd6ac7f5eaa6104fa89955c09290497e31008e2618e4"
REC_SHA256="d267ab077a44a0eedb1ea8f8c542d263f211de8e9d7a029bf9fcfff7e5a88fb1"

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }
command -v tar >/dev/null || { echo "error: tar is required" >&2; exit 1; }
command -v shasum >/dev/null || { echo "error: shasum is required" >&2; exit 1; }

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/wordcover-ocr-models.XXXXXX")"
cleanup() { rm -rf "${work_dir}"; }
trap cleanup EXIT

fetch_and_verify() {
  local archive="$1"
  local checksum="$2"
  local output="${work_dir}/${archive}"

  echo "Downloading ${archive}"
  curl --fail --location --retry 3 --retry-delay 2 \
    --output "${output}" "${BASE_URL}/${archive}"
  printf '%s  %s\n' "${checksum}" "${output}" | shasum -a 256 --check --status
}

fetch_and_verify "${DET_ARCHIVE}" "${DET_SHA256}"
fetch_and_verify "${REC_ARCHIVE}" "${REC_SHA256}"

tar -xf "${work_dir}/${DET_ARCHIVE}" -C "${work_dir}"
tar -xf "${work_dir}/${REC_ARCHIVE}" -C "${work_dir}"

det_source="${work_dir}/PP-OCRv6_small_det_onnx_infer"
rec_source="${work_dir}/PP-OCRv6_small_rec_onnx_infer"

for required in \
  "${det_source}/inference.onnx" \
  "${det_source}/inference.yml" \
  "${rec_source}/inference.onnx" \
  "${rec_source}/inference.yml"; do
  [[ -f "${required}" ]] || { echo "error: archive is missing ${required}" >&2; exit 1; }
done

mkdir -p "${MODEL_ROOT}/det" "${MODEL_ROOT}/rec"
install -m 0644 "${det_source}/inference.onnx" "${MODEL_ROOT}/det/inference.onnx"
install -m 0644 "${det_source}/inference.yml" "${MODEL_ROOT}/det/inference.yml"
install -m 0644 "${rec_source}/inference.onnx" "${MODEL_ROOT}/rec/inference.onnx"
install -m 0644 "${rec_source}/inference.yml" "${MODEL_ROOT}/rec/inference.yml"

echo "Installed checksum-verified PP-OCRv6_small models under ${MODEL_ROOT}"
