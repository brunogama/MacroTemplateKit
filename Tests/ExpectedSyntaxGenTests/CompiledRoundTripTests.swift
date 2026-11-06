import Foundation
import XCTest

@testable import ExpectedSyntaxGenCore

final class CompiledRoundTripTests: XCTestCase {
  func testGeneratedFactoriesCompileAndReconstructAllRootKinds() throws {
    let fixtures: [(source: String, options: ExpectedSyntaxGenerationOptions)] = [
      (
        """
        #!/usr/bin/swift\r
        @available(*, deprecated, message: "legacy")\r
        struct Box<Value: Sendable> {\r
        \tlet `default`: Value\r
        \tfunc map<Result>(_ transform: (Value) -> Result) -> Result {\r
        \t\ttransform(`default`)\r
        \t}\r
        }; // file-only semicolon\r
        #if DEBUG\r
        let mode = "debug"\r
        #else\r
        let mode = "release"\r
        #endif\r
        """,
        ExpectedSyntaxGenerationOptions(kind: .sourceFile, factoryName: "SourceFileSyntax")
      ),
      (
        """
        @available(*, deprecated)
        public struct Pair<First, Second> where First: Sendable {
          public let first: First
          public let second: Second
          public func stored() -> First { self.first }
          public func valueType() throws -> First.Type { First.self }
        }
        // declaration eof
        """,
        ExpectedSyntaxGenerationOptions(kind: .declaration, factoryName: "TokenSyntax")
      ),
      (
        ##"""
        [
          #"raw \#(value)"#,
          """
          multi \(value)
          line
          """,
        ].map { element in element.uppercased() }
        // expression eof
        """##,
        ExpectedSyntaxGenerationOptions(kind: .expression, factoryName: "ExprSyntax")
      ),
      (
        """
        final class Resource {
          init() {}
          deinit {}
        }

        func `repeat`<each Value>(_ value: repeat each Value) {}
        // declarations eof
        """,
        ExpectedSyntaxGenerationOptions(kind: .declarations, factoryName: "DeclarationsFactory")
      ),
    ]

    let generated = try fixtures.map { fixture in
      try ExpectedSyntaxGenerator.generate(source: fixture.source, options: fixture.options)
    }.joined(separator: "\n")

    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let swiftSyntaxCheckout =
      packageRoot
      .appendingPathComponent(".build/checkouts/swift-syntax")
    XCTAssertTrue(FileManager.default.fileExists(atPath: swiftSyntaxCheckout.path))

    let temporaryPackage = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExpectedSyntaxGenRoundTrip-\(UUID().uuidString)")
    let sources = temporaryPackage.appendingPathComponent("Sources/RoundTrip")
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryPackage) }

    try Data(packageManifest(swiftSyntaxCheckout: swiftSyntaxCheckout).utf8)
      .write(to: temporaryPackage.appendingPathComponent("Package.swift"))
    try Data(generated.utf8).write(to: sources.appendingPathComponent("Generated.swift"))
    try Data(consumerMain(sources: fixtures.map(\.source)).utf8)
      .write(to: sources.appendingPathComponent("main.swift"))

    let logURL = temporaryPackage.appendingPathComponent("build.log")
    _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
    let logHandle = try FileHandle(forWritingTo: logURL)
    defer { try? logHandle.close() }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "swift", "run",
      "--package-path", temporaryPackage.path,
      "--scratch-path", temporaryPackage.appendingPathComponent(".build").path,
    ]
    process.currentDirectoryURL = packageRoot
    var environment = ProcessInfo.processInfo.environment
    environment["PAGER"] = "cat"
    environment["GIT_PAGER"] = "cat"
    process.environment = environment
    process.standardOutput = logHandle
    process.standardError = logHandle

    try process.run()
    process.waitUntilExit()
    try logHandle.synchronize()

    let log = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertEqual(process.terminationStatus, 0, log)
    XCTAssertTrue(log.contains("EXPECTED_SYNTAX_ROUND_TRIP_OK"), log)
  }

  private func packageManifest(swiftSyntaxCheckout: URL) -> String {
    """
    // swift-tools-version: 5.10
    import PackageDescription

    let package = Package(
      name: "ExpectedSyntaxGenConsumer",
      platforms: [.macOS(.v13)],
      dependencies: [
        .package(path: \(swiftLiteral(swiftSyntaxCheckout.path)))
      ],
      targets: [
        .executableTarget(
          name: "RoundTrip",
          dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
          ]
        )
      ]
    )
    """
  }

  private func consumerMain(sources: [String]) -> String {
    let encodedSources = sources.map { source in
      "[\(source.utf8.map(String.init).joined(separator: ", "))]"
    }.joined(separator: ",\n  ")

    return """
      import Foundation
      import SwiftParser
      import SwiftSyntax

      let fixtureBytes: [[UInt8]] = [
        \(encodedSources)
      ]
      let fixtures = fixtureBytes.map { String(decoding: $0, as: UTF8.self) }

      func fingerprint(_ node: some SyntaxProtocol) -> [String] {
        var result: [String] = []
        func walk(_ node: Syntax) {
          if let token = node.as(TokenSyntax.self) {
            result.append(
              "token|\\(String(reflecting: token.tokenKind))|\\(token.presence)|"
                + "\\(token.leadingTrivia.debugDescription)|\\(token.trailingTrivia.debugDescription)"
            )
          } else {
            let children = Array(node.children(viewMode: .all))
            result.append("node|\\(node.kind)|children=\\(children.count)")
            for child in children { walk(child) }
          }
        }
        walk(Syntax(node))
        return result
      }

      func fail(_ message: String) -> Never {
        try? FileHandle.standardError.write(contentsOf: Data((message + "\\n").utf8))
        exit(1)
      }

      func requireSame(_ actual: some SyntaxProtocol, _ expected: some SyntaxProtocol, label: String) {
        guard actual.description.utf8.elementsEqual(expected.description.utf8) else {
          fail("\\(label) UTF-8 mismatch")
        }
        guard fingerprint(actual) == fingerprint(expected) else {
          fail("\\(label) fingerprint mismatch")
        }
        guard actual.debugDescription(includeTrivia: true)
          == expected.debugDescription(includeTrivia: true)
        else {
          fail("\\(label) debug tree mismatch")
        }
      }

      let expectedFile = Parser.parse(source: fixtures[0])
      requireSame(SourceFileSyntax(), expectedFile, label: "file")

      let declarationFile = Parser.parse(source: fixtures[1])
      guard let declarationItem = declarationFile.statements.first,
        var expectedDeclaration = DeclSyntax(declarationItem.item)
      else {
        fail("declaration fixture projection failed")
      }
      expectedDeclaration.trailingTrivia += declarationFile.endOfFileToken.leadingTrivia
      requireSame(TokenSyntax(), expectedDeclaration, label: "declaration")

      let expressionFile = Parser.parse(source: fixtures[2])
      guard let expressionItem = expressionFile.statements.first,
        var expectedExpression = ExprSyntax(expressionItem.item)
      else {
        fail("expression fixture projection failed")
      }
      expectedExpression.trailingTrivia += expressionFile.endOfFileToken.leadingTrivia
      requireSame(ExprSyntax(), expectedExpression, label: "expression")

      let declarationsFile = Parser.parse(source: fixtures[3])
      var expectedDeclarations = declarationsFile.statements.compactMap { DeclSyntax($0.item) }
      guard var lastDeclaration = expectedDeclarations.popLast() else {
        fail("declarations fixture projection failed")
      }
      lastDeclaration.trailingTrivia += declarationsFile.endOfFileToken.leadingTrivia
      expectedDeclarations.append(lastDeclaration)
      let actualDeclarations = DeclarationsFactory()
      guard actualDeclarations.count == expectedDeclarations.count else {
        fail("declaration count mismatch")
      }
      for (index, pair) in zip(actualDeclarations, expectedDeclarations).enumerated() {
        requireSame(pair.0, pair.1, label: "declarations[\\(index)]")
      }

      print("EXPECTED_SYNTAX_ROUND_TRIP_OK")
      """
  }

  private func swiftLiteral(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x22: result += "\\\""
      case 0x5C: result += "\\\\"
      case 0x20...0x21, 0x23...0x5B, 0x5D...0x7E: result.unicodeScalars.append(scalar)
      default: result += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
      }
    }
    result += "\""
    return result
  }
}
