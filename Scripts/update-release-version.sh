#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "error: expected one semantic version argument (for example, 1.2.3)" >&2
	exit 2
fi

version="$1"

python3 - "$ROOT_DIR" "$version" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
version = sys.argv[2]
current_version = (root / "VERSION").read_text().strip()
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", current_version):
    raise SystemExit(f"error: invalid current VERSION: {current_version}")

replacements = {
    root / "README.md": [
        (
            r'(\.package\(url: "https://github\.com/brunogama/'
            r'MacroTemplateKit\.git", )(?:from|exact): "[0-9]+\.[0-9]+\.[0-9]+"',
            rf'\1exact: "{version}"',
            2,
        ),
        (
            r'(\.package\(url: "https://github\.com/swiftlang/'
            r'swift-syntax\.git", )(?:from|exact): "[0-9]+\.[0-9]+\.[0-9]+"',
            r'\1exact: "600.0.1"',
            2,
        ),
        (
            r'select version `[0-9]+\.[0-9]+\.[0-9]+` '
            r'(?:or later|with Xcode 16\.2)',
            f'select version `{version}` with Xcode 16.2',
            1,
        ),
    ],
    root / "Sources/MacroTemplateKit/Documentation.docc/GettingStarted.md": [
        (
            r'(\.package\(url: "https://github\.com/brunogama/'
            r'MacroTemplateKit\.git", )(?:from|exact): "[0-9]+\.[0-9]+\.[0-9]+"',
            rf'\1exact: "{version}"',
            1,
        ),
        (
            r'(\.package\(url: "https://github\.com/swiftlang/'
            r'swift-syntax\.git", )(?:from|exact): "[0-9]+\.[0-9]+\.[0-9]+"',
            r'\1exact: "600.0.1"',
            1,
        ),
    ],
    root / "Sources/MacroTemplateKit/Documentation.docc/Articles/GettingStarted.md": [
        (
            r'(\.package\(url: "https://github\.com/brunogama/'
            r'MacroTemplateKit\.git", )(?:from|exact): "[0-9]+\.[0-9]+\.[0-9]+"',
            rf'\1exact: "{version}"',
            1,
        ),
        (
            r'(\.package\(url: "https://github\.com/swiftlang/'
            r'swift-syntax\.git", )(?:from|exact): "[0-9]+\.[0-9]+\.[0-9]+"',
            r'\1exact: "600.0.1"',
            1,
        ),
    ],
}

legacy_installation = """Version `0.1.0` is the final source-only tag. Starting with the next approved
release, tags resolve to a universal macOS `MacroTemplateKit.xcframework`
pinned to Xcode 16.2, Swift 6.0, and SwiftSyntax 600.0.1."""
binary_installation = """Tagged releases resolve to a universal macOS `MacroTemplateKit.xcframework`.
The binary is pinned to Xcode 16.2, Swift 6.0, and SwiftSyntax 600.0.1;
keep both package dependencies exact as shown above."""

for path, edits in replacements.items():
    text = path.read_text()
    for pattern, replacement, expected_count in edits:
        text, count = re.subn(pattern, replacement, text)
        if count != expected_count:
            raise SystemExit(
                f"error: {path.relative_to(root)} matched {count} times; "
                f"expected {expected_count}: {pattern}"
            )
    text = text.replace(legacy_installation, binary_installation)
    expected_installations = 2 if path.name == "README.md" else 1
    if text.count(binary_installation) != expected_installations:
        raise SystemExit(
            f"error: {path.relative_to(root)} has invalid release installation text"
        )
    path.write_text(text)

(root / "RELEASE_BASE_VERSION").write_text(f"{current_version}\n")
(root / "VERSION").write_text(f"{version}\n")
(root / "RELEASE_DISTRIBUTION").write_text("binary\n")
PY

"$ROOT_DIR/Scripts/generate_llms_txt.sh"
echo "release_version: $version"
