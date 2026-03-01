import XCTest
import SwiftSyntax
@testable import MacroTemplateKit

// swiftlint:disable file_length type_body_length
// Justification: Comprehensive tests for all new Template/Statement cases added in phase 16-01.
// All test methods are cohesive: verifying rendering of the new MTK cases. Splitting reduces clarity.

/// Tests for all new Template and Statement cases added in MacroTemplateKit (phase 16-01).
///
/// Verifies Renderer renders: dictionary literals, subscript access, force-unwrap,
/// string interpolation, closures, guard-let bindings, switch statements, and assignments.
final class NewCasesRendererTests: XCTestCase {

  // MARK: - Dictionary Literal

  func testRenderDictionaryLiteral_empty() {
    let template: Template<Void> = .dictionaryLiteral([])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Should render as DictionaryExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("["), "Should contain opening bracket")
    XCTAssertTrue(description.contains("]"), "Should contain closing bracket")
    XCTAssertTrue(description.contains(":"), "Empty dictionary should render as [:]")
  }

  func testRenderDictionaryLiteral_nonEmpty() {
    let template: Template<Void> = .dictionaryLiteral([
      (key: .literal(.string("id")), value: .literal(.integer(1))),
      (key: .literal(.string("name")), value: .literal(.string("Alice"))),
    ])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Should render as DictionaryExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("id"), "Should contain first key")
    XCTAssertTrue(description.contains("1"), "Should contain first value")
    XCTAssertTrue(description.contains("name"), "Should contain second key")
    XCTAssertTrue(description.contains("Alice"), "Should contain second value")
  }

  func testRenderDictionaryLiteral_singleEntry() {
    let template: Template<Void> = .dictionaryLiteral([
      (key: .literal(.string("key")), value: .literal(.boolean(true)))
    ])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Should render as DictionaryExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("key"), "Should contain key")
    XCTAssertTrue(description.contains("true"), "Should contain value")
  }

  func testFluentFactory_dictionary() {
    let template: Template<Void> = .dictionary([
      (key: .literal(.string("x")), value: .literal(.integer(42)))
    ])
    let result = Renderer.render(template)
    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Fluent factory should produce DictionaryExprSyntax")
  }

  // MARK: - Subscript Access

  func testRenderSubscriptAccess_stringKey() {
    // row["id"]
    let template: Template<Void> = .subscriptAccess(
      base: .variable("row", payload: ()),
      index: .literal(.string("id"))
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(SubscriptCallExprSyntax.self), "Should render as SubscriptCallExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("row"), "Should contain base")
    XCTAssertTrue(description.contains("["), "Should contain opening subscript bracket")
    XCTAssertTrue(description.contains("id"), "Should contain index key")
    XCTAssertTrue(description.contains("]"), "Should contain closing subscript bracket")
  }

  func testRenderSubscriptAccess_integerIndex() {
    // array[0]
    let template: Template<Void> = .subscriptAccess(
      base: .variable("array", payload: ()),
      index: .literal(.integer(0))
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(SubscriptCallExprSyntax.self), "Should render as SubscriptCallExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("array"), "Should contain base name")
    XCTAssertTrue(description.contains("0"), "Should contain integer index")
  }

  func testFluentFactory_subscript() {
    let template: Template<Void> = Template<Void>.subscript(
      .variable("dict", payload: ()),
      index: .literal(.string("key"))
    )
    let result = Renderer.render(template)
    XCTAssertTrue(result.is(SubscriptCallExprSyntax.self), "Fluent factory should produce SubscriptCallExprSyntax")
  }

  // MARK: - Force Unwrap

  func testRenderForceUnwrap_variable() {
    // value!
    let template: Template<Void> = .forceUnwrap(.variable("value", payload: ()))
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ForceUnwrapExprSyntax.self), "Should render as ForceUnwrapExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("value"), "Should contain base expression")
    XCTAssertTrue(description.contains("!"), "Should contain force-unwrap operator")
  }

  func testRenderForceUnwrap_functionCall() {
    // getOptional()!
    let template: Template<Void> = .forceUnwrap(
      .functionCall(function: "getOptional", arguments: [])
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ForceUnwrapExprSyntax.self), "Should render as ForceUnwrapExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("getOptional"), "Should contain function name")
    XCTAssertTrue(description.contains("!"), "Should contain force-unwrap operator")
  }

  func testFluentFactory_unwrapped() {
    let template: Template<Void> = .unwrapped(.variable("optional", payload: ()))
    let result = Renderer.render(template)
    XCTAssertTrue(result.is(ForceUnwrapExprSyntax.self), "Fluent factory should produce ForceUnwrapExprSyntax")
  }

  // MARK: - String Interpolation

  func testRenderStringInterpolation_textOnly() {
    let template: Template<Void> = .stringInterpolation([.text("hello")])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(StringLiteralExprSyntax.self), "Should render as StringLiteralExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("hello"), "Should contain text segment")
  }

  func testRenderStringInterpolation_withExpression() {
    // "prefix_\(name)_suffix"
    let template: Template<Void> = .stringInterpolation([
      .text("prefix_"),
      .expression(.variable("name", payload: ())),
      .text("_suffix"),
    ])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(StringLiteralExprSyntax.self), "Should render as StringLiteralExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("prefix_"), "Should contain text prefix")
    XCTAssertTrue(description.contains("name"), "Should contain interpolated expression")
    XCTAssertTrue(description.contains("_suffix"), "Should contain text suffix")
  }

  func testRenderStringInterpolation_expressionOnly() {
    // "\(value)"
    let template: Template<Void> = .stringInterpolation([
      .expression(.variable("value", payload: ()))
    ])
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(StringLiteralExprSyntax.self), "Should render as StringLiteralExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("value"), "Should contain interpolated expression")
  }

  func testFluentFactory_interpolated() {
    let template: Template<Void> = .interpolated([
      .text("Hello, "),
      .expression(.variable("name", payload: ())),
    ])
    let result = Renderer.render(template)
    XCTAssertTrue(result.is(StringLiteralExprSyntax.self), "Fluent factory should produce StringLiteralExprSyntax")
  }

  // MARK: - Closure

  func testRenderClosure_noSignature() {
    // { body }
    let template: Template<Void> = .closure(ClosureSignature<Void>(
      parameters: [],
      returnType: nil,
      body: [.returnStatement(.literal(.integer(42)))]
    ))
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("{"), "Should contain opening brace")
    XCTAssertTrue(description.contains("42"), "Should contain body expression")
    XCTAssertTrue(description.contains("}"), "Should contain closing brace")
    XCTAssertFalse(description.contains("in"), "No-signature closure should not have 'in' keyword")
  }

  func testRenderClosure_withParametersAndReturnType() {
    // { (row: Row) -> Void in ... }
    let template: Template<Void> = .closure(ClosureSignature<Void>(
      parameters: [(name: "row", type: "Row")],
      returnType: "Void",
      body: [.expression(.functionCall(function: "process", arguments: [
        (label: nil, value: .variable("row", payload: ()))
      ]))]
    ))
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("row"), "Should contain parameter name")
    XCTAssertTrue(description.contains("Row"), "Should contain parameter type")
    XCTAssertTrue(description.contains("Void"), "Should contain return type")
    XCTAssertTrue(description.contains("in"), "Closure with signature should have 'in' keyword")
    XCTAssertTrue(description.contains("process"), "Should contain body")
  }

  func testRenderClosure_multipleParameters() {
    // { (a: Int, b: String) -> Bool in ... }
    let template: Template<Void> = .closure(ClosureSignature<Void>(
      parameters: [
        (name: "a", type: "Int"),
        (name: "b", type: "String"),
      ],
      returnType: "Bool",
      body: [.returnStatement(.literal(.boolean(true)))]
    ))
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("a"), "Should contain first parameter")
    XCTAssertTrue(description.contains("b"), "Should contain second parameter")
    XCTAssertTrue(description.contains("Bool"), "Should contain return type")
  }

  func testFluentFactory_closure() {
    let template: Template<Void> = .closure(
      params: [(name: "x", type: "Int")],
      returnType: "String",
      body: [.returnStatement(.literal(.string("value")))]
    )
    let result = Renderer.render(template)
    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Fluent factory should produce ClosureExprSyntax")
  }

  // MARK: - Template Assignment Expression

  func testRenderAssignmentExpression() {
    // self.name = name (as expression)
    let template: Template<Void> = .assignment(
      lhs: .propertyAccess(base: .variable("self", payload: ()), property: "name"),
      rhs: .variable("name", payload: ())
    )
    let result = Renderer.render(template)

    XCTAssertTrue(result.is(InfixOperatorExprSyntax.self), "Should render as InfixOperatorExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("self"), "Should contain lhs base")
    XCTAssertTrue(description.contains("name"), "Should contain property and rhs")
    XCTAssertTrue(description.contains("="), "Should contain assignment operator")
  }

  // MARK: - Guard Let Binding (Statement)

  func testRenderGuardLetBinding_withoutType() {
    // guard let value = expr else { throw error }
    let statement: Statement<Void> = .guardLetBinding(
      name: "value",
      type: nil,
      initializer: .functionCall(function: "getValue", arguments: []),
      elseBody: [.throwStatement(.variable("SomeError", payload: ()))]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("guard"), "Should contain guard keyword")
    XCTAssertTrue(description.contains("let"), "Should contain let keyword")
    XCTAssertTrue(description.contains("value"), "Should contain binding name")
    XCTAssertTrue(description.contains("getValue"), "Should contain initializer expression")
    XCTAssertTrue(description.contains("else"), "Should contain else keyword")
    XCTAssertTrue(description.contains("throw"), "Should contain throw in else body")
    XCTAssertFalse(description.contains(": "), "Without type, should not have type annotation")
  }

  func testRenderGuardLetBinding_withType() {
    // guard let id: Int = row["id"] else { return }
    let statement: Statement<Void> = .guardLetBinding(
      name: "id",
      type: "Int",
      initializer: .subscriptAccess(
        base: .variable("row", payload: ()),
        index: .literal(.string("id"))
      ),
      elseBody: [.returnStatement(nil)]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("guard"), "Should contain guard keyword")
    XCTAssertTrue(description.contains("let"), "Should contain let keyword")
    XCTAssertTrue(description.contains("id"), "Should contain binding name")
    XCTAssertTrue(description.contains("Int"), "Should contain type annotation")
    XCTAssertTrue(description.contains("row"), "Should contain subscript base")
    XCTAssertTrue(description.contains("else"), "Should contain else keyword")
    XCTAssertTrue(description.contains("return"), "Should contain return in else body")
  }

  func testRenderGuardLetBinding_distinguishedFromBooleanGuard() {
    // Verify this produces OptionalBindingConditionSyntax (guard let), not boolean guard
    let statement: Statement<Void> = .guardLetBinding(
      name: "x",
      type: nil,
      initializer: .functionCall(function: "optional", arguments: []),
      elseBody: [.returnStatement(nil)]
    )
    let result = Renderer.render(statement)
    let description = result.formatted().description

    // guard let x = optional() else { return }
    XCTAssertTrue(description.contains("guard let x"), "Should use guard let syntax, not boolean guard")
  }

  // MARK: - Switch Statement

  func testRenderSwitchStatement_expressionAndDefault() {
    // switch value { case "a": ...; default: ... }
    let statement: Statement<Void> = .switchStatement(
      subject: .variable("value", payload: ()),
      cases: [
        SwitchCase(
          pattern: .stringLiteral("a"),
          body: [.returnStatement(.literal(.integer(1)))]
        ),
        SwitchCase(
          pattern: .defaultCase,
          body: [.returnStatement(.literal(.integer(0)))]
        ),
      ]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch"), "Should contain switch keyword")
    XCTAssertTrue(description.contains("value"), "Should contain subject")
    XCTAssertTrue(description.contains("case"), "Should contain case keyword")
    XCTAssertTrue(description.contains("a"), "Should contain string literal pattern")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
    XCTAssertTrue(description.contains("return"), "Should contain return statements")
  }

  func testRenderSwitchStatement_expressionPattern() {
    // switch myEnum { case .someCase: ... }
    let statement: Statement<Void> = .switchStatement(
      subject: .variable("myEnum", payload: ()),
      cases: [
        SwitchCase(
          pattern: .expression(.propertyAccess(base: .variable("MyEnum", payload: ()), property: "someCase")),
          body: [.expression(.functionCall(function: "handle", arguments: []))]
        ),
        SwitchCase(
          pattern: .defaultCase,
          body: [.returnStatement(nil)]
        ),
      ]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch"), "Should contain switch keyword")
    XCTAssertTrue(description.contains("myEnum"), "Should contain subject")
    XCTAssertTrue(description.contains("someCase"), "Should contain expression pattern")
    XCTAssertTrue(description.contains("handle"), "Should contain case body")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
  }

  func testRenderSwitchStatement_multipleStringLiteralCases() {
    let statement: Statement<Void> = .switchStatement(
      subject: .variable("kind", payload: ()),
      cases: [
        SwitchCase(pattern: .stringLiteral("insert"), body: [.returnStatement(.literal(.integer(1)))]),
        SwitchCase(pattern: .stringLiteral("update"), body: [.returnStatement(.literal(.integer(2)))]),
        SwitchCase(pattern: .stringLiteral("delete"), body: [.returnStatement(.literal(.integer(3)))]),
        SwitchCase(pattern: .defaultCase, body: [.returnStatement(.literal(.integer(0)))]),
      ]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch kind"), "Should contain switch with subject")
    XCTAssertTrue(description.contains("insert"), "Should contain first case")
    XCTAssertTrue(description.contains("update"), "Should contain second case")
    XCTAssertTrue(description.contains("delete"), "Should contain third case")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
  }

  // MARK: - Assignment Statement

  func testRenderAssignmentStatement() {
    // self.name = name (as statement)
    let statement: Statement<Void> = .assignmentStatement(
      lhs: .propertyAccess(base: .variable("self", payload: ()), property: "name"),
      rhs: .variable("name", payload: ())
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("self"), "Should contain lhs base")
    XCTAssertTrue(description.contains("name"), "Should contain property and rhs name")
    XCTAssertTrue(description.contains("="), "Should contain assignment operator")
  }

  func testRenderAssignmentStatement_variableToVariable() {
    // x = y
    let statement: Statement<Void> = .assignmentStatement(
      lhs: .variable("x", payload: ()),
      rhs: .variable("y", payload: ())
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("x"), "Should contain lhs variable")
    XCTAssertTrue(description.contains("y"), "Should contain rhs variable")
    XCTAssertTrue(description.contains("="), "Should contain assignment operator")
  }

  // MARK: - Functor Map Tests for New Types

  func testMap_dictionaryLiteral() {
    let template: Template<Int> = .dictionaryLiteral([
      (key: .variable("k", payload: 1), value: .variable("v", payload: 2))
    ])
    let mapped: Template<String> = template.map { "\($0)" }

    if case .dictionaryLiteral(let entries) = mapped {
      XCTAssertEqual(entries.count, 1, "Should preserve entry count")
    } else {
      XCTFail("Should remain dictionaryLiteral after map")
    }
  }

  func testMap_subscriptAccess() {
    let template: Template<Int> = .subscriptAccess(
      base: .variable("base", payload: 1),
      index: .variable("idx", payload: 2)
    )
    let mapped: Template<String> = template.map { "\($0)" }

    if case .subscriptAccess = mapped {
      // OK
    } else {
      XCTFail("Should remain subscriptAccess after map")
    }
  }

  func testMap_forceUnwrap() {
    let template: Template<Int> = .forceUnwrap(.variable("opt", payload: 5))
    let mapped: Template<String> = template.map { "\($0)" }

    if case .forceUnwrap = mapped {
      // OK
    } else {
      XCTFail("Should remain forceUnwrap after map")
    }
  }

  func testMap_stringInterpolation() {
    let template: Template<Int> = .stringInterpolation([
      .text("prefix"),
      .expression(.variable("x", payload: 3)),
    ])
    let mapped: Template<String> = template.map { "\($0)" }

    if case .stringInterpolation(let segments) = mapped {
      XCTAssertEqual(segments.count, 2, "Should preserve segment count")
    } else {
      XCTFail("Should remain stringInterpolation after map")
    }
  }

  func testMap_closure() {
    let template: Template<Int> = .closure(ClosureSignature<Int>(
      parameters: [(name: "x", type: "Int")],
      returnType: "Void",
      body: [.expression(.variable("x", payload: 7))]
    ))
    let mapped: Template<String> = template.map { "\($0)" }

    if case .closure(let sig) = mapped {
      XCTAssertEqual(sig.parameters.count, 1, "Should preserve parameters")
      XCTAssertEqual(sig.returnType, "Void", "Should preserve return type")
      XCTAssertEqual(sig.body.count, 1, "Should preserve body statements")
    } else {
      XCTFail("Should remain closure after map")
    }
  }

  // MARK: - Equatable/Hashable Tests for New Types

  func testEquatable_stringInterpolationSegment_text() {
    let a: StringInterpolationSegment<Int> = .text("hello")
    let b: StringInterpolationSegment<Int> = .text("hello")
    let c: StringInterpolationSegment<Int> = .text("world")

    XCTAssertEqual(a, b, "Same text segments should be equal")
    XCTAssertNotEqual(a, c, "Different text segments should not be equal")
  }

  func testEquatable_switchCasePattern_defaultCase() {
    let a: SwitchCasePattern<Int> = .defaultCase
    let b: SwitchCasePattern<Int> = .defaultCase
    XCTAssertEqual(a, b, "Default cases should be equal")
  }

  func testEquatable_switchCasePattern_stringLiteral() {
    let a: SwitchCasePattern<Int> = .stringLiteral("foo")
    let b: SwitchCasePattern<Int> = .stringLiteral("foo")
    let c: SwitchCasePattern<Int> = .stringLiteral("bar")

    XCTAssertEqual(a, b, "Same string literal patterns should be equal")
    XCTAssertNotEqual(a, c, "Different string literal patterns should not be equal")
  }

  func testHashable_switchCase() {
    let case1: SwitchCase<Int> = SwitchCase(
      pattern: .stringLiteral("a"),
      body: [.returnStatement(nil)]
    )
    let case2: SwitchCase<Int> = SwitchCase(
      pattern: .stringLiteral("a"),
      body: [.returnStatement(nil)]
    )
    XCTAssertEqual(case1.hashValue, case2.hashValue, "Equal switch cases should have equal hash values")
  }
}
