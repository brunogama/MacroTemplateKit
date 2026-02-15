import MacroTemplateKit
import XCTest

final class TemplateBuilderTests: XCTestCase {

  // MARK: - Result Builder Tests

  func testBuildBlock_singleExpression() {
    @TemplateBuilder<Int> var template: Template<Int> {
      Template.literal(42)
    }
    XCTAssertEqual(template, .literal(.integer(42)))
  }

  func testBuildBlock_multipleExpressions() {
    @TemplateBuilder<Int> var template: Template<Int> {
      Template.literal(1)
      Template.literal(2)
      Template.literal(3)
    }
    XCTAssertEqual(
      template,
      .arrayLiteral([
        .literal(.integer(1)),
        .literal(.integer(2)),
        .literal(.integer(3)),
      ]))
  }

  func testBuildOptional_present() {
    let condition = true
    @TemplateBuilder<Int> var template: Template<Int> {
      if condition {
        Template.literal("present")
      }
    }
    // Should contain the string literal
    XCTAssertNotEqual(template, .literal(.nil))
  }

  func testBuildOptional_absent() {
    let condition = false
    @TemplateBuilder<Int> var template: Template<Int> {
      if condition {
        Template.literal("present")
      }
    }
    XCTAssertEqual(template, .literal(.nil))
  }

  func testBuildEither_first() {
    let useFirst = true
    @TemplateBuilder<Int> var template: Template<Int> {
      if useFirst {
        Template.literal("first")
      } else {
        Template.literal("second")
      }
    }
    XCTAssertEqual(template, .literal(.string("first")))
  }

  func testBuildEither_second() {
    let useFirst = false
    @TemplateBuilder<Int> var template: Template<Int> {
      if useFirst {
        Template.literal("first")
      } else {
        Template.literal("second")
      }
    }
    XCTAssertEqual(template, .literal(.string("second")))
  }

  // MARK: - Fluent Factory Tests

  func testLiteral_integer() {
    let template: Template<Int> = .literal(42)
    XCTAssertEqual(template, .literal(.integer(42)))
  }

  func testLiteral_string() {
    let template: Template<Int> = .literal("hello")
    XCTAssertEqual(template, .literal(.string("hello")))
  }

  func testLiteral_boolean() {
    XCTAssertEqual(Template<Int>.literal(true), .literal(.boolean(true)))
    XCTAssertEqual(Template<Int>.literal(false), .literal(.boolean(false)))
  }

  func testProperty_onTemplate() {
    let template: Template<Int> = .property("name", on: .variable("user", payload: 1))
    XCTAssertEqual(
      template,
      .propertyAccess(
        base: .variable("user", payload: 1),
        property: "name"
      ))
  }

  func testFunction_varargs() {
    let template: Template<Int> = .function("print", .literal("hello"))
    XCTAssertEqual(
      template,
      .functionCall(
        function: "print",
        arguments: [(label: nil, value: .literal(.string("hello")))]
      ))
  }

  func testFunction_withBuilder() {
    let template: Template<Int> = .function("method") {
      Template.literal(1)
      Template.literal(2)
    }
    XCTAssertEqual(
      template,
      .functionCall(
        function: "method",
        arguments: [
          (label: nil, value: .literal(.integer(1))),
          (label: nil, value: .literal(.integer(2))),
        ]
      ))
  }

  func testOperation() {
    let template: Template<Int> = .operation(.literal(1), "+", .literal(2))
    XCTAssertEqual(
      template,
      .binaryOperation(
        left: .literal(.integer(1)),
        operator: "+",
        right: .literal(.integer(2))
      ))
  }

  func testTernary() {
    let template: Template<Int> = .ternary(
      if: .literal(true),
      then: .literal(1),
      else: .literal(0)
    )
    XCTAssertEqual(
      template,
      .conditional(
        condition: .literal(.boolean(true)),
        thenBranch: .literal(.integer(1)),
        elseBranch: .literal(.integer(0))
      ))
  }

  func testArray_varargs() {
    let template: Template<Int> = .array(.literal(1), .literal(2), .literal(3))
    XCTAssertEqual(
      template,
      .arrayLiteral([
        .literal(.integer(1)),
        .literal(.integer(2)),
        .literal(.integer(3)),
      ]))
  }

  // MARK: - Integration Tests

  func testComplexTemplate_httpRequest() {
    // Simulates building: URLRequest(url: baseURL.appendingPathComponent(path))
    let template: Template<Int> = .function(
      "URLRequest",
      arguments: [
        (
          label: "url",
          value: .function("appendingPathComponent") {
            Template.variable("baseURL", payload: 1)
            Template.variable("path", payload: 2)
          }
        )
      ])

    if case .functionCall(let name, let args) = template {
      XCTAssertEqual(name, "URLRequest")
      XCTAssertEqual(args.count, 1)
      XCTAssertEqual(args[0].label, "url")
    } else {
      XCTFail("Expected functionCall")
    }
  }
}
