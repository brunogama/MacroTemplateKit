#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/mtk-release-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p \
	"$fixture/Scripts" \
	"$fixture/Sources/MacroTemplateKit/Documentation.docc/Articles"
cp "$ROOT_DIR/CHANGELOG.md" "$fixture/"
cp "$ROOT_DIR/Package.binary.swift" "$fixture/"
cp "$ROOT_DIR/README.md" "$fixture/"
cp "$ROOT_DIR/RELEASE_BASE_VERSION" "$fixture/"
cp "$ROOT_DIR/RELEASE_DISTRIBUTION" "$fixture/"
cp "$ROOT_DIR/VERSION" "$fixture/"
cp "$ROOT_DIR/Sources/MacroTemplateKit/Documentation.docc/GettingStarted.md" \
	"$fixture/Sources/MacroTemplateKit/Documentation.docc/"
cp "$ROOT_DIR/Sources/MacroTemplateKit/Documentation.docc/Articles/GettingStarted.md" \
	"$fixture/Sources/MacroTemplateKit/Documentation.docc/Articles/"
cp \
	"$ROOT_DIR/Scripts/check-release-metadata.sh" \
	"$ROOT_DIR/Scripts/generate_llms_txt.sh" \
	"$ROOT_DIR/Scripts/next-release-version.sh" \
	"$ROOT_DIR/Scripts/render-binary-manifest.sh" \
	"$ROOT_DIR/Scripts/update-release-version.sh" \
	"$fixture/Scripts/"
chmod +x "$fixture/Scripts/"*.sh

"$fixture/Scripts/update-release-version.sh" 9.8.7
"$fixture/Scripts/check-release-metadata.sh"
"$fixture/Scripts/update-release-version.sh" 9.8.8
"$fixture/Scripts/check-release-metadata.sh"
test "$(cat "$fixture/RELEASE_BASE_VERSION")" = "9.8.7"

(
	cd "$fixture"
	git init -q
	git config user.name "Release Test"
	git config user.email "release-test@example.com"
	git add .
	git commit -qm "chore: seed release fixture"
	git tag v9.8.8

	echo fix >release-test.txt
	git add release-test.txt
	git commit -qm "fix: correct release fixture"
	test "$(Scripts/next-release-version.sh)" = "v9.8.9"

	echo feature >>release-test.txt
	git add release-test.txt
	git commit -qm "feat: extend release fixture"
	test "$(Scripts/next-release-version.sh)" = "v9.9.0"

	echo breaking >>release-test.txt
	git add release-test.txt
	git commit -qm "feat(api)!: change release fixture contract"
	test "$(Scripts/next-release-version.sh)" = "v10.0.0"
)

checksum="$(printf 'a%.0s' {1..64})"
manifest="$fixture/RenderedPackage.swift"
"$fixture/Scripts/render-binary-manifest.sh" 9.8.8 "$checksum" "$manifest"
grep -Fq \
	'releases/download/v9.8.8/MacroTemplateKit.xcframework.zip' \
	"$manifest"
grep -Fq "checksum: \"$checksum\"" "$manifest"
if grep -Eq '__VERSION__|__CHECKSUM__' "$manifest"; then
	echo "error: rendered binary manifest contains a placeholder" >&2
	exit 1
fi

cp "$manifest" "$fixture/Package.swift"
swift package dump-package --package-path "$fixture" >/dev/null

echo "release_automation_tests: passed"
