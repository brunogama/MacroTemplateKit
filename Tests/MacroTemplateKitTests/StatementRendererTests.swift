import XCTest
import SwiftSyntax
@testable import MacroTemplateKit

/// Tests for Statement rendering to SwiftSyntax CodeBlockItemSyntax.
///
/// Verifies that Renderer.render correctly transforms all Statement cases
/// into valid SwiftSyntax statement nodes with proper structure and formatting.
final class StatementRendererTests: XCTestCase {

  // MARK: - Let Binding Tests

  func testRenderLetBinding_withoutType() {
    let statement: Statement<Void> = .letBinding(
      name: "result",
      type: nil,
      initializer: .literal(.integer(42))
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("let result"), "Should contain let binding")
    XCTAssertTrue(description.contains("= 42"), "Should contain initializer value")
    XCTAssertFalse(description.contains(":"), "Should not contain type annotation")
  }

  func testRenderLetBinding_withType() {
    let statement: Statement<String> = .letBinding(
      name: "value",
      type: "Int",
      initializer: .literal(.integer(100))
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("let value"), "Should contain let binding with name")
    XCTAssertTrue(description.contains(": Int"), "Should contain type annotation")
    XCTAssertTrue(description.contains("= 100"), "Should contain initializer value")
  }

  func testRenderLetBinding_complexInitializer() {
    let statement: Statement<Int> = .letBinding(
      name: "sum",
      type: "Int",
      initializer: .binaryOperation(
        left: .variable("a", payload: 1),
        operator: "+",
        right: .variable("b", payload: 2)
      )
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("let sum"), "Should contain let binding")
    XCTAssertTrue(description.contains(": Int"), "Should contain type annotation")
    XCTAssertTrue(description.contains("a + b"), "Should contain binary operation")
  }

  // MARK: - Var Binding Tests

  func testRenderVarBinding_withoutType() {
    let statement: Statement<Void> = .varBinding(
      name: "counter",
      type: nil,
      initializer: .literal(.integer(0))
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var counter"), "Should contain var binding")
    XCTAssertTrue(description.contains("= 0"), "Should contain initializer value")
    XCTAssertFalse(description.contains(":"), "Should not contain type annotation")
  }

  func testRenderVarBinding_withType() {
    let statement: Statement<Bool> = .varBinding(
      name: "isActive",
      type: "Bool",
      initializer: .literal(.boolean(true))
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var isActive"), "Should contain var binding with name")
    XCTAssertTrue(description.contains(": Bool"), "Should contain type annotation")
    XCTAssertTrue(description.contains("= true"), "Should contain initializer value")
  }

  // MARK: - Guard Statement Tests

  func testRenderGuardStatement_simpleCondition() {
    let statement: Statement<Void> = .guardStatement(
      condition: .variable("isValid", payload: ()),
      elseBody: [.returnStatement(nil)]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("guard"), "Should contain guard keyword")
    XCTAssertTrue(description.contains("isValid"), "Should contain condition")
    XCTAssertTrue(description.contains("else"), "Should contain else keyword")
    XCTAssertTrue(description.contains("return"), "Should contain return in else body")
  }

  func testRenderGuardStatement_complexElseBody() {
    let statement: Statement<String> = .guardStatement(
      condition: .binaryOperation(
        left: .variable("count", payload: "meta"),
        operator: ">",
        right: .literal(.integer(0))
      ),
      elseBody: [
        .expression(.functionCall(function: "print", arguments: [
          (label: nil, value: .literal(.string("Error")))
        ])),
        .returnStatement(.literal(.nil)),
      ]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("guard"), "Should contain guard keyword")
    XCTAssertTrue(description.contains("count > 0"), "Should contain condition")
    XCTAssertTrue(description.contains("print"), "Should contain print call in else body")
    XCTAssertTrue(description.contains("return nil"), "Should contain return statement")
  }

  // MARK: - If Statement Tests

  func testRenderIfStatement_withoutElse() {
    let statement: Statement<Int> = .ifStatement(
      condition: .variable("shouldPrint", payload: 1),
      thenBody: [
        .expression(.functionCall(function: "print", arguments: [
          (label: nil, value: .literal(.string("true")))
        ]))
      ],
      elseBody: nil
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("if"), "Should contain if keyword")
    XCTAssertTrue(description.contains("shouldPrint"), "Should contain condition")
    XCTAssertTrue(description.contains("print"), "Should contain print call")
    XCTAssertFalse(description.contains("else"), "Should not contain else keyword")
  }

  func testRenderIfStatement_withElse() {
    let statement: Statement<Void> = .ifStatement(
      condition: .binaryOperation(
        left: .variable("x", payload: ()),
        operator: ">",
        right: .literal(.integer(0))
      ),
      thenBody: [
        .returnStatement(.literal(.integer(1)))
      ],
      elseBody: [
        .returnStatement(.literal(.integer(-1)))
      ]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("if"), "Should contain if keyword")
    XCTAssertTrue(description.contains("x > 0"), "Should contain condition")
    XCTAssertTrue(description.contains("else"), "Should contain else keyword")
    XCTAssertTrue(description.contains("return 1"), "Should contain then return")
    XCTAssertTrue(description.contains("return -1"), "Should contain else return")
  }

  func testRenderIfStatement_multipleStatementsInBranches() {
    let statement: Statement<String> = .ifStatement(
      condition: .literal(.boolean(true)),
      thenBody: [
        .letBinding(name: "temp", type: nil, initializer: .literal(.integer(1))),
        .expression(.functionCall(function: "process", arguments: [
          (label: nil, value: .variable("temp", payload: "meta"))
        ])),
      ],
      elseBody: [
        .letBinding(name: "other", type: nil, initializer: .literal(.integer(2))),
        .returnStatement(.variable("other", payload: "meta")),
      ]
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("if"), "Should contain if keyword")
    XCTAssertTrue(description.contains("let temp"), "Should contain let binding in then")
    XCTAssertTrue(description.contains("process"), "Should contain process call in then")
    XCTAssertTrue(description.contains("let other"), "Should contain let binding in else")
    XCTAssertTrue(description.contains("return other"), "Should contain return in else")
  }

  // MARK: - Return Statement Tests

  func testRenderReturnStatement_withoutExpression() {
    let statement: Statement<Void> = .returnStatement(nil)
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertEqual(description, "return", "Should render as bare return statement")
  }

  func testRenderReturnStatement_withLiteral() {
    let statement: Statement<Int> = .returnStatement(.literal(.integer(42)))
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("return"), "Should contain return keyword")
    XCTAssertTrue(description.contains("42"), "Should contain return value")
  }

  func testRenderReturnStatement_withComplexExpression() {
    let statement: Statement<String> = .returnStatement(
      .binaryOperation(
        left: .variable("x", payload: "meta"),
        operator: "*",
        right: .literal(.integer(2))
      )
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("return"), "Should contain return keyword")
    XCTAssertTrue(description.contains("x * 2"), "Should contain expression")
  }

  // MARK: - Throw Statement Tests

  func testRenderThrowStatement_simpleLiteral() {
    let statement: Statement<Void> = .throwStatement(
      .variable("error", payload: ())
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("throw"), "Should contain throw keyword")
    XCTAssertTrue(description.contains("error"), "Should contain error variable")
  }

  func testRenderThrowStatement_functionCall() {
    let statement: Statement<String> = .throwStatement(
      .functionCall(function: "MyError", arguments: [
        (label: "message", value: .literal(.string("Something failed")))
      ])
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("throw"), "Should contain throw keyword")
    XCTAssertTrue(description.contains("MyError"), "Should contain error type")
    XCTAssertTrue(description.contains("message"), "Should contain argument label")
    XCTAssertTrue(description.contains("Something failed"), "Should contain message")
  }

  // MARK: - Expression Statement Tests

  func testRenderExpressionStatement_functionCall() {
    let statement: Statement<Void> = .expression(
      .functionCall(function: "print", arguments: [
        (label: nil, value: .literal(.string("hello")))
      ])
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("print"), "Should contain function call")
    XCTAssertTrue(description.contains("hello"), "Should contain argument")
  }

  func testRenderExpressionStatement_propertyAccess() {
    let statement: Statement<Int> = .expression(
      .propertyAccess(
        base: .variable("object", payload: 1),
        property: "method"
      )
    )
    let result = Renderer.render(statement)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("object"), "Should contain base object")
    XCTAssertTrue(description.contains(".method"), "Should contain property access")
  }

  // MARK: - Multiple Statements Rendering

  func testRenderStatements_multipleStatements() {
    let statements: [Statement<String>] = [
      .letBinding(name: "x", type: "Int", initializer: .literal(.integer(1))),
      .letBinding(name: "y", type: "Int", initializer: .literal(.integer(2))),
      .returnStatement(
        .binaryOperation(
          left: .variable("x", payload: "meta1"),
          operator: "+",
          right: .variable("y", payload: "meta2")
        )
      ),
    ]
    let result = Renderer.renderStatements(statements)

    XCTAssertEqual(result.count, 3, "Should render all 3 statements")

    let fullDescription = result.formatted().description
    XCTAssertTrue(fullDescription.contains("let x: Int = 1"), "Should contain first binding")
    XCTAssertTrue(fullDescription.contains("let y: Int = 2"), "Should contain second binding")
    XCTAssertTrue(fullDescription.contains("return x + y"), "Should contain return statement")
  }

  func testRenderStatements_emptyArray() {
    let statements: [Statement<Void>] = []
    let result = Renderer.renderStatements(statements)

    XCTAssertTrue(result.isEmpty, "Should render empty list for empty array")
  }

  func testRenderStatements_mixedStatementTypes() {
    let statements: [Statement<Int>] = [
      .guardStatement(
        condition: .variable("isValid", payload: 1),
        elseBody: [.returnStatement(nil)]
      ),
      .ifStatement(
        condition: .literal(.boolean(true)),
        thenBody: [
          .expression(.functionCall(function: "doSomething", arguments: []))
        ],
        elseBody: nil
      ),
      .varBinding(name: "result", type: "Int", initializer: .literal(.integer(0))),
      .throwStatement(.variable("error", payload: 2)),
    ]
    let result = Renderer.renderStatements(statements)

    XCTAssertEqual(result.count, 4, "Should render all 4 statements")

    let fullDescription = result.formatted().description
    XCTAssertTrue(fullDescription.contains("guard"), "Should contain guard statement")
    XCTAssertTrue(fullDescription.contains("if"), "Should contain if statement")
    XCTAssertTrue(fullDescription.contains("var result"), "Should contain var binding")
    XCTAssertTrue(fullDescription.contains("throw"), "Should contain throw statement")
  }
}
