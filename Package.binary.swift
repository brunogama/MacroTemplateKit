// swift-tools-version: 5.10
// Package.binary.swift -- Release manifest for binary distribution.
// MacroTemplateKit is a compile-time library that wraps SwiftSyntax.
// When distributed as an XCFramework, consumers avoid pulling swift-syntax.
// On tagged releases, CI swaps this file to Package.swift.
import PackageDescription

let package = Package(
  name: "MacroTemplateKit",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "MacroTemplateKit",
      targets: ["MacroTemplateKit"]
    )
  ],
  dependencies: [],
  targets: [
    // Pre-built XCFramework -- no swift-syntax required.
    .binaryTarget(
      name: "MacroTemplateKit",
      url: "https://github.com/brunogama/MacroTemplateKit/releases/download/__VERSION__/MacroTemplateKit.xcframework.zip",
      checksum: "__CHECKSUM__"
    ),
  ]
)
