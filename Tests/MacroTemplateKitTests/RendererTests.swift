import XCTest
import SwiftSyntax
@testable import MacroTemplateKit

// swiftlint:disable file_length type_body_length
// Justification: Comprehensive renderer tests covering all 9 Template cases with edge cases.
// All test methods verify Renderer natural transformation - cohesive test suite.
// Splitting would reduce test cohesion and clarity.

/// Tests for Renderer natural transformation from Template<A> to SwiftSyntax ExprSyntax.
///
/// Verifies that Renderer.render produces correct SwiftSyntax node types for each
/// Template case, ensuring valid AST generation for macro expansion.
final class RendererTests: XCTestCase {

  // MARK: - Literal Rendering

  func testRenderLiteral_integer() {
    let template: Template<Void> = .literal(.integer(42))
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(IntegerLiteralExprSyntax.self),
      "Should render as IntegerLiteralExprSyntax"
    )
    XCTAssertTrue(result.description.contains("42"), "Should contain integer value 42")
  }

  func testRenderLiteral_double() {
    let template: Template<Void> = .literal(.double(3.14))
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(FloatLiteralExprSyntax.self), "Should render as FloatLiteralExprSyntax")
    XCTAssertTrue(result.description.contains("3.14"), "Should contain double value 3.14")
  }

  func testRenderLiteral_string() {
    let template: Template<Void> = .literal(.string("hello"))
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(StringLiteralExprSyntax.self),
      "Should render as StringLiteralExprSyntax"
    )
    XCTAssertTrue(result.description.contains("hello"), "Should contain string value hello")
  }

  func testRenderLiteral_booleanTrue() {
    let template: Template<Void> = .literal(.boolean(true))
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(BooleanLiteralExprSyntax.self),
      "Should render as BooleanLiteralExprSyntax"
    )
    XCTAssertTrue(result.description.contains("true"), "Should contain boolean value true")
  }

  func testRenderLiteral_booleanFalse() {
    let template: Template<Void> = .literal(.boolean(false))
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(BooleanLiteralExprSyntax.self),
      "Should render as BooleanLiteralExprSyntax"
    )
    XCTAssertTrue(result.description.contains("false"), "Should contain boolean value false")
  }

  func testRenderLiteral_nil() {
    let template: Template<Void> = .literal(.nil)
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(NilLiteralExprSyntax.self), "Should render as NilLiteralExprSyntax")
    XCTAssertTrue(result.description.contains("nil"), "Should contain nil keyword")
  }

  // MARK: - Variable Rendering

  func testRenderVariable() {
    let template: Template<String> = .variable("myVariable", payload: "metadata")
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(DeclReferenceExprSyntax.self),
      "Should render as DeclReferenceExprSyntax (identifier)"
    )
    XCTAssertTrue(
      result.description.contains("myVariable"),
      "Should contain variable name myVariable"
    )
  }

  func testRenderVariable_complexName() {
    let template: Template<Int> = .variable("_privateVariable123", payload: 42)
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(DeclReferenceExprSyntax.self),
      "Should render as DeclReferenceExprSyntax"
    )
    XCTAssertTrue(
      result.description.contains("_privateVariable123"),
      "Should contain variable name _privateVariable123"
    )
  }

  // MARK: - Control Flow Rendering

  func testRenderConditional() {
    let template: Template<Void> = .conditional(
      condition: .literal(.boolean(true)),
      thenBranch: .literal(.integer(1)),
      elseBranch: .literal(.integer(0))
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(TernaryExprSyntax.self), "Should render as TernaryExprSyntax")
    XCTAssertTrue(result.description.contains("true"), "Should contain condition")
    XCTAssertTrue(result.description.contains("1"), "Should contain then branch")
    XCTAssertTrue(result.description.contains("0"), "Should contain else branch")
  }

  func testRenderLoop() {
    let template: Template<Int> = .loop(
      variable: "item",
      collection: .variable("items", payload: 1),
      body: .variable("item", payload: 2)
    )
    let result = Renderer.render(template)

    // Loop rendered as .forEach closure pattern (expressions can't represent for-in statements)
    XCTAssertTrue(
      result.is(FunctionCallExprSyntax.self),
      "Should render as FunctionCallExprSyntax (forEach)"
    )
    XCTAssertTrue(result.description.contains("forEach"), "Should contain forEach method call")
    XCTAssertTrue(result.description.contains("item"), "Should contain loop variable name")
  }

  // MARK: - Operations Rendering

  func testRenderFunctionCall_noLabel() {
    let template: Template<Void> = .functionCall(
      function: "print",
      arguments: [(label: nil, value: .literal(.string("hello")))]
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(FunctionCallExprSyntax.self), "Should render as FunctionCallExprSyntax")
    XCTAssertTrue(result.description.contains("print"), "Should contain function name print")
    XCTAssertTrue(result.description.contains("hello"), "Should contain argument value")
  }

  func testRenderFunctionCall_withLabel() {
    let template: Template<String> = .functionCall(
      function: "greet",
      arguments: [
        (label: "name", value: .literal(.string("Alice"))),
        (label: "times", value: .literal(.integer(3))),
      ]
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(FunctionCallExprSyntax.self), "Should render as FunctionCallExprSyntax")
    XCTAssertTrue(result.description.contains("greet"), "Should contain function name")
    XCTAssertTrue(result.description.contains("name"), "Should contain argument label name")
    XCTAssertTrue(result.description.contains("times"), "Should contain argument label times")
  }

  func testRenderBinaryOperation_addition() {
    let template: Template<Void> = .binaryOperation(
      left: .literal(.integer(1)),
      operator: "+",
      right: .literal(.integer(2))
    )
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(InfixOperatorExprSyntax.self),
      "Should render as InfixOperatorExprSyntax"
    )
    XCTAssertTrue(result.description.contains("1"), "Should contain left operand")
    XCTAssertTrue(result.description.contains("+"), "Should contain operator")
    XCTAssertTrue(result.description.contains("2"), "Should contain right operand")
  }

  func testRenderBinaryOperation_comparison() {
    let template: Template<String> = .binaryOperation(
      left: .variable("x", payload: "meta"),
      operator: ">=",
      right: .literal(.integer(0))
    )
    let result = Renderer.render(template)

    XCTAssertTrue(
      result.is(InfixOperatorExprSyntax.self),
      "Should render as InfixOperatorExprSyntax"
    )
    XCTAssertTrue(result.description.contains("x"), "Should contain left variable")
    XCTAssertTrue(result.description.contains(">="), "Should contain comparison operator")
  }

  func testRenderPropertyAccess() {
    let template: Template<Void> = .propertyAccess(
      base: .variable("object", payload: ()),
      property: "property"
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(MemberAccessExprSyntax.self), "Should render as MemberAccessExprSyntax")
    XCTAssertTrue(result.description.contains("object"), "Should contain base object name")
    XCTAssertTrue(result.description.contains("property"), "Should contain property name")
    XCTAssertTrue(result.description.contains("."), "Should contain member access dot")
  }

  func testRenderPropertyAccess_chained() {
    let template: Template<Int> = .propertyAccess(
      base: .propertyAccess(
        base: .variable("root", payload: 1),
        property: "middle"
      ),
      property: "leaf"
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(MemberAccessExprSyntax.self), "Should render as MemberAccessExprSyntax")
    XCTAssertTrue(result.description.contains("root"), "Should contain root object")
    XCTAssertTrue(result.description.contains("middle"), "Should contain middle property")
    XCTAssertTrue(result.description.contains("leaf"), "Should contain leaf property")
  }

  // MARK: - Collections Rendering

  func testRenderArrayLiteral_empty() {
    let template: Template<Void> = .arrayLiteral([])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ArrayExprSyntax.self), "Should render as ArrayExprSyntax")
    XCTAssertTrue(result.description.contains("["), "Should contain opening bracket")
    XCTAssertTrue(result.description.contains("]"), "Should contain closing bracket")
  }

  func testRenderArrayLiteral_integers() {
    let template: Template<Void> = .arrayLiteral([
      .literal(.integer(1)),
      .literal(.integer(2)),
      .literal(.integer(3)),
    ])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ArrayExprSyntax.self), "Should render as ArrayExprSyntax")
    XCTAssertTrue(result.description.contains("1"), "Should contain element 1")
    XCTAssertTrue(result.description.contains("2"), "Should contain element 2")
    XCTAssertTrue(result.description.contains("3"), "Should contain element 3")
  }

  func testRenderArrayLiteral_mixedExpressions() {
    let template: Template<String> = .arrayLiteral([
      .literal(.string("hello")),
      .variable("name", payload: "meta"),
      .literal(.string("world")),
    ])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ArrayExprSyntax.self), "Should render as ArrayExprSyntax")
    XCTAssertTrue(result.description.contains("hello"), "Should contain string literal")
    XCTAssertTrue(result.description.contains("name"), "Should contain variable")
    XCTAssertTrue(result.description.contains("world"), "Should contain second string literal")
  }

  // MARK: - Declarations Rendering

  func testRenderVariableDeclaration() {
    let template: Template<Int> = .variableDeclaration(
      name: "result",
      type: "Int",
      initializer: .literal(.integer(42))
    )
    let result = Renderer.render(template)

    // Limitation: Only renders initializer expression (full declaration requires statement context)
    XCTAssertTrue(
      result.is(IntegerLiteralExprSyntax.self),
      "Should render initializer as IntegerLiteralExprSyntax"
    )
    XCTAssertTrue(result.description.contains("42"), "Should contain initializer value")
  }

  func testRenderVariableDeclaration_complexInitializer() {
    let template: Template<String> = .variableDeclaration(
      name: "sum",
      type: "Int",
      initializer: .binaryOperation(
        left: .variable("a", payload: "meta1"),
        operator: "+",
        right: .variable("b", payload: "meta2")
      )
    )
    let result = Renderer.render(template)

    // Renders only the initializer expression (a + b)
    XCTAssertTrue(
      result.is(InfixOperatorExprSyntax.self),
      "Should render initializer as InfixOperatorExprSyntax"
    )
    XCTAssertTrue(result.description.contains("a"), "Should contain variable a")
    XCTAssertTrue(result.description.contains("+"), "Should contain operator")
    XCTAssertTrue(result.description.contains("b"), "Should contain variable b")
  }

  // MARK: - Edge Cases and Complex Expressions

  func testRenderNestedExpressions() {
    // property.method(arg1, arg2 + arg3)
    let template: Template<Int> = .functionCall(
      function: "method",
      arguments: [
        (label: nil, value: .variable("arg1", payload: 1)),
        (
          label: nil,
          value: .binaryOperation(
            left: .variable("arg2", payload: 2),
            operator: "+",
            right: .variable("arg3", payload: 3)
          )
        ),
      ]
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(FunctionCallExprSyntax.self), "Should render as FunctionCallExprSyntax")
    XCTAssertTrue(result.description.contains("method"), "Should contain method name")
    XCTAssertTrue(result.description.contains("arg1"), "Should contain first argument")
    XCTAssertTrue(
      result.description.contains("arg2"),
      "Should contain second argument left operand"
    )
    XCTAssertTrue(result.description.contains("+"), "Should contain operator in second argument")
    XCTAssertTrue(
      result.description.contains("arg3"),
      "Should contain second argument right operand"
    )
  }

  func testRenderComplexConditional() {
    // (x > 0) ? (x * 2) : 0
    let template: Template<String> = .conditional(
      condition: .binaryOperation(
        left: .variable("x", payload: "x_meta"),
        operator: ">",
        right: .literal(.integer(0))
      ),
      thenBranch: .binaryOperation(
        left: .variable("x", payload: "x_meta"),
        operator: "*",
        right: .literal(.integer(2))
      ),
      elseBranch: .literal(.integer(0))
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(TernaryExprSyntax.self), "Should render as TernaryExprSyntax")
    XCTAssertTrue(result.description.contains("x"), "Should contain variable x")
    XCTAssertTrue(result.description.contains(">"), "Should contain comparison operator")
    XCTAssertTrue(result.description.contains("*"), "Should contain multiplication operator")
  }

  func testRenderPropertyAccessOnFunctionCall() {
    // myFunction().property
    let template: Template<Void> = .propertyAccess(
      base: .functionCall(
        function: "myFunction",
        arguments: []
      ),
      property: "property"
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(MemberAccessExprSyntax.self), "Should render as MemberAccessExprSyntax")
    XCTAssertTrue(result.description.contains("myFunction"), "Should contain function name")
    XCTAssertTrue(result.description.contains("property"), "Should contain property name")
  }

  func testRenderPayloadIsDiscarded() {
    // Verify that payload type parameter A is discarded during rendering
    let template1: Template<Int> = .variable("x", payload: 42)
    let template2: Template<String> = .variable("x", payload: "metadata")
    let template3: Template<Bool> = .variable("x", payload: true)

    let result1 = Renderer.render(template1)
    let result2 = Renderer.render(template2)
    let result3 = Renderer.render(template3)

    // All should produce identical SwiftSyntax output (identifier "x")
    XCTAssertEqual(
      result1.description.trimmingCharacters(in: .whitespacesAndNewlines),
      result2.description.trimmingCharacters(in: .whitespacesAndNewlines),
      "Payloads should not affect rendered output"
    )
    XCTAssertEqual(
      result2.description.trimmingCharacters(in: .whitespacesAndNewlines),
      result3.description.trimmingCharacters(in: .whitespacesAndNewlines),
      "Payloads should not affect rendered output"
    )
  }
}
