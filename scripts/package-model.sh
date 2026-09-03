#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_SOURCE_DIR="${SUPERDICTATE_MODEL_SOURCE_DIR:-$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3}"
OUTPUT_ARCHIVE="${1:-$ROOT_DIR/dist/SuperDictate-Model-v3.zip}"
EXPECTED_CONTENT_SHA256="66e79161c28717a7869b552453eab474975e801ba5dee28a964d79f952690dff"

say() {
    printf 'SuperDictate model: %s\n' "$*"
}

fail() {
    printf 'SuperDictate model: %s\n' "$*" >&2
    exit 1
}

model_content_sha256() {
    local model_dir="$1"
    local file_manifest="$2"
    local file_count

    [[ -d "$model_dir" && ! -L "$model_dir" ]] || return 1
    for required in \
        Decoder.mlmodelc \
        Encoder.mlmodelc \
        JointDecisionv3.mlmodelc \
        Preprocessor.mlmodelc; do
        [[ -d "$model_dir/$required" && ! -L "$model_dir/$required" ]] || return 1
    done
    [[ -f "$model_dir/parakeet_vocab.json" && ! -L "$model_dir/parakeet_vocab.json" ]] || return 1

    (
        cd "$model_dir"
        {
            find \
                Decoder.mlmodelc \
                Encoder.mlmodelc \
                JointDecisionv3.mlmodelc \
                Preprocessor.mlmodelc \
                -type f -print
            printf '%s\n' parakeet_vocab.json
        } | LC_ALL=C sort | while IFS= read -r model_file; do
            /usr/bin/shasum -a 256 "$model_file"
        done
    ) > "$file_manifest" || return 1

    file_count="$(wc -l < "$file_manifest" | tr -d '[:space:]')"
    [[ "$file_count" == "21" ]] || return 1
    /usr/bin/shasum -a 256 "$file_manifest" | awk '{print $1}'
}

[[ -d "$MODEL_SOURCE_DIR" ]] || fail "Model cache not found: $MODEL_SOURCE_DIR"

STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/superdictate-model.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT
STAGED_MODEL="$STAGE_DIR/parakeet-tdt-0.6b-v3"
mkdir -p "$STAGED_MODEL"

say "Copying the pinned runtime subset..."
for item in \
    Decoder.mlmodelc \
    Encoder.mlmodelc \
    JointDecisionv3.mlmodelc \
    Preprocessor.mlmodelc \
    parakeet_vocab.json; do
    ditto "$MODEL_SOURCE_DIR/$item" "$STAGED_MODEL/$item"
done
cp "$ROOT_DIR/MODEL_ATTRIBUTION.md" "$STAGED_MODEL/MODEL_ATTRIBUTION.md"

actual_content_sha256="$(model_content_sha256 "$STAGED_MODEL" "$STAGE_DIR/model-files.sha256")" || \
    fail "Could not verify staged model files."
[[ "$actual_content_sha256" == "$EXPECTED_CONTENT_SHA256" ]] || \
    fail "Model content checksum mismatch: $actual_content_sha256"

mkdir -p "$(dirname "$OUTPUT_ARCHIVE")"
rm -f "$OUTPUT_ARCHIVE"
say "Creating $(basename "$OUTPUT_ARCHIVE")..."
ditto -c -k --norsrc --keepParent "$STAGED_MODEL" "$OUTPUT_ARCHIVE"

archive_sha256="$(shasum -a 256 "$OUTPUT_ARCHIVE" | awk '{print $1}')"
archive_size="$(du -h "$OUTPUT_ARCHIVE" | awk '{print $1}')"
say "Created $OUTPUT_ARCHIVE ($archive_size)"
say "Archive SHA-256: $archive_sha256"
say "Content SHA-256: $actual_content_sha256"
