import Foundation
import XCTest

@testable import ExpectedSyntaxGenCore

final class ExpectedSyntaxGeneratorTests: XCTestCase {
  func testAllRootKindsProduceTypedFactories() throws {
    let cases: [(ExpectedSyntaxOutputKind, String, String)] = [
      (.sourceFile, "let value = 1\n", "-> SwiftSyntax.SourceFileSyntax"),
      (.declaration, "struct Value {}\n", "-> SwiftSyntax.DeclSyntax"),
      (.expression, "values.map { $0 + 1 }\n", "-> SwiftSyntax.ExprSyntax"),
      (.declarations, "struct A {}\nstruct B {}\n", "-> [SwiftSyntax.DeclSyntax]"),
    ]

    for (kind, source, returnType) in cases {
      let generated = try ExpectedSyntaxGenerator.generate(
        source: source,
        options: ExpectedSyntaxGenerationOptions(kind: kind, factoryName: "makeFixture")
      )
      XCTAssertTrue(generated.contains("public func makeFixture() \(returnType)"))
      XCTAssertTrue(generated.contains("SwiftSyntax.TokenSyntax("))
      XCTAssertTrue(generated.contains("presence: .present"))
    }
  }

  func testGenerationIsDeterministicAndEmitsAbsentChildren() throws {
    let options = ExpectedSyntaxGenerationOptions(
      kind: .expression,
      factoryName: "makeReference"
    )
    let first = try ExpectedSyntaxGenerator.generate(source: "value", options: options)
    let second = try ExpectedSyntaxGenerator.generate(source: "value", options: options)

    XCTAssertEqual(first, second)
    XCTAssertTrue(first.contains("argumentNames: SwiftSyntax.DeclNameArgumentsSyntax?.none"))
    XCTAssertTrue(first.contains("public func makeReference() -> SwiftSyntax.ExprSyntax"))
  }

  func testEmptyDeclarationsAreExplicit() throws {
    let generated = try ExpectedSyntaxGenerator.generate(
      source: "",
      options: ExpectedSyntaxGenerationOptions(kind: .declarations, factoryName: "makeEmpty")
    )

    XCTAssertTrue(generated.contains("public func makeEmpty() -> [SwiftSyntax.DeclSyntax]"))
    XCTAssertTrue(generated.contains("return []"))
  }

  func testMalformedInputReportsSourceLocation() {
    XCTAssertThrowsError(
      try ExpectedSyntaxGenerator.generate(
        source: "func broken(",
        options: ExpectedSyntaxGenerationOptions(kind: .sourceFile)
      )
    ) { error in
      guard case .malformedSource(let diagnostics) = error as? ExpectedSyntaxGenerationError else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertFalse(diagnostics.isEmpty)
      XCTAssertGreaterThanOrEqual(diagnostics[0].line, 1)
      XCTAssertGreaterThanOrEqual(diagnostics[0].column, 1)
    }
  }

  func testInvalidFactoryNamesAreRejected() {
    for name in [
      "", "two names", "member.name", "name()", "// comment\nname", "SwiftSyntax", "`SwiftSyntax`",
    ] {
      XCTAssertThrowsError(
        try ExpectedSyntaxGenerator.generate(
          source: "value",
          options: ExpectedSyntaxGenerationOptions(kind: .expression, factoryName: name)
        )
      ) { error in
        XCTAssertEqual(error as? ExpectedSyntaxGenerationError, .invalidFactoryName(name))
      }
    }
  }

  func testEscapedFactoryNameIsPreserved() throws {
    let generated = try ExpectedSyntaxGenerator.generate(
      source: "value",
      options: ExpectedSyntaxGenerationOptions(
        kind: .expression,
        factoryName: "`class`"
      )
    )

    XCTAssertTrue(generated.contains("public func `class`() -> SwiftSyntax.ExprSyntax"))
  }

  func testWrongRootKindsAreRejected() {
    XCTAssertThrowsError(
      try ExpectedSyntaxGenerator.generate(
        source: "let value = 1\nlet other = 2",
        options: ExpectedSyntaxGenerationOptions(kind: .declaration)
      )
    ) { error in
      guard case .rootMismatch(expected: .declaration, _) = error as? ExpectedSyntaxGenerationError
      else {
        return XCTFail("Unexpected error: \(error)")
      }
    }

    XCTAssertThrowsError(
      try ExpectedSyntaxGenerator.generate(
        source: "let value = 1",
        options: ExpectedSyntaxGenerationOptions(kind: .expression)
      )
    )
  }

  func testFragmentModesRejectFileOnlySyntax() {
    let cases: [(ExpectedSyntaxOutputKind, String)] = [
      (.declaration, "struct Value {};"),
      (.expression, "value;"),
      (.declarations, "struct A {}; struct B {}"),
      (.declaration, "#!/usr/bin/swift\nstruct Value {}"),
      (.declarations, "// comment only\n"),
      (.declarations, " \t\r\n"),
    ]

    for (kind, source) in cases {
      XCTAssertThrowsError(
        try ExpectedSyntaxGenerator.generate(
          source: source,
          options: ExpectedSyntaxGenerationOptions(kind: kind)
        )
      ) { error in
        guard case .unrepresentableFragment = error as? ExpectedSyntaxGenerationError else {
          return XCTFail("Unexpected error for \(kind): \(error)")
        }
      }
    }
  }

  func testTriviaStringsAndChoiceWrappersAreEmittedStructurally() throws {
    let generated = try ExpectedSyntaxGenerator.generate(
      source: "#\"raw \\#(value) 🙂\"#.map { value in value } // end\r\n",
      options: ExpectedSyntaxGenerationOptions(kind: .expression, factoryName: "makeTrivia")
    )

    XCTAssertTrue(generated.contains("SwiftSyntax.ClosureSignatureSyntax.ParameterClause"))
    XCTAssertTrue(generated.contains(".lineComment(\"// end\")"))
    XCTAssertTrue(generated.contains(".carriageReturnLineFeeds(1)"))
    XCTAssertTrue(generated.contains("\\u{1F642}"))
  }

  func testCheckedInMacroFixtureIsCurrent() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let input = packageRoot.appendingPathComponent(
      "docs/fixtures/expected-answer-expression.swift"
    )
    let checkedIn = packageRoot.appendingPathComponent(
      "Examples/ExpectedSyntaxGenMacro/ExpectedAnswerExpression.generated.swift"
    )

    let source = try String(contentsOf: input, encoding: .utf8)
    let expected = try String(contentsOf: checkedIn, encoding: .utf8)
    let generated = try ExpectedSyntaxGenerator.generate(
      source: source,
      options: ExpectedSyntaxGenerationOptions(
        kind: .expression,
        factoryName: "makeExpectedAnswerExpression"
      )
    )

    XCTAssertEqual(generated, expected)
  }
}
