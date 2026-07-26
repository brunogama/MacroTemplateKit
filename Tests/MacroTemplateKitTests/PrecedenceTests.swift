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
/// Each case asserts the emitted text and then re-parses it, so the
/// parentheses are validated against the compiler's grammar rather than only
/// against a string.
final class PrecedenceTests: XCTestCase {

  private func v(_ name: String) -> Template<Void> { .variable(name, payload: ()) }

  private func emitted(_ template: Template<Void>) -> String {
    var buffer = ""
    SourceEmitter.emit(template, into: &buffer)
    return buffer
  }

  private func assertRenders(
    _ template: Template<Void>,
    equals expected: String,
    line: UInt = #line
  ) throws {
    XCTAssertEqual(emitted(template), expected, "emitter", line: line)

    let parsed = try Renderer.render(template)
    XCTAssertFalse(parsed.hasError, "should parse cleanly", line: line)

    // Re-parsing proves the parentheses survive the compiler's own grammar
    // rather than merely looking right as a string.
    XCTAssertEqual(parsed.trimmedDescription, expected, "reparsed", line: line)
  }

  // MARK: - The bug this fixes

  func testLooserChildOnLeftIsParenthesized() throws {
    // (a + b) * c — without parens this silently becomes a + b * c
    try assertRenders(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "+", right: v("b")), operator: "*",
        right: v("c")),
      equals: "(a + b) * c"
    )
  }

  func testLooserChildOnRightIsParenthesized() throws {
    try assertRenders(
      .binaryOperation(
        left: v("a"), operator: "*",
        right: .binaryOperation(left: v("b"), operator: "+", right: v("c"))),
      equals: "a * (b + c)"
    )
  }

  func testLogicalOperatorsNestByPrecedence() throws {
    // (a || b) && c
    try assertRenders(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "||", right: v("b")), operator: "&&",
        right: v("c")),
      equals: "(a || b) && c"
    )
  }

  // MARK: - No redundant parentheses

  func testTighterChildIsNotParenthesized() throws {
    // a + b * c — the nesting already means what it says
    try assertRenders(
      .binaryOperation(
        left: v("a"), operator: "+",
        right: .binaryOperation(left: v("b"), operator: "*", right: v("c"))),
      equals: "a + b * c"
    )
  }

  func testLeftAssociativeChainIsNotParenthesized() throws {
    // a - b - c, not (a - b) - c
    try assertRenders(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "-", right: v("b")), operator: "-",
        right: v("c")),
      equals: "a - b - c"
    )
  }

  func testAtomicOperandsAreNeverParenthesized() throws {
    try assertRenders(
      .binaryOperation(
        left: .functionCall(function: "f", arguments: []), operator: "+", right: v("b")),
      equals: "f() + b"
    )
  }

  // MARK: - Associativity

  func testLeftAssociativeOperatorParenthesizesItsRightOperand() throws {
    // a - (b - c) must keep its parentheses, or it means (a - b) - c
    try assertRenders(
      .binaryOperation(
        left: v("a"), operator: "-",
        right: .binaryOperation(left: v("b"), operator: "-", right: v("c"))),
      equals: "a - (b - c)"
    )
  }

  func testRightAssociativeOperatorParenthesizesItsLeftOperand() throws {
    // (a ?? b) ?? c — `??` is right-associative
    try assertRenders(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "??", right: v("b")), operator: "??",
        right: v("c")),
      equals: "(a ?? b) ?? c"
    )
  }

  func testNonAssociativeOperatorParenthesizesBothSides() throws {
    // `a < b < c` is not valid Swift, so the nesting must be made explicit
    try assertRenders(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "<", right: v("b")), operator: "<",
        right: v("c")),
      equals: "(a < b) < c"
    )
  }

  // MARK: - Casts and ternaries

  func testCastDoesNotParenthesizeTighterOperand() throws {
    // AdditionPrecedence is higher than CastingPrecedence, so `a + b as! Int`
    // already groups as `(a + b) as! Int`. Adding parentheses would be noise.
    try assertRenders(
      .cast(
        .binaryOperation(left: v("a"), operator: "+", right: v("b")), type: "Int", kind: .forced),
      equals: "a + b as! Int"
    )
  }

  func testCastParenthesizesLooserOperand() throws {
    // ComparisonPrecedence is lower than CastingPrecedence: without parens
    // `a == b as! Bool` would cast `b`, not the comparison.
    try assertRenders(
      .cast(
        .binaryOperation(left: v("a"), operator: "==", right: v("b")), type: "Bool", kind: .forced),
      equals: "(a == b) as! Bool"
    )
  }

  func testCastDoesNotParenthesizeAtomicOperand() throws {
    try assertRenders(.cast(v("a"), type: "Int", kind: .forced), equals: "a as! Int")
  }

  func testTernaryParenthesizesNestedTernaryCondition() throws {
    let inner = Template<Void>.conditional(
      condition: v("a"), thenBranch: v("b"), elseBranch: v("c"))
    try assertRenders(
      .conditional(condition: inner, thenBranch: v("d"), elseBranch: v("e")),
      equals: "(a ? b : c) ? d : e"
    )
  }

  func testComparisonInTernaryConditionNeedsNoParentheses() throws {
    try assertRenders(
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
    try assertRenders(
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
    try assertRenders(
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
    try assertRenders(
      .binaryOperation(
        left: .binaryOperation(left: v("a"), operator: "|>", right: v("b")), operator: "*",
        right: v("c")),
      equals: "(a |> b) * c"
    )
  }
}
