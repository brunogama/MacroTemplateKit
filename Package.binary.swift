// swift-tools-version: 5.10
// Package.binary.swift -- Release manifest for binary distribution.
// MacroTemplateKit is a compile-time library that wraps SwiftSyntax.
// This internal-distribution XCFramework is pinned to Xcode 16.2 and
// SwiftSyntax 600.0.1. Consumers must provide that exact SwiftSyntax dependency.
// Release automation installs this manifest only in the detached tagged tree.
import PackageDescription

let package = Package(
  name: "MacroTemplateKit",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "MacroTemplateKit",
      targets: ["MacroTemplateKit"]
    )
  ],
  dependencies: [],
  targets: [
    // Pre-built host framework for use from Swift macro implementation targets.
    .binaryTarget(
      name: "MacroTemplateKit",
      url: "https://github.com/brunogama/MacroTemplateKit/releases/download/__VERSION__/MacroTemplateKit.xcframework.zip",
      checksum: "__CHECKSUM__"
    ),
  ]
)
