// swift-tools-version: 6.2
// KEEP THE COMMON MANIFEST IN SYNC WITH THE VERSION-SPECIFIC MANIFESTS.
// Package@swift-6.0.swift is byte-identical below line 1. Package@swift-6.2.swift
// appends only target-scoped warning controls. `Scripts/check-manifests.sh`
// enforces both relationships because SwiftPM selects one manifest and ignores
// the others, which previously let the MacroExamples target drift unnoticed.
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
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.1"..<"700.0.0")
  ],
  targets: [
    .target(
      name: "MacroTemplateKit",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "MacroTemplateKitTests",
      dependencies: ["MacroTemplateKit"],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    // The example macros are a build target so that they cannot silently rot.
    // They were not one until now, and every one of them had drifted out of
    // date: 57 call sites across 24 files still used the pre-throwing
    // `Renderer.render` API and had not compiled since that change shipped.
    // Documentation nothing compiles is documentation nothing checks.
    .target(
      name: "MacroExamples",
      dependencies: [
        "MacroTemplateKit",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
      ],
      path: "Examples",
      exclude: [
        "README.md",
        "AccessorAndBodyMacros/README.md",
        "ExpressionMacros/README.md",
        "ExtensionMacros/README.md",
        "MemberMacros/README.md",
        "PeerMacros/README.md",
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
  ]
)
// Swift 6.2 scopes warning controls to this package's targets, avoiding
// `-Xswiftc` propagation into swift-syntax and the deprecated native build system.
for target in package.targets {
  var settings = target.swiftSettings ?? []
  settings.append(.treatAllWarnings(as: .error))
  target.swiftSettings = settings
}
