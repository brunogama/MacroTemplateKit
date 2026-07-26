import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Covers `Pattern` and the `guardCase`/`ifCase` statements.
///
/// The shape that motivated the type is the CasePaths extract closure —
/// `guard case let .success(value) = $0 else { return nil }` — which until now
/// could only be written by handing raw source to `Template.variable`.
final class MatchPatternTests: XCTestCase {

  private func render(_ statement: Statement<Void>) throws -> String {
    try Renderer.render(statement).description
  }

  // MARK: - Emission

  func testGuardCaseHoistsLetInFrontOfPattern() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("success", binding: "value"),
      value: .variable("result"),
      elseBody: [.returnStatement(.literal(.nil))]
    )
    let rendered = try render(statement)
    XCTAssertTrue(
      rendered.contains("guard case let .success(value) = result"),
      "expected a hoisted `let`, got: \(rendered)"
    )
  }

  func testPatternWithoutBindingsOmitsLet() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("loading"),
      value: .variable("state"),
      elseBody: [.returnStatement(nil)]
    )
    let rendered = try render(statement)
    XCTAssertTrue(rendered.contains("guard case .loading = state"))
    XCTAssertFalse(rendered.contains("let"), "no bindings, so no `let`: \(rendered)")
  }

  func testWildcardBindsNothingSoStillOmitsLet() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("success", [.wildcard]),
      value: .variable("result"),
      elseBody: [.returnStatement(nil)]
    )
    let rendered = try render(statement)
    XCTAssertTrue(rendered.contains("guard case .success(_) = result"))
    XCTAssertFalse(rendered.contains("let"))
  }

  func testMultipleBindingsShareOneHoistedLet() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("point", [.bind("x"), .bind("y")]),
      value: .variable("shape"),
      elseBody: [.returnStatement(nil)]
    )
    XCTAssertTrue(try render(statement).contains("guard case let .point(x, y) = shape"))
  }

  func testOneBindingAmongWildcardsStillHoists() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("point", [.wildcard, .bind("y")]),
      value: .variable("shape"),
      elseBody: [.returnStatement(nil)]
    )
    XCTAssertTrue(try render(statement).contains("guard case let .point(_, y) = shape"))
  }

  func testTuplePattern() throws {
    let statement = Statement<Void>.ifCase(
      pattern: .tuple([.bind("a"), .bind("b")]),
      value: .variable("pair"),
      thenBody: [.breakStatement],
      elseBody: nil
    )
    XCTAssertTrue(try render(statement).contains("if case let (a, b) = pair"))
  }

  func testNestedEnumCasePattern() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("outer", [.enumCase("inner", binding: "value")]),
      value: .variable("wrapped"),
      elseBody: [.returnStatement(nil)]
    )
    XCTAssertTrue(
      try render(statement).contains("guard case let .outer(.inner(value)) = wrapped"))
  }

  func testValuePatternIsAnExpressionNotADestructuring() throws {
    // `.value` emits no leading dot and no binding — it is matched with `~=`.
    let statement = Statement<Void>.guardCase(
      pattern: .value(.literal(42)),
      value: .variable("code"),
      elseBody: [.returnStatement(nil)]
    )
    let rendered = try render(statement)
    XCTAssertTrue(rendered.contains("guard case 42 = code"), rendered)
  }

  func testIfCaseWithElseBranch() throws {
    let statement = Statement<Void>.ifCase(
      pattern: .enumCase("success", binding: "value"),
      value: .variable("result"),
      thenBody: [.returnStatement(.variable("value"))],
      elseBody: [.returnStatement(.literal(.nil))]
    )
    let rendered = try render(statement)
    XCTAssertTrue(rendered.contains("if case let .success(value) = result"))
    XCTAssertTrue(rendered.contains("else"))
  }

  // MARK: - Identifier escaping

  func testCaseNameThatIsAKeywordIsEscaped() throws {
    // Enum cases really are named things like `default` and `repeat`; an
    // unescaped one would emit `.default(value)` and fail to parse.
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("repeat", binding: "value"),
      value: .variable("mode"),
      elseBody: [.returnStatement(nil)]
    )
    let rendered = try render(statement)
    XCTAssertTrue(rendered.contains("`repeat`"), rendered)
  }

  func testBoundNameThatIsAKeywordIsEscaped() throws {
    let statement = Statement<Void>.guardCase(
      pattern: .enumCase("success", binding: "class"),
      value: .variable("result"),
      elseBody: [.returnStatement(nil)]
    )
    let rendered = try render(statement)
    XCTAssertTrue(rendered.contains("`class`"), rendered)
  }

  // MARK: - Everything it emits must parse

  func testEveryPatternShapeParsesCleanly() throws {
    let patterns: [MatchPattern<Void>] = [
      .enumCase("success", binding: "value"),
      .enumCase("loading"),
      .enumCase("point", [.bind("x"), .bind("y")]),
      .enumCase("outer", [.enumCase("inner", binding: "v")]),
      .enumCase("success", [.wildcard]),
      .tuple([.bind("a"), .wildcard]),
      .value(.literal(42)),
      .value(.literal("hello")),
      .enumCase("repeat", binding: "class"),
    ]
    for pattern in patterns {
      let statement = Statement<Void>.guardCase(
        pattern: pattern,
        value: .variable("subject"),
        elseBody: [.returnStatement(nil)]
      )
      // `render` throws a `RenderError` if the emitted buffer does not parse,
      // which is the property under test.
      XCTAssertNoThrow(try render(statement))
    }
  }

  // MARK: - Functor laws

  func testMapPreservesIdentity() {
    let pattern = MatchPattern<Int>.enumCase(
      "point", [.bind("x"), .value(.variable("y", payload: 1))])
    XCTAssertEqual(pattern.map { $0 }, pattern)
  }

  func testMapReachesPayloadsInsideValuePatterns() {
    // The point of giving `Pattern` a `map`: a raw-source pattern was opaque
    // to a map over the tree, so payloads nested in it silently survived
    // untransformed.
    let statement = Statement<Int>.guardCase(
      pattern: .enumCase("success", [.value(.variable("tag", payload: 1))]),
      value: .variable("result", payload: 2),
      elseBody: []
    )
    guard case .guardCase(let pattern, _, _) = statement.map({ $0 * 10 }) else {
      return XCTFail("expected guardCase")
    }
    guard case .enumCase(_, let subpatterns) = pattern,
      case .value(let template) = subpatterns[0],
      case .variable(_, let payload) = template
    else {
      return XCTFail("expected a value subpattern carrying a variable")
    }
    XCTAssertEqual(payload, 10)
  }

  func testMapComposes() {
    let pattern = MatchPattern<Int>.enumCase("c", [.value(.variable("v", payload: 2))])
    let f: (Int) -> Int = { $0 + 1 }
    let g: (Int) -> Int = { $0 * 3 }
    XCTAssertEqual(pattern.map(f).map(g), pattern.map { g(f($0)) })
  }
}
