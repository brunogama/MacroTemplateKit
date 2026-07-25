import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Tests that nested expressions are parenthesized according to Swift's
/// precedence rules.
///
/// This is the guarantee a hand-written source string cannot offer: a string
/// has no structure to inspect, so its author must track precedence in their
/// head. A `Template` knows its own shape, so the renderer can do it.
///
/// Every case is checked on both render paths, since a divergence would mean
/// the parse-backed and structural renderers disagree about meaning.
final class PrecedenceTests: XCTestCase {

  private func v(_ name: String) -> Template<Void> { .variable(name, payload: ()) }

  private func emitted(_ template: Template<Void>) -> String {
    var buffer = ""
    SourceEmitter.emit(template, into: &buffer)
    return buffer
  }

  private func assertBothPaths(
    _ template: Template<Void>,
    equals expected: String,
    line: UInt = #line
  ) {
    XCTAssertEqual(emitted(template), expected, "emitter", line: line)

    let parsed = Renderer.render(template)
    XCTAssertFalse(parsed.hasError, "should parse cleanly", line: line)

    // Compare token streams rather than descriptions: the legacy renderer
    // builds tokens without trivia, so its description has no spaces. Only the
    // token sequence carries meaning, and that is what the parity harness
    // compares too.
    func tokens(_ node: some SyntaxProtocol) -> [String] {
      node.tokens(viewMode: .sourceAccurate).map(\.text)
    }
    XCTAssertEqual(
      tokens(Renderer.legacyRender(template)), tokens(parsed),
      "legacy and parse-backed paths disagree", line: line
    )
  }

  // MARK: - The bug this fixes

  func testLooserChildOnLeftIsParenthesized() {
    // (a + b) * c — without parens this silently becomes a + b * c
    assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "+", right: v("b")), operator: "*", right: v("c")),
      equals: "(a + b) * c"
    )
  }

  func testLooserChildOnRightIsParenthesized() {
    assertBothPaths(
      .binaryOperation(left: v("a"), operator: "*", right: .binaryOperation(left: v("b"), operator: "+", right: v("c"))),
      equals: "a * (b + c)"
    )
  }

  func testLogicalOperatorsNestByPrecedence() {
    // (a || b) && c
    assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "||", right: v("b")), operator: "&&", right: v("c")),
      equals: "(a || b) && c"
    )
  }

  // MARK: - No redundant parentheses

  func testTighterChildIsNotParenthesized() {
    // a + b * c — the nesting already means what it says
    assertBothPaths(
      .binaryOperation(left: v("a"), operator: "+", right: .binaryOperation(left: v("b"), operator: "*", right: v("c"))),
      equals: "a + b * c"
    )
  }

  func testLeftAssociativeChainIsNotParenthesized() {
    // a - b - c, not (a - b) - c
    assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "-", right: v("b")), operator: "-", right: v("c")),
      equals: "a - b - c"
    )
  }

  func testAtomicOperandsAreNeverParenthesized() {
    assertBothPaths(
      .binaryOperation(left: .functionCall(function: "f", arguments: []), operator: "+", right: v("b")),
      equals: "f() + b"
    )
  }

  // MARK: - Associativity

  func testLeftAssociativeOperatorParenthesizesItsRightOperand() {
    // a - (b - c) must keep its parentheses, or it means (a - b) - c
    assertBothPaths(
      .binaryOperation(left: v("a"), operator: "-", right: .binaryOperation(left: v("b"), operator: "-", right: v("c"))),
      equals: "a - (b - c)"
    )
  }

  func testRightAssociativeOperatorParenthesizesItsLeftOperand() {
    // (a ?? b) ?? c — `??` is right-associative
    assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "??", right: v("b")), operator: "??", right: v("c")),
      equals: "(a ?? b) ?? c"
    )
  }

  func testNonAssociativeOperatorParenthesizesBothSides() {
    // `a < b < c` is not valid Swift, so the nesting must be made explicit
    assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "<", right: v("b")), operator: "<", right: v("c")),
      equals: "(a < b) < c"
    )
  }

  // MARK: - Casts and ternaries

  func testCastDoesNotParenthesizeTighterOperand() {
    // AdditionPrecedence is higher than CastingPrecedence, so `a + b as! Int`
    // already groups as `(a + b) as! Int`. Adding parentheses would be noise.
    assertBothPaths(
      .cast(.binaryOperation(left: v("a"), operator: "+", right: v("b")), type: "Int", kind: .forced),
      equals: "a + b as! Int"
    )
  }

  func testCastParenthesizesLooserOperand() {
    // ComparisonPrecedence is lower than CastingPrecedence: without parens
    // `a == b as! Bool` would cast `b`, not the comparison.
    assertBothPaths(
      .cast(.binaryOperation(left: v("a"), operator: "==", right: v("b")), type: "Bool", kind: .forced),
      equals: "(a == b) as! Bool"
    )
  }

  func testCastDoesNotParenthesizeAtomicOperand() {
    assertBothPaths(.cast(v("a"), type: "Int", kind: .forced), equals: "a as! Int")
  }

  func testTernaryParenthesizesNestedTernaryCondition() {
    let inner = Template<Void>.conditional(condition: v("a"), thenBranch: v("b"), elseBranch: v("c"))
    assertBothPaths(
      .conditional(condition: inner, thenBranch: v("d"), elseBranch: v("e")),
      equals: "(a ? b : c) ? d : e"
    )
  }

  func testComparisonInTernaryConditionNeedsNoParentheses() {
    assertBothPaths(
      .conditional(
        condition: .binaryOperation(left: v("a"), operator: "<", right: v("b")),
        thenBranch: v("c"),
        elseBranch: v("d")
      ),
      equals: "a < b ? c : d"
    )
  }

  // MARK: - Unknown operators

  func testCustomOperatorIsParenthesizedDefensively() {
    // An operator the table doesn't know could have any precedence, so the
    // renderer biases toward redundant parens rather than a silent meaning
    // change.
    assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "|>", right: v("b")), operator: "*", right: v("c")),
      equals: "(a |> b) * c"
    )
  }
}
