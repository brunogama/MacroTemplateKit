// swift-tools-version: 5.10
// Development manifest -- builds MacroTemplateKit from source (requires swift-syntax).
// MacroTemplateKit is a compile-time library statically linked into macro binaries.
// When macros ship as .artifactbundle binaries, MTK is baked in -- consumers never
// resolve it or swift-syntax. Package.binary.swift exists for completeness.
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
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "510.0.0"..<"700.0.0")
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
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
  ]
)
