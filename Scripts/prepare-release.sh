#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 0 ]]; then
	echo "error: prepare-release.sh does not accept arguments" >&2
	exit 2
fi

if ! command -v git-cliff >/dev/null 2>&1; then
	echo "error: git-cliff is required to prepare a release" >&2
	exit 1
fi

current_version="$(tr -d '[:space:]' <VERSION)"
current_tag="v$current_version"
next_tag="$(Scripts/next-release-version.sh)"
version="${next_tag#v}"
section="$(mktemp)"
trap 'rm -f "$section"' EXIT

git-cliff \
	--config .github/cliff.toml \
	"$current_tag..HEAD" \
	--tag "$next_tag" \
	--ignore-tags '.*' \
	--strip all \
	--output "$section"

python3 - \
	CHANGELOG.md "$section" "$current_tag" "$next_tag" \
	"$version" <<'PY'
from pathlib import Path
import re
import sys

changelog_path, section_path, current_tag, next_tag, version = sys.argv[1:]
path = Path(changelog_path)
text = path.read_text()
section = Path(section_path).read_text().strip()

if not section.startswith(f"## [{version}]"):
    raise SystemExit(f"error: generated changelog does not start with {version}")

heading = re.search(r"^## \[", text, flags=re.MULTILINE)
if heading is None:
    raise SystemExit("error: CHANGELOG.md has no release heading")
header = text[: heading.start()].rstrip()
history = text[heading.start() :]
if history.startswith("## [Unreleased]"):
    next_heading = re.search(r"^## \[", history[1:], flags=re.MULTILINE)
    if next_heading is None:
        history = ""
    else:
        history = history[next_heading.start() + 1 :]

if re.search(rf"^\[{re.escape(version)}\]:", history, flags=re.MULTILINE):
    raise SystemExit(f"error: CHANGELOG.md already contains a {version} link")

new_link = (
    f"[{version}]: https://github.com/brunogama/MacroTemplateKit/compare/"
    f"{current_tag}...{next_tag}"
)
replacement = (
    f"[Unreleased]: https://github.com/brunogama/MacroTemplateKit/compare/"
    f"{next_tag}...HEAD\n{new_link}"
)
unreleased_pattern = re.compile(r"^\[Unreleased\]:.*$", flags=re.MULTILINE)
history, count = unreleased_pattern.subn(replacement, history, count=1)
if count != 1:
    raise SystemExit("error: CHANGELOG.md has no Unreleased comparison link")

path.write_text(f"{header}\n\n{section}\n\n{history.lstrip()}")
PY

Scripts/update-release-version.sh "$version"
Scripts/check-release-metadata.sh
printf 'release_tag: %s\nrelease_version: %s\n' "$next_tag" "$version"
