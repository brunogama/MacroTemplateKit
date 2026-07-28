#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_SYNTAX_VERSION="600.0.1"

usage() {
	echo "usage: Scripts/build-release-xcframework.sh <version> <output-directory>" >&2
}

if [[ $# -ne 2 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	usage
	exit 2
fi

version="$1"
output_dir="$2"

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "error: the release XCFramework must be built on macOS" >&2
	exit 1
fi

xcode_version="$(xcodebuild -version | sed -n '1p')"
if [[ "$xcode_version" != "Xcode 16.2" ]]; then
	echo "error: binary releases require Xcode 16.2; found $xcode_version" >&2
	exit 1
fi

for command in git libtool lipo python3 swift xcodebuild zip; do
	if ! command -v "$command" >/dev/null 2>&1; then
		echo "error: required command is unavailable: $command" >&2
		exit 1
	fi
done

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/mtk-release.XXXXXX")"
resolved_path="$ROOT_DIR/Package.resolved"
resolved_backup="$work_dir/Package.resolved.backup"
resolved_existed=false

if [[ -f "$resolved_path" ]]; then
	cp "$resolved_path" "$resolved_backup"
	resolved_existed=true
fi

cleanup() {
	if [[ "$resolved_existed" == true ]]; then
		cp "$resolved_backup" "$resolved_path"
	else
		rm -f "$resolved_path"
	fi
	rm -rf "$work_dir"
}
trap cleanup EXIT

cd "$ROOT_DIR"
rm -f "$resolved_path"
swift package resolve
swift package resolve --version "$SWIFT_SYNTAX_VERSION" swift-syntax
grep -Fq "\"version\" : \"$SWIFT_SYNTAX_VERSION\"" "$resolved_path"

archive_path="$work_dir/MacroTemplateKit.xcarchive"
derived_data="$work_dir/DerivedData"
xcodebuild archive \
	-scheme MacroTemplateKit \
	-destination "generic/platform=macOS" \
	-archivePath "$archive_path" \
	-derivedDataPath "$derived_data" \
	-configuration Release \
	SKIP_INSTALL=NO \
	BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
	ONLY_ACTIVE_ARCH=NO \
	CODE_SIGNING_ALLOWED=NO

object_file="$(
	/usr/bin/find "$archive_path/Products" -name MacroTemplateKit.o -type f
)"
module_dir="$(
	/usr/bin/find "$derived_data" \
		-path '*/BuildProductsPath/Release/MacroTemplateKit.swiftmodule' \
		-type d
)"
generated_header="$(
	/usr/bin/find "$derived_data" \
		-path '*/GeneratedModuleMaps/MacroTemplateKit-Swift.h' \
		-type f
)"

for artifact in "$object_file" "$module_dir" "$generated_header"; do
	if [[ -z "$artifact" || ! -e "$artifact" ]]; then
		echo "error: archive did not produce every required framework input" >&2
		exit 1
	fi
done

framework="$work_dir/MacroTemplateKit.framework"
mkdir -p \
	"$framework/Headers" \
	"$framework/Modules/MacroTemplateKit.swiftmodule"
libtool -static -o "$framework/MacroTemplateKit" "$object_file"
cp "$generated_header" "$framework/Headers/"
cp -R "$module_dir/." "$framework/Modules/MacroTemplateKit.swiftmodule/"

python3 - "$framework/Info.plist" "$version" <<'PY'
import plistlib
import sys

path, version = sys.argv[1:]
info = {
    "CFBundleIdentifier": "com.brunogama.MacroTemplateKit",
    "CFBundleName": "MacroTemplateKit",
    "CFBundlePackageType": "FMWK",
    "CFBundleShortVersionString": version,
    "CFBundleVersion": version,
    "MinimumOSVersion": "13.0",
}
with open(path, "wb") as output:
    plistlib.dump(info, output, sort_keys=True)
PY

xcframework="$work_dir/MacroTemplateKit.xcframework"
xcodebuild -create-xcframework \
	-allow-internal-distribution \
	-framework "$framework" \
	-output "$xcframework"

architectures="$(lipo -archs "$framework/MacroTemplateKit")"
for architecture in arm64 x86_64; do
	if [[ " $architectures " != *" $architecture "* ]]; then
		echo "error: release binary is missing $architecture" >&2
		exit 1
	fi
done

artifact="$output_dir/MacroTemplateKit.xcframework.zip"
rm -f "$artifact"
(
	cd "$work_dir"
	COPYFILE_DISABLE=1 zip -X -q -r "$artifact" MacroTemplateKit.xcframework
)
unzip -q "$artifact" -d "$work_dir/Packaged"
packaged_xcframework="$work_dir/Packaged/MacroTemplateKit.xcframework"
packaged_binary="$packaged_xcframework/macos-arm64_x86_64/"
packaged_binary+="MacroTemplateKit.framework/MacroTemplateKit"
architectures="$(lipo -archs "$packaged_binary")"
for architecture in arm64 x86_64; do
	if [[ " $architectures " != *" $architecture "* ]]; then
		echo "error: packaged binary is missing $architecture" >&2
		exit 1
	fi
done

consumer="$work_dir/Consumer"
mkdir -p "$consumer/Sources/Consumer"
cp -R "$packaged_xcframework" "$consumer/"
cat >"$consumer/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "MacroTemplateKitReleaseConsumer",
	platforms: [.macOS(.v13)],
	dependencies: [
		.package(
			url: "https://github.com/swiftlang/swift-syntax.git",
			exact: "$SWIFT_SYNTAX_VERSION"
		)
	],
	targets: [
		.executableTarget(
			name: "Consumer",
			dependencies: [
				"MacroTemplateKit",
				.product(name: "SwiftSyntax", package: "swift-syntax"),
				.product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
			]
		),
		.binaryTarget(
			name: "MacroTemplateKit",
			path: "MacroTemplateKit.xcframework"
		),
	]
)
SWIFT
cat >"$consumer/Sources/Consumer/main.swift" <<'SWIFT'
import MacroTemplateKit
import SwiftSyntax

let expression: ExprSyntax = try Renderer.render(
	Template<Void>.literal(.integer(42))
)
print(expression.description)
SWIFT
swift build --package-path "$consumer" -c release
consumer_output="$("$consumer/.build/release/Consumer")"
if [[ "$consumer_output" != "42" ]]; then
	echo "error: release consumer returned unexpected output: $consumer_output" >&2
	exit 1
fi

checksum="$(swift package compute-checksum "$artifact")"
printf '%s\n' "$checksum" >"$output_dir/checksum.txt"
printf '%s\n' "$SWIFT_SYNTAX_VERSION" >"$output_dir/swift-syntax-version.txt"
printf 'artifact: %s\nchecksum: %s\narchitectures: %s\n' \
	"$artifact" "$checksum" "$architectures"
