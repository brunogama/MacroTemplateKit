import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Tests for all new Template and Statement cases added in MacroTemplateKit (phase 16-01).
///
/// Verifies Renderer renders: dictionary literals, subscript access, force-unwrap,
/// string interpolation, closures, guard-let bindings, switch statements, and assignments.
final class NewCasesRendererTests: XCTestCase {
  // MARK: - Dictionary Literal

  func testRenderDictionaryLiteral_empty() throws {
    let template: Template<Void> = .dictionaryLiteral([])
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Should render as DictionaryExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("["), "Should contain opening bracket")
    XCTAssertTrue(description.contains("]"), "Should contain closing bracket")
    XCTAssertTrue(description.contains(":"), "Empty dictionary should render as [:]")
  }

  func testRenderDictionaryLiteral_nonEmpty() throws {
    let template: Template<Void> = .dictionaryLiteral([
      (key: .literal(.string("id")), value: .literal(.integer(1))),
      (key: .literal(.string("name")), value: .literal(.string("Alice"))),
    ])
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Should render as DictionaryExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("id"), "Should contain first key")
    XCTAssertTrue(description.contains("1"), "Should contain first value")
    XCTAssertTrue(description.contains("name"), "Should contain second key")
    XCTAssertTrue(description.contains("Alice"), "Should contain second value")
  }

  func testRenderDictionaryLiteral_singleEntry() throws {
    let template: Template<Void> = .dictionaryLiteral([
      (key: .literal(.string("key")), value: .literal(.boolean(true)))
    ])
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(DictionaryExprSyntax.self), "Should render as DictionaryExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("key"), "Should contain key")
    XCTAssertTrue(description.contains("true"), "Should contain value")
  }

  func testFluentFactory_dictionary() throws {
    let template: Template<Void> = .dictionary([
      (key: .literal(.string("x")), value: .literal(.integer(42)))
    ])
    let result = try Renderer.render(template)
    XCTAssertTrue(
      result.is(DictionaryExprSyntax.self), "Fluent factory should produce DictionaryExprSyntax"
    )
  }

  // MARK: - Subscript Access

  func testRenderSubscriptAccess_stringKey() throws {
    // row["id"]
    let template: Template<Void> = .subscriptAccess(
      base: .variable("row", payload: ()),
      index: .literal(.string("id"))
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(
      result.is(SubscriptCallExprSyntax.self), "Should render as SubscriptCallExprSyntax"
    )
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("row"), "Should contain base")
    XCTAssertTrue(description.contains("["), "Should contain opening subscript bracket")
    XCTAssertTrue(description.contains("id"), "Should contain index key")
    XCTAssertTrue(description.contains("]"), "Should contain closing subscript bracket")
  }

  func testRenderSubscriptAccess_integerIndex() throws {
    // array[0]
    let template: Template<Void> = .subscriptAccess(
      base: .variable("array", payload: ()),
      index: .literal(.integer(0))
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(
      result.is(SubscriptCallExprSyntax.self), "Should render as SubscriptCallExprSyntax"
    )
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("array"), "Should contain base name")
    XCTAssertTrue(description.contains("0"), "Should contain integer index")
  }

  func testFluentFactory_subscript() throws {
    let template = Template<Void>.subscript(
      .variable("dict", payload: ()),
      index: .literal(.string("key"))
    )
    let result = try Renderer.render(template)
    XCTAssertTrue(
      result.is(SubscriptCallExprSyntax.self),
      "Fluent factory should produce SubscriptCallExprSyntax"
    )
  }

  // MARK: - Force Unwrap

  func testRenderForceUnwrap_variable() throws {
    // value!
    let template: Template<Void> = .forceUnwrap(.variable("value", payload: ()))
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(ForceUnwrapExprSyntax.self), "Should render as ForceUnwrapExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("value"), "Should contain base expression")
    XCTAssertTrue(description.contains("!"), "Should contain force-unwrap operator")
  }

  func testRenderForceUnwrap_functionCall() throws {
    // getOptional()!
    let template: Template<Void> = .forceUnwrap(
      .functionCall(function: "getOptional", arguments: [])
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(ForceUnwrapExprSyntax.self), "Should render as ForceUnwrapExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("getOptional"), "Should contain function name")
    XCTAssertTrue(description.contains("!"), "Should contain force-unwrap operator")
  }

  func testFluentFactory_unwrapped() throws {
    let template: Template<Void> = .unwrapped(.variable("optional", payload: ()))
    let result = try Renderer.render(template)
    XCTAssertTrue(
      result.is(ForceUnwrapExprSyntax.self), "Fluent factory should produce ForceUnwrapExprSyntax"
    )
  }

  // MARK: - String Interpolation

  func testRenderStringInterpolation_textOnly() throws {
    let template: Template<Void> = .stringInterpolation([.text("hello")])
    let result = try Renderer.render(template)

    XCTAssertTrue(
      result.is(StringLiteralExprSyntax.self), "Should render as StringLiteralExprSyntax"
    )
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("hello"), "Should contain text segment")
  }

  func testRenderStringInterpolation_withExpression() throws {
    // "prefix_\(name)_suffix"
    let template: Template<Void> = .stringInterpolation([
      .text("prefix_"),
      .expression(.variable("name", payload: ())),
      .text("_suffix"),
    ])
    let result = try Renderer.render(template)

    XCTAssertTrue(
      result.is(StringLiteralExprSyntax.self), "Should render as StringLiteralExprSyntax"
    )
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("prefix_"), "Should contain text prefix")
    XCTAssertTrue(description.contains("name"), "Should contain interpolated expression")
    XCTAssertTrue(description.contains("_suffix"), "Should contain text suffix")
  }

  func testRenderStringInterpolation_expressionOnly() throws {
    // "\(value)"
    let template: Template<Void> = .stringInterpolation([
      .expression(.variable("value", payload: ()))
    ])
    let result = try Renderer.render(template)

    XCTAssertTrue(
      result.is(StringLiteralExprSyntax.self), "Should render as StringLiteralExprSyntax"
    )
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("value"), "Should contain interpolated expression")
  }

  func testFluentFactory_interpolated() throws {
    let template: Template<Void> = .interpolated([
      .text("Hello, "),
      .expression(.variable("name", payload: ())),
    ])
    let result = try Renderer.render(template)
    XCTAssertTrue(
      result.is(StringLiteralExprSyntax.self),
      "Fluent factory should produce StringLiteralExprSyntax"
    )
  }

  // MARK: - Closure

  func testRenderClosure_noSignature() throws {
    // { body }
    let template: Template<Void> = .closure(
      ClosureSignature<Void>(
        parameters: [],
        returnType: nil,
        body: [.returnStatement(.literal(.integer(42)))]
      )
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("{"), "Should contain opening brace")
    XCTAssertTrue(description.contains("42"), "Should contain body expression")
    XCTAssertTrue(description.contains("}"), "Should contain closing brace")
    XCTAssertFalse(description.contains("in"), "No-signature closure should not have 'in' keyword")
  }

  func testRenderClosure_withParametersAndReturnType() throws {
    // { (row: Row) -> Void in ... }
    let template: Template<Void> = .closure(
      ClosureSignature<Void>(
        parameters: [(name: "row", type: "Row")],
        returnType: "Void",
        body: [
          .expression(
            .functionCall(
              function: "process",
              arguments: [
                (label: nil, value: .variable("row", payload: ()))
              ]
            )
          )
        ]
      )
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("row"), "Should contain parameter name")
    XCTAssertTrue(description.contains("Row"), "Should contain parameter type")
    XCTAssertTrue(description.contains("Void"), "Should contain return type")
    XCTAssertTrue(description.contains("in"), "Closure with signature should have 'in' keyword")
    XCTAssertTrue(description.contains("process"), "Should contain body")
  }

  func testRenderClosure_multipleParameters() throws {
    // { (a: Int, b: String) -> Bool in ... }
    let template: Template<Void> = .closure(
      ClosureSignature<Void>(
        parameters: [
          (name: "a", type: "Int"),
          (name: "b", type: "String"),
        ],
        returnType: "Bool",
        body: [.returnStatement(.literal(.boolean(true)))]
      )
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("a"), "Should contain first parameter")
    XCTAssertTrue(description.contains("b"), "Should contain second parameter")
    XCTAssertTrue(description.contains("Bool"), "Should contain return type")
  }

  func testRenderClosure_withAttributes() throws {
    let template: Template<Void> = .closure(
      ClosureSignature<Void>(
        attributes: [.sendable],
        parameters: [(name: "value", type: "Int")],
        returnType: "Void",
        body: [
          .expression(
            .call(
              "handle",
              arguments: [
                .unlabeled(.variable("value"))
              ]
            )
          )
        ]
      )
    )
    let result = try Renderer.render(template)

    XCTAssertTrue(result.is(ClosureExprSyntax.self), "Should render as ClosureExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("@Sendable"), "Should contain closure attribute")
    XCTAssertTrue(description.contains("value"), "Should contain parameter name")
    XCTAssertTrue(description.contains("Int"), "Should contain parameter type")
    XCTAssertTrue(description.contains("Void"), "Should contain return type")
    XCTAssertTrue(description.contains("handle(value)"), "Should contain body call")
  }

  func testFluentFactory_closure() throws {
    let template: Template<Void> = .closure(
      params: [(name: "x", type: "Int")],
      returnType: "String",
      body: [.returnStatement(.literal(.string("value")))]
    )
    let result = try Renderer.render(template)
    XCTAssertTrue(
      result.is(ClosureExprSyntax.self), "Fluent factory should produce ClosureExprSyntax"
    )
  }

  // MARK: - Template Assignment Expression

  func testRenderAssignmentExpression() throws {
    // self.name = name (as expression)
    let template: Template<Void> = .assignment(
      lhs: .propertyAccess(base: .variable("self", payload: ()), property: "name"),
      rhs: .variable("name", payload: ())
    )
    let result = try Renderer.render(template)

    // The parse-backed renderer yields an unfolded `SequenceExprSyntax` for
    // `=` until `SwiftOperators.OperatorTable.foldAll` folds it into
    // `InfixOperatorExprSyntax` (a fold this renderer deliberately doesn't
    // perform, since only token content — not tree shape — is guaranteed);
    // the legacy structural renderer builds `InfixOperatorExprSyntax`
    // directly. Both are token-equivalent.
    XCTAssertTrue(
      result.is(InfixOperatorExprSyntax.self) || result.is(SequenceExprSyntax.self),
      "Should render as InfixOperatorExprSyntax or (pre-fold) SequenceExprSyntax"
    )
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("self"), "Should contain lhs base")
    XCTAssertTrue(description.contains("name"), "Should contain property and rhs")
    XCTAssertTrue(description.contains("="), "Should contain assignment operator")
  }

  // MARK: - Guard Let Binding (Statement)

  func testRenderGuardLetBinding_withoutType() throws {
    // guard let value = expr else { throw error }
    let statement: Statement<Void> = .guardLetBinding(
      name: "value",
      type: nil,
      initializer: .functionCall(function: "getValue", arguments: []),
      elseBody: [.throwStatement(.variable("SomeError", payload: ()))]
    )
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("guard"), "Should contain guard keyword")
    XCTAssertTrue(description.contains("let"), "Should contain let keyword")
    XCTAssertTrue(description.contains("value"), "Should contain binding name")
    XCTAssertTrue(description.contains("getValue"), "Should contain initializer expression")
    XCTAssertTrue(description.contains("else"), "Should contain else keyword")
    XCTAssertTrue(description.contains("throw"), "Should contain throw in else body")
    XCTAssertFalse(description.contains(": "), "Without type, should not have type annotation")
  }

  func testRenderGuardLetBinding_withType() throws {
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
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("guard"), "Should contain guard keyword")
    XCTAssertTrue(description.contains("let"), "Should contain let keyword")
    XCTAssertTrue(description.contains("id"), "Should contain binding name")
    XCTAssertTrue(description.contains("Int"), "Should contain type annotation")
    XCTAssertTrue(description.contains("row"), "Should contain subscript base")
    XCTAssertTrue(description.contains("else"), "Should contain else keyword")
    XCTAssertTrue(description.contains("return"), "Should contain return in else body")
  }

  func testRenderGuardLetBinding_distinguishedFromBooleanGuard() throws {
    // Verify this produces OptionalBindingConditionSyntax (guard let), not boolean guard
    let statement: Statement<Void> = .guardLetBinding(
      name: "x",
      type: nil,
      initializer: .functionCall(function: "optional", arguments: []),
      elseBody: [.returnStatement(nil)]
    )
    let result = try Renderer.render(statement)
    let description = result.formatted().description

    // guard let x = optional() else { return }
    XCTAssertTrue(
      description.contains("guard let x"), "Should use guard let syntax, not boolean guard"
    )
  }

  // MARK: - Switch Statement

  func testRenderSwitchStatement_expressionAndDefault() throws {
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
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch"), "Should contain switch keyword")
    XCTAssertTrue(description.contains("value"), "Should contain subject")
    XCTAssertTrue(description.contains("case"), "Should contain case keyword")
    XCTAssertTrue(description.contains("a"), "Should contain string literal pattern")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
    XCTAssertTrue(description.contains("return"), "Should contain return statements")
  }

  func testRenderSwitchStatement_expressionPattern() throws {
    // switch myEnum { case .someCase: ... }
    let statement: Statement<Void> = .switchStatement(
      subject: .variable("myEnum", payload: ()),
      cases: [
        SwitchCase(
          pattern: .expression(
            .propertyAccess(base: .variable("MyEnum", payload: ()), property: "someCase")
          ),
          body: [.expression(.functionCall(function: "handle", arguments: []))]
        ),
        SwitchCase(
          pattern: .defaultCase,
          body: [.returnStatement(nil)]
        ),
      ]
    )
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch"), "Should contain switch keyword")
    XCTAssertTrue(description.contains("myEnum"), "Should contain subject")
    XCTAssertTrue(description.contains("someCase"), "Should contain expression pattern")
    XCTAssertTrue(description.contains("handle"), "Should contain case body")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
  }

  func testRenderSwitchStatement_multipleStringLiteralCases() throws {
    let statement: Statement<Void> = .switchStatement(
      subject: .variable("kind", payload: ()),
      cases: [
        SwitchCase(
          pattern: .stringLiteral("insert"), body: [.returnStatement(.literal(.integer(1)))]
        ),
        SwitchCase(
          pattern: .stringLiteral("update"), body: [.returnStatement(.literal(.integer(2)))]
        ),
        SwitchCase(
          pattern: .stringLiteral("delete"), body: [.returnStatement(.literal(.integer(3)))]
        ),
        SwitchCase(pattern: .defaultCase, body: [.returnStatement(.literal(.integer(0)))]),
      ]
    )
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch kind"), "Should contain switch with subject")
    XCTAssertTrue(description.contains("insert"), "Should contain first case")
    XCTAssertTrue(description.contains("update"), "Should contain second case")
    XCTAssertTrue(description.contains("delete"), "Should contain third case")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
  }

  // MARK: - Assignment Statement

  func testRenderAssignmentStatement() throws {
    // self.name = name (as statement)
    let statement: Statement<Void> = .assignmentStatement(
      lhs: .propertyAccess(base: .variable("self", payload: ()), property: "name"),
      rhs: .variable("name", payload: ())
    )
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("self"), "Should contain lhs base")
    XCTAssertTrue(description.contains("name"), "Should contain property and rhs name")
    XCTAssertTrue(description.contains("="), "Should contain assignment operator")
  }

  func testRenderAssignmentStatement_variableToVariable() throws {
    // x = y
    let statement: Statement<Void> = .assignmentStatement(
      lhs: .variable("x", payload: ()),
      rhs: .variable("y", payload: ())
    )
    let result = try Renderer.render(statement)

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
    let template: Template<Int> = .closure(
      ClosureSignature<Int>(
        parameters: [(name: "x", type: "Int")],
        returnType: "Void",
        body: [.expression(.variable("x", payload: 7))]
      )
    )
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
    XCTAssertEqual(
      case1.hashValue, case2.hashValue, "Equal switch cases should have equal hash values"
    )
  }

  // MARK: - Self Access (Template.selfAccess)

  func testRenderSelfAccess_simpleType() throws {
    // String.self
    let template: Template<Void> = .selfAccess("String")
    let result = try Renderer.render(template)

    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("String"), "Should contain type name")
    XCTAssertTrue(description.contains(".self"), "Should contain .self access")
  }

  func testRenderSelfAccess_customType() throws {
    // MyStruct.self
    let template: Template<Void> = .selfAccess("MyStruct")
    let result = try Renderer.render(template)

    let description = result.trimmedDescription
    XCTAssertEqual(description, "MyStruct.self", "Should render as TypeName.self")
  }

  func testFluentFactory_selfType() throws {
    let template: Template<Void> = .selfType("Int")
    let result = try Renderer.render(template)

    XCTAssertEqual(result.trimmedDescription, "Int.self", "Fluent factory should render Type.self")
  }

  func testMap_selfAccess() {
    let template: Template<Int> = .selfAccess("Double")
    let mapped: Template<String> = template.map { "\($0)" }

    if case .selfAccess(let typeName) = mapped {
      XCTAssertEqual(typeName, "Double", "Should preserve type name through map")
    } else {
      XCTFail("Should remain selfAccess after map")
    }
  }

  func testEquatable_selfAccess() {
    let a: Template<Int> = .selfAccess("String")
    let b: Template<Int> = .selfAccess("String")
    let c: Template<Int> = .selfAccess("Int")

    XCTAssertEqual(a, b, "Same selfAccess should be equal")
    XCTAssertNotEqual(a, c, "Different selfAccess should not be equal")
  }

  // MARK: - Failable Initializer (InitializerSignature.isFailable)

  func testRenderFailableInitializer() throws {
    // init?(rawValue: String) { ... }
    let decl: Declaration<Void> = .initDecl(
      InitializerSignature<Void>(
        isFailable: true,
        parameters: [ParameterSignature(name: "rawValue", type: "String")],
        body: [.returnStatement(.literal(.nil))]
      )
    )
    let result = try Renderer.render(decl)

    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("init?"), "Should render as failable init?")
    XCTAssertTrue(description.contains("rawValue"), "Should contain parameter name")
    XCTAssertTrue(description.contains("String"), "Should contain parameter type")
  }

  func testRenderNonFailableInitializer() throws {
    // init(value: Int) { ... }
    let decl: Declaration<Void> = .initDecl(
      InitializerSignature<Void>(
        parameters: [ParameterSignature(name: "value", type: "Int")],
        body: []
      )
    )
    let result = try Renderer.render(decl)

    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("init"), "Should contain init")
    XCTAssertFalse(description.contains("init?"), "Non-failable should not have question mark")
  }

  // MARK: - Mutating Function (FunctionSignature.isMutating)

  func testRenderMutatingFunction() throws {
    // mutating func update(value: Int) { ... }
    let decl: Declaration<Void> = .function(
      FunctionSignature<Void>(
        isMutating: true,
        name: "update",
        parameters: [ParameterSignature(name: "value", type: "Int")],
        body: []
      )
    )
    let result = try Renderer.render(decl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("mutating"), "Should contain mutating modifier")
    XCTAssertTrue(description.contains("update"), "Should contain func name")
  }

  func testRenderNonMutatingFunction() throws {
    // func read() { ... }
    let decl: Declaration<Void> = .function(
      FunctionSignature<Void>(
        name: "read",
        body: []
      )
    )
    let result = try Renderer.render(decl)

    let description = result.formatted().description
    XCTAssertFalse(
      description.contains("mutating"), "Non-mutating func should not have mutating modifier"
    )
    XCTAssertTrue(description.contains("read"), "Should contain func name")
  }

  func testRenderStaticMutatingNotCombined() throws {
    // static func (isMutating should not apply alongside static in practice,
    // but test that both modifiers appear if set)
    let decl: Declaration<Void> = .function(
      FunctionSignature<Void>(
        isStatic: true,
        isMutating: true,
        name: "reset"
      )
    )
    let result = try Renderer.render(decl)

    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("static"), "Should contain static modifier")
    XCTAssertTrue(description.contains("mutating"), "Should contain mutating modifier")
  }

  // MARK: - Break Statement

  func testRenderBreakStatement() throws {
    let statement: Statement<Void> = .breakStatement
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("break"), "Should render break statement")
  }

  func testBreakStatementInSwitchDefault() throws {
    // switch x { case "a": ...; default: break }
    let statement: Statement<Void> = .switchStatement(
      subject: .variable("x", payload: ()),
      cases: [
        SwitchCase(
          pattern: .stringLiteral("a"),
          body: [.returnStatement(.literal(.integer(1)))]
        ),
        SwitchCase(
          pattern: .defaultCase,
          body: [.breakStatement]
        ),
      ]
    )
    let result = try Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("switch"), "Should contain switch")
    XCTAssertTrue(description.contains("default"), "Should contain default case")
    XCTAssertTrue(description.contains("break"), "Default case should contain break")
  }

  func testMap_breakStatement() {
    let statement: Statement<Int> = .breakStatement
    let mapped: Statement<String> = statement.map { "\($0)" }

    if case .breakStatement = mapped {
      // OK
    } else {
      XCTFail("Should remain breakStatement after map")
    }
  }

  // MARK: - Tuple Literal

  func testRenderTupleLiteral_twoElements() throws {
    let template: Template<Void> = .tupleLiteral([
      .variable("x", payload: ()),
      .literal(.string("hello")),
    ])
    let result = try Renderer.render(template)
    XCTAssertTrue(result.is(TupleExprSyntax.self), "Should render as TupleExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.hasPrefix("("), "Should start with opening paren")
    XCTAssertTrue(description.hasSuffix(")"), "Should end with closing paren")
    XCTAssertTrue(description.contains("x"), "Should contain first element")
    XCTAssertTrue(description.contains("hello"), "Should contain second element")
    XCTAssertTrue(description.contains(","), "Should contain comma separator")
  }

  func testRenderTupleLiteral_singleElement() throws {
    let template: Template<Void> = .tupleLiteral([
      .literal(.integer(42))
    ])
    let result = try Renderer.render(template)
    XCTAssertTrue(result.is(TupleExprSyntax.self), "Should render as TupleExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.hasPrefix("("), "Should start with opening paren")
    XCTAssertTrue(description.hasSuffix(")"), "Should end with closing paren")
    XCTAssertTrue(description.contains("42"), "Should contain the element")
  }

  func testRenderTupleLiteral_empty() throws {
    let template: Template<Void> = .tupleLiteral([])
    let result = try Renderer.render(template)
    XCTAssertTrue(result.is(TupleExprSyntax.self), "Should render as TupleExprSyntax")
    XCTAssertEqual(result.trimmedDescription, "()", "Empty tuple should render as ()")
  }

  func testFluentFactory_tuple() throws {
    let template: Template<Void> = .tuple(
      .literal(.integer(1)),
      .literal(.string("two"))
    )
    let result = try Renderer.render(template)
    XCTAssertTrue(result.is(TupleExprSyntax.self), "Fluent factory should produce TupleExprSyntax")
    let description = result.trimmedDescription
    XCTAssertTrue(description.contains("1"), "Should contain first element")
    XCTAssertTrue(description.contains("two"), "Should contain second element")
    XCTAssertTrue(description.contains(","), "Should contain comma separator")
  }

  func testMap_tupleLiteral() {
    let template: Template<Int> = .tupleLiteral([
      .variable("a", payload: 1),
      .variable("b", payload: 2),
    ])
    let mapped = template.map { $0 * 10 }
    if case .tupleLiteral(let elements) = mapped,
      case .variable(_, let p1) = elements[0],
      case .variable(_, let p2) = elements[1]
    {
      XCTAssertEqual(p1, 10)
      XCTAssertEqual(p2, 20)
    } else {
      XCTFail("Expected tupleLiteral with mapped payloads")
    }
  }

  func testEquatable_tupleLiteral() {
    let t1: Template<Int> = .tupleLiteral([.literal(.integer(1))])
    let t2: Template<Int> = .tupleLiteral([.literal(.integer(1))])
    let t3: Template<Int> = .tupleLiteral([.literal(.integer(2))])
    XCTAssertEqual(t1, t2)
    XCTAssertNotEqual(t1, t3)
  }

  func testHashable_tupleLiteral() {
    let t1: Template<Int> = .tupleLiteral([.literal(.integer(1))])
    let t2: Template<Int> = .tupleLiteral([.literal(.integer(1))])
    XCTAssertEqual(t1.hashValue, t2.hashValue)
  }

  // MARK: - SubscriptCall Tests

  func testRenderSubscriptCall_withDefault() throws {
    let template: Template<Void> = .subscriptCall(
      base: .variable("dict", payload: ()),
      arguments: [
        (label: nil, value: .literal(.string("key"))),
        (label: "default", value: .literal(.string("fallback"))),
      ]
    )
    let result = try Renderer.render(template)
    XCTAssertEqual(result.description, #"dict["key", default: "fallback"]"#)
  }

  func testRenderSubscriptCall_multipleLabeled() throws {
    let template: Template<Void> = .subscriptCall(
      base: .variable("grid", payload: ()),
      arguments: [
        (label: "row", value: .literal(.integer(1))),
        (label: "col", value: .literal(.integer(2))),
      ]
    )
    let result = try Renderer.render(template)
    XCTAssertEqual(result.description, "grid[row: 1, col: 2]")
  }

  func testMap_subscriptCall() {
    let template: Template<Int> = .subscriptCall(
      base: .variable("dict", payload: 1),
      arguments: [
        (label: nil, value: .variable("key", payload: 2)),
        (label: "default", value: .variable("dflt", payload: 3)),
      ]
    )
    let mapped = template.map { $0 * 10 }
    if case .subscriptCall(let base, let args) = mapped,
      case .variable(_, let basePayload) = base,
      case .variable(_, let argPayload1) = args[0].value,
      case .variable(_, let argPayload2) = args[1].value
    {
      XCTAssertEqual(basePayload, 10)
      XCTAssertEqual(argPayload1, 20)
      XCTAssertEqual(argPayload2, 30)
    } else {
      XCTFail("Expected subscriptCall with mapped payloads")
    }
  }

  func testEquatable_subscriptCall() {
    let t1: Template<Int> = .subscriptCall(
      base: .variable("d", payload: 0),
      arguments: [(label: nil, value: .literal(.integer(1)))]
    )
    let t2: Template<Int> = .subscriptCall(
      base: .variable("d", payload: 0),
      arguments: [(label: nil, value: .literal(.integer(1)))]
    )
    let t3: Template<Int> = .subscriptCall(
      base: .variable("d", payload: 0),
      arguments: [(label: nil, value: .literal(.integer(2)))]
    )
    XCTAssertEqual(t1, t2)
    XCTAssertNotEqual(t1, t3)
  }

  // MARK: - For-In Statement Map Tests

  func testMap_forInStatement() {
    let stmt: Statement<Int> = .forInStatement(
      variable: "item",
      collection: .variable("list", payload: 1),
      body: [.expression(.variable("item", payload: 2))]
    )
    let mapped = stmt.map { $0 * 10 }
    guard case .forInStatement(let variable, let collection, let body) = mapped else {
      XCTFail("Expected forInStatement")
      return
    }
    XCTAssertEqual(variable, "item", "Variable name should be preserved")
    guard case .variable(_, let collectionPayload) = collection else {
      XCTFail("Expected variable collection")
      return
    }
    XCTAssertEqual(collectionPayload, 10, "Collection payload should be transformed")
    guard case .expression(let bodyExpr) = body.first,
      case .variable(_, let bodyPayload) = bodyExpr
    else {
      XCTFail("Expected expression body with variable")
      return
    }
    XCTAssertEqual(bodyPayload, 20, "Body payload should be transformed")
  }

  // MARK: - If-Let Binding Map Tests

  func testMap_ifLetBinding() {
    let stmt: Statement<Int> = .ifLetBinding(
      name: "v",
      type: nil,
      initializer: .variable("opt", payload: 1),
      thenBody: [.returnStatement(.variable("v", payload: 2))],
      elseBody: nil
    )
    let mapped = stmt.map { $0 * 10 }
    guard case .ifLetBinding(_, _, let initializer, _, _) = mapped,
      case .variable(_, let initPayload) = initializer
    else {
      XCTFail("Expected ifLetBinding with variable initializer")
      return
    }
    XCTAssertEqual(initPayload, 10, "Initializer payload should be transformed")
  }

  func testRenderImplicitMember() throws {
    let template: Template<Void> = .implicitMember("get")

    XCTAssertEqual(try Renderer.render(template).description, ".get")
  }

  func testRenderInOutExpression() throws {
    let template: Template<Void> = .inOut(.variable("request", payload: ()))

    XCTAssertEqual(try Renderer.render(template).description, "&request")
  }
}
