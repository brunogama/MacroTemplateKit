#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

version="$(tr -d '[:space:]' <VERSION)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "error: VERSION is not semantic: $version" >&2
	exit 1
fi
base_version="$(tr -d '[:space:]' <RELEASE_BASE_VERSION)"
if [[ ! "$base_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "error: RELEASE_BASE_VERSION is not semantic: $base_version" >&2
	exit 1
fi

assert_count() {
	local expected="$1"
	local text="$2"
	local file="$3"
	local actual
	actual="$(grep -F -c "$text" "$file" || true)"
	if [[ "$actual" != "$expected" ]]; then
		echo "error: $file contains '$text' $actual times; expected $expected" >&2
		exit 1
	fi
}

distribution="$(tr -d '[:space:]' <RELEASE_DISTRIBUTION)"
case "$distribution" in
source)
	dependency_rule="from"
	version_instruction="select version \`$version\` or later"
	installation_text="Version \`$version\` is the final source-only tag."
	;;
binary)
	dependency_rule="exact"
	version_instruction="select version \`$version\` with Xcode 16.2"
	installation_text="Tagged releases resolve to a universal macOS \`MacroTemplateKit.xcframework\`."
	;;
*)
	echo "error: unsupported release distribution: $distribution" >&2
	exit 1
	;;
esac

mtk_dependency=".package(url: \"https://github.com/brunogama/MacroTemplateKit.git\", $dependency_rule: \"$version\")"
syntax_dependency=".package(url: \"https://github.com/swiftlang/swift-syntax.git\", $dependency_rule: \"600.0.1\")"
article="Sources/MacroTemplateKit/Documentation.docc/Articles/GettingStarted.md"
guide="Sources/MacroTemplateKit/Documentation.docc/GettingStarted.md"

assert_count 2 "$mtk_dependency" README.md
assert_count 2 "$syntax_dependency" README.md
assert_count 1 "$version_instruction" README.md
assert_count 2 "$installation_text" README.md
assert_count 1 "$mtk_dependency" "$article"
assert_count 1 "$syntax_dependency" "$article"
assert_count 1 "$installation_text" "$article"
assert_count 1 "$mtk_dependency" "$guide"
assert_count 1 "$syntax_dependency" "$guide"
assert_count 1 "$installation_text" "$guide"
assert_count 1 '__VERSION__' Package.binary.swift
assert_count 1 '__CHECKSUM__' Package.binary.swift
Scripts/generate_llms_txt.sh --check

echo "release_metadata: valid ($version, $distribution, SwiftSyntax 600.0.1)"
