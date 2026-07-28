#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 3 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: Scripts/render-binary-manifest.sh <version> <checksum> <output>" >&2
  exit 2
fi

version="$1"
checksum="$2"
output="$3"

if [[ ! "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
  echo "error: checksum must be a 64-character lowercase SHA-256 value" >&2
  exit 2
fi

python3 - "$ROOT_DIR/Package.binary.swift" "$output" "$version" "$checksum" <<'PY'
from pathlib import Path
import sys

template_path, output_path, version, checksum = sys.argv[1:]
text = Path(template_path).read_text()

if text.count("__VERSION__") != 1 or text.count("__CHECKSUM__") != 1:
    raise SystemExit("error: binary manifest placeholders must each occur exactly once")

text = text.replace("__VERSION__", f"v{version}")
text = text.replace("__CHECKSUM__", checksum)
if "__VERSION__" in text or "__CHECKSUM__" in text:
    raise SystemExit("error: unresolved binary manifest placeholder")

Path(output_path).write_text(text)
PY

printf 'binary_manifest: %s\n' "$output"
