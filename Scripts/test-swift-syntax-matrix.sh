#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

matrix_mode="${MTK_MATRIX_MODE:-xcode27}"
versions=("$@")
if [[ ${#versions[@]} -eq 0 ]]; then
	versions=(600.0.1 603.0.2)
fi

resolved_path="$ROOT_DIR/Package.resolved"
resolved_backup="$(mktemp)"
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
	rm -f "$resolved_backup"
}
trap cleanup EXIT

for version in "${versions[@]}"; do
	rm -f "$resolved_path"
	swift package resolve
	swift package resolve --version "$version" swift-syntax
	grep -Fq "\"version\" : \"$version\"" "$resolved_path"

	scratch_path="$ROOT_DIR/.build/swift-syntax-matrix/$version"
	case "$matrix_mode" in
	xcode27)
		Scripts/swift-package.sh build \
			--build-system swiftbuild --scratch-path "$scratch_path/swiftbuild"
		Scripts/swift-package.sh test \
			--build-system swiftbuild --scratch-path "$scratch_path/swiftbuild"
		;;
	hosted)
		Scripts/swift-package.sh build --scratch-path "$scratch_path/hosted-default"
		Scripts/swift-package.sh test --scratch-path "$scratch_path/hosted-default"
		;;
	*)
		echo "error: unsupported MTK_MATRIX_MODE '$matrix_mode'" >&2
		exit 2
		;;
	esac
	if ! swift package dump-package 2>/dev/null | grep -q '"treatAllWarnings"'; then
		Scripts/swift-package.sh build \
			--scratch-path "$scratch_path/warnings" -Xswiftc -warnings-as-errors
		Scripts/swift-package.sh test \
			--scratch-path "$scratch_path/warnings" -Xswiftc -warnings-as-errors
	fi
done
