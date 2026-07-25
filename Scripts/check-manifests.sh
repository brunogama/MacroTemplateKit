#!/usr/bin/env bash
# Asserts Package.swift and Package@swift-6.0.swift are identical below line 1.
#
# SwiftPM picks the highest matching Package@swift-N.swift and ignores
# Package.swift entirely, so on a Swift 6 toolchain a change made to only one of
# them builds clean and the other rots unnoticed. That has already happened once:
# the MacroExamples target existed in Package.swift alone.
set -euo pipefail

cd "$(dirname "$0")/.."

if diff -u <(tail -n +2 Package.swift) <(tail -n +2 Package@swift-6.0.swift); then
  echo "Manifests are in sync."
else
  echo "::error::Package.swift and Package@swift-6.0.swift have diverged below line 1."
  echo "Only the swift-tools-version line may differ. Copy one over the other:"
  echo "  { echo '// swift-tools-version: 5.10'; tail -n +2 Package@swift-6.0.swift; } > Package.swift"
  exit 1
fi
