#!/usr/bin/env bash
# Selects a known-good Xcode on a CI runner.
#
# The workflows used to hardcode `sudo xcode-select -s /Applications/Xcode_16.2.app`.
# GitHub rotates Xcode versions out of the runner images, and when 16.2 goes the
# step fails with a bare "invalid developer directory" that reads like a
# toolchain problem rather than an image change. Prefer the pinned version,
# fall back to whatever the image ships as default.
set -euo pipefail

PREFERRED=(
  /Applications/Xcode_16.2.app
  /Applications/Xcode_16.app
)

for candidate in "${PREFERRED[@]}"; do
  if [ -d "$candidate" ]; then
    sudo xcode-select -s "$candidate"
    echo "Selected $candidate"
    swift --version
    exit 0
  fi
done

echo "::warning::None of the preferred Xcode versions are present; using the image default."
ls -d /Applications/Xcode*.app || true
swift --version
