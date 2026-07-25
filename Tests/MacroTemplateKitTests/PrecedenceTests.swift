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
  ) throws {
    XCTAssertEqual(emitted(template), expected, "emitter", line: line)

    let parsed = try Renderer.render(template)
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

  func testLooserChildOnLeftIsParenthesized() throws {
    // (a + b) * c — without parens this silently becomes a + b * c
    try assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "+", right: v("b")), operator: "*", right: v("c")),
      equals: "(a + b) * c"
    )
  }

  func testLooserChildOnRightIsParenthesized() throws {
    try assertBothPaths(
      .binaryOperation(left: v("a"), operator: "*", right: .binaryOperation(left: v("b"), operator: "+", right: v("c"))),
      equals: "a * (b + c)"
    )
  }

  func testLogicalOperatorsNestByPrecedence() throws {
    // (a || b) && c
    try assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "||", right: v("b")), operator: "&&", right: v("c")),
      equals: "(a || b) && c"
    )
  }

  // MARK: - No redundant parentheses

  func testTighterChildIsNotParenthesized() throws {
    // a + b * c — the nesting already means what it says
    try assertBothPaths(
      .binaryOperation(left: v("a"), operator: "+", right: .binaryOperation(left: v("b"), operator: "*", right: v("c"))),
      equals: "a + b * c"
    )
  }

  func testLeftAssociativeChainIsNotParenthesized() throws {
    // a - b - c, not (a - b) - c
    try assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "-", right: v("b")), operator: "-", right: v("c")),
      equals: "a - b - c"
    )
  }

  func testAtomicOperandsAreNeverParenthesized() throws {
    try assertBothPaths(
      .binaryOperation(left: .functionCall(function: "f", arguments: []), operator: "+", right: v("b")),
      equals: "f() + b"
    )
  }

  // MARK: - Associativity

  func testLeftAssociativeOperatorParenthesizesItsRightOperand() throws {
    // a - (b - c) must keep its parentheses, or it means (a - b) - c
    try assertBothPaths(
      .binaryOperation(left: v("a"), operator: "-", right: .binaryOperation(left: v("b"), operator: "-", right: v("c"))),
      equals: "a - (b - c)"
    )
  }

  func testRightAssociativeOperatorParenthesizesItsLeftOperand() throws {
    // (a ?? b) ?? c — `??` is right-associative
    try assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "??", right: v("b")), operator: "??", right: v("c")),
      equals: "(a ?? b) ?? c"
    )
  }

  func testNonAssociativeOperatorParenthesizesBothSides() throws {
    // `a < b < c` is not valid Swift, so the nesting must be made explicit
    try assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "<", right: v("b")), operator: "<", right: v("c")),
      equals: "(a < b) < c"
    )
  }

  // MARK: - Casts and ternaries

  func testCastDoesNotParenthesizeTighterOperand() throws {
    // AdditionPrecedence is higher than CastingPrecedence, so `a + b as! Int`
    // already groups as `(a + b) as! Int`. Adding parentheses would be noise.
    try assertBothPaths(
      .cast(.binaryOperation(left: v("a"), operator: "+", right: v("b")), type: "Int", kind: .forced),
      equals: "a + b as! Int"
    )
  }

  func testCastParenthesizesLooserOperand() throws {
    // ComparisonPrecedence is lower than CastingPrecedence: without parens
    // `a == b as! Bool` would cast `b`, not the comparison.
    try assertBothPaths(
      .cast(.binaryOperation(left: v("a"), operator: "==", right: v("b")), type: "Bool", kind: .forced),
      equals: "(a == b) as! Bool"
    )
  }

  func testCastDoesNotParenthesizeAtomicOperand() throws {
    try assertBothPaths(.cast(v("a"), type: "Int", kind: .forced), equals: "a as! Int")
  }

  func testTernaryParenthesizesNestedTernaryCondition() throws {
    let inner = Template<Void>.conditional(condition: v("a"), thenBranch: v("b"), elseBranch: v("c"))
    try assertBothPaths(
      .conditional(condition: inner, thenBranch: v("d"), elseBranch: v("e")),
      equals: "(a ? b : c) ? d : e"
    )
  }

  func testComparisonInTernaryConditionNeedsNoParentheses() throws {
    try assertBothPaths(
      .conditional(
        condition: .binaryOperation(left: v("a"), operator: "<", right: v("b")),
        thenBranch: v("c"),
        elseBranch: v("d")
      ),
      equals: "a < b ? c : d"
    )
  }

  // MARK: - Unknown operators

  func testCustomOperatorWithDeclaredPrecedenceIsNotOverParenthesized() throws {
    // Declaring the precedence lets the renderer treat `|>` like any other
    // operator instead of assuming the worst.
    let pipe = Operator("|>", precedence: .multiplication)
    try assertBothPaths(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: pipe, right: v("b")),
        operator: pipe,
        right: v("c")
      ),
      equals: "a |> b |> c"
    )
  }

  func testDeclaredPrecedenceStillParenthesizesLooserChildren() throws {
    let pipe = Operator("|>", precedence: .multiplication)
    try assertBothPaths(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "+", right: v("b")),
        operator: pipe,
        right: v("c")
      ),
      equals: "(a + b) |> c"
    )
  }

  func testCustomOperatorIsParenthesizedDefensively() throws {
    // An operator the table doesn't know could have any precedence, so the
    // renderer biases toward redundant parens rather than a silent meaning
    // change.
    try assertBothPaths(
      .binaryOperation(left: .binaryOperation(left: v("a"), operator: "|>", right: v("b")), operator: "*", right: v("c")),
      equals: "(a |> b) * c"
    )
  }
}
