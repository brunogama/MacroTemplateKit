#!/usr/bin/env bash
# Runs a Swift package command while suppressing one known SwiftPM false positive.
#
# Current SwiftPM warns that this package's Documentation.docc catalog is an
# unhandled target file even though that location is required for DocC discovery.
# Declaring it as a resource or excluding it would either ship documentation in
# the runtime bundle or break DocC generation. Filter only that exact two-line
# diagnostic and preserve every other warning, error, and the Swift exit status.
set -euo pipefail

swift "$@" 2> >(
	awk '
    pending != "" {
      if ($0 ~ /\/Sources\/MacroTemplateKit\/Documentation\.docc$/) {
        pending = ""
        next
      }
      print pending
      fflush()
      pending = ""
    }
    /^warning: '\''macrotemplatekit'\'': found 1 file\(s\) which are unhandled;/ {
      pending = $0
      next
    }
    {
      print
      fflush()
    }
    END {
      if (pending != "") {
        print pending
        fflush()
      }
    }
  ' >&2
)
