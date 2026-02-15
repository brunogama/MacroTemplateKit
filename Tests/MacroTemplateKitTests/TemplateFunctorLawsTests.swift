import XCTest
@testable import MacroTemplateKit

/// Property-based tests verifying Template<A> satisfies functor laws.
///
/// Functor laws tested:
/// 1. Identity: template.map { $0 } == template
/// 2. Composition: template.map(f).map(g) == template.map { g(f($0)) }
///
/// These laws ensure Template is a lawful functor, guaranteeing:
/// - Structure preservation during mapping
/// - Composability of transformations
/// - Predictable behavior for all template cases
final class TemplateFunctorLawsTests: XCTestCase {

  // MARK: - Functor Law 1: Identity
  // template.map { $0 } == template

  func testFunctorIdentityLaw_literal_integer() {
    let template: Template<Int> = .literal(.integer(42))
    let mapped = template.map { $0 }
    XCTAssertEqual(
      mapped,
      template,
      "Identity law failed: mapping identity function should preserve template"
    )
  }

  func testFunctorIdentityLaw_literal_string() {
    let template: Template<String> = .literal(.string("hello"))
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for string literal")
  }

  func testFunctorIdentityLaw_literal_boolean() {
    let templateTrue: Template<Bool> = .literal(.boolean(true))
    let templateFalse: Template<Bool> = .literal(.boolean(false))
    XCTAssertEqual(templateTrue.map { $0 }, templateTrue, "Identity law failed for true literal")
    XCTAssertEqual(templateFalse.map { $0 }, templateFalse, "Identity law failed for false literal")
  }

  func testFunctorIdentityLaw_literal_nil() {
    let template: Template<Int> = .literal(.nil)
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for nil literal")
  }

  func testFunctorIdentityLaw_variable() {
    let template: Template<String> = .variable("myVar", payload: "metadata")
    let mapped = template.map { $0 }
    XCTAssertEqual(
      mapped,
      template,
      "Identity law failed: variable payload should be preserved by identity function"
    )
  }

  func testFunctorIdentityLaw_conditional() {
    let template: Template<Int> = .conditional(
      condition: .literal(.boolean(true)),
      thenBranch: .variable("x", payload: 1),
      elseBranch: .variable("y", payload: 2)
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(
      mapped,
      template,
      "Identity law failed: nested conditional structure should be preserved"
    )
  }

  func testFunctorIdentityLaw_functionCall() {
    let template: Template<String> = .functionCall(
      function: "print",
      arguments: [
        (label: nil, value: .literal(.string("hello"))),
        (label: "separator", value: .variable("sep", payload: "comma")),
      ]
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(
      mapped,
      template,
      "Identity law failed: function call with multiple arguments should be preserved"
    )
  }

  func testFunctorIdentityLaw_binaryOperation() {
    let template: Template<Int> = .binaryOperation(
      left: .literal(.integer(1)),
      operator: "+",
      right: .literal(.integer(2))
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for binary operation")
  }

  func testFunctorIdentityLaw_propertyAccess() {
    let template: Template<String> = .propertyAccess(
      base: .variable("object", payload: "metadata"),
      property: "property"
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for property access")
  }

  func testFunctorIdentityLaw_arrayLiteral() {
    let template: Template<Int> = .arrayLiteral([
      .literal(.integer(1)),
      .variable("x", payload: 10),
      .literal(.integer(3)),
    ])
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for array literal")
  }

  func testFunctorIdentityLaw_variableDeclaration() {
    let template: Template<String> = .variableDeclaration(
      name: "result",
      type: "Int",
      initializer: .variable("value", payload: "init")
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for variable declaration")
  }

  func testFunctorIdentityLaw_loop() {
    let template: Template<Int> = .loop(
      variable: "item",
      collection: .variable("items", payload: 1),
      body: .variable("item", payload: 2)
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(mapped, template, "Identity law failed for loop")
  }

  func testFunctorIdentityLaw_complexNested() {
    // Test deeply nested structure: conditional containing function call with binary operations
    let template: Template<String> = .conditional(
      condition: .binaryOperation(
        left: .variable("x", payload: "x_meta"),
        operator: ">",
        right: .literal(.integer(0))
      ),
      thenBranch: .functionCall(
        function: "process",
        arguments: [
          (
            label: "value",
            value: .binaryOperation(
              left: .variable("x", payload: "x_meta"),
              operator: "*",
              right: .literal(.integer(2))
            )
          )
        ]
      ),
      elseBranch: .literal(.integer(0))
    )
    let mapped = template.map { $0 }
    XCTAssertEqual(
      mapped,
      template,
      "Identity law failed for deeply nested template structure"
    )
  }

  // MARK: - Functor Law 2: Composition
  // template.map(f).map(g) == template.map { g(f($0)) }

  func testFunctorCompositionLaw_simple() {
    let template: Template<Int> = .variable("x", payload: 10)

    let transform1: (Int) -> String = { "\($0)" }
    let transform2: (String) -> Int = { $0.count }

    let mappedTwice = template.map(transform1).map(transform2)
    let mappedComposed = template.map { transform2(transform1($0)) }

    XCTAssertEqual(
      mappedTwice,
      mappedComposed,
      "Composition law failed: map(f).map(g) should equal map { g(f($0)) }"
    )
  }

  func testFunctorCompositionLaw_nestedTemplate() {
    let template: Template<Int> = .conditional(
      condition: .literal(.boolean(true)),
      thenBranch: .variable("x", payload: 1),
      elseBranch: .variable("y", payload: 2)
    )

    let transform1: (Int) -> String = { "value_\($0)" }
    let transform2: (String) -> Bool = { $0.count > 5 }

    let mappedTwice = template.map(transform1).map(transform2)
    let mappedComposed = template.map { transform2(transform1($0)) }

    XCTAssertEqual(
      mappedTwice,
      mappedComposed,
      "Composition law failed for conditional template"
    )
  }

  func testFunctorCompositionLaw_functionCall() {
    let template: Template<String> = .functionCall(
      function: "print",
      arguments: [
        (label: nil, value: .variable("x", payload: "first")),
        (label: "separator", value: .variable("y", payload: "second")),
      ]
    )

    let transform1: (String) -> Int = { $0.count }
    let transform2: (Int) -> String = { "len_\($0)" }

    let mappedTwice = template.map(transform1).map(transform2)
    let mappedComposed = template.map { transform2(transform1($0)) }

    XCTAssertEqual(
      mappedTwice,
      mappedComposed,
      "Composition law failed for function call template"
    )
  }

  func testFunctorCompositionLaw_arrayLiteral() {
    let template: Template<Int> = .arrayLiteral([
      .variable("a", payload: 1),
      .variable("b", payload: 2),
      .variable("c", payload: 3),
    ])

    let transform1: (Int) -> String = { "item_\($0)" }
    let transform2: (String) -> Int = { $0.count }

    let mappedTwice = template.map(transform1).map(transform2)
    let mappedComposed = template.map { transform2(transform1($0)) }

    XCTAssertEqual(
      mappedTwice,
      mappedComposed,
      "Composition law failed for array literal template"
    )
  }

  // MARK: - Structure Preservation

  func testMapPreservesTemplateStructure() {
    // Verify mapping doesn't change .conditional to .functionCall, etc.
    let conditional: Template<Int> = .conditional(
      condition: .literal(.boolean(true)),
      thenBranch: .variable("x", payload: 1),
      elseBranch: .variable("y", payload: 2)
    )

    let mapped = conditional.map { $0 * 2 }

    // Use pattern matching to verify structure
    guard
      case .conditional(
        condition: .literal(.boolean(true)),
        thenBranch: .variable("x", payload: 2),
        elseBranch: .variable("y", payload: 4)
      ) = mapped
    else {
      XCTFail("Mapping changed template structure from conditional")
      return
    }
  }

  func testMapOnlyAffectsPayload() {
    // Verify literal values unchanged, only variable payloads transformed
    let template: Template<String> = .binaryOperation(
      left: .literal(.integer(10)),  // Should remain unchanged
      operator: "+",  // Should remain unchanged
      right: .variable("x", payload: "original")  // Only payload changes
    )

    let mapped = template.map { $0.uppercased() }

    guard
      case .binaryOperation(
        left: .literal(.integer(10)),
        operator: "+",
        right: .variable("x", payload: "ORIGINAL")
      ) = mapped
    else {
      XCTFail("Mapping affected non-payload data")
      return
    }
  }

  func testMapPreservesLiteralValues() {
    // All literal types should pass through unchanged
    let intLit: Template<Int> = .literal(.integer(42))
    let doubleLit: Template<Int> = .literal(.double(3.14))
    let stringLit: Template<Int> = .literal(.string("hello"))
    let boolLit: Template<Int> = .literal(.boolean(true))
    let nilLit: Template<Int> = .literal(.nil)

    XCTAssertEqual(intLit.map { $0 * 2 }, .literal(.integer(42)))
    XCTAssertEqual(doubleLit.map { $0 * 2 }, .literal(.double(3.14)))
    XCTAssertEqual(stringLit.map { $0 * 2 }, .literal(.string("hello")))
    XCTAssertEqual(boolLit.map { $0 * 2 }, .literal(.boolean(true)))
    XCTAssertEqual(nilLit.map { $0 * 2 }, .literal(.nil))
  }

  func testMapPreservesVariableNames() {
    // Variable names should remain unchanged, only payloads transform
    let template: Template<Int> = .variable("myVariable", payload: 10)
    let mapped = template.map { $0 * 2 }

    guard case .variable("myVariable", payload: 20) = mapped else {
      XCTFail("Mapping changed variable name")
      return
    }
  }

  func testMapPreservesFunctionNames() {
    // Function names should remain unchanged
    let template: Template<Int> = .functionCall(
      function: "myFunction",
      arguments: [(label: "arg", value: .variable("x", payload: 5))]
    )
    let mapped = template.map { $0 * 2 }

    if case .functionCall(let function, let arguments) = mapped {
      XCTAssertEqual(function, "myFunction", "Mapping changed function name")
      XCTAssertEqual(arguments.count, 1, "Mapping changed argument count")
      XCTAssertEqual(arguments[0].label, "arg", "Mapping changed argument label")
      if case .variable("x", payload: 10) = arguments[0].value {
        // Success
      } else {
        XCTFail("Mapping changed argument value incorrectly")
      }
    } else {
      XCTFail("Mapping changed template type from functionCall")
    }
  }

  func testMapPreservesOperators() {
    // Binary operators should remain unchanged
    let template: Template<String> = .binaryOperation(
      left: .variable("x", payload: "a"),
      operator: "&&",
      right: .variable("y", payload: "b")
    )
    let mapped = template.map { $0.uppercased() }

    guard
      case .binaryOperation(
        left: .variable("x", payload: "A"),
        operator: "&&",
        right: .variable("y", payload: "B")
      ) = mapped
    else {
      XCTFail("Mapping changed binary operator")
      return
    }
  }

  func testMapPreservesPropertyNames() {
    // Property names should remain unchanged
    let template: Template<Int> = .propertyAccess(
      base: .variable("object", payload: 1),
      property: "myProperty"
    )
    let mapped = template.map { $0 * 2 }

    guard
      case .propertyAccess(
        base: .variable("object", payload: 2),
        property: "myProperty"
      ) = mapped
    else {
      XCTFail("Mapping changed property name")
      return
    }
  }

  func testMapPreservesLoopStructure() {
    // Loop variable name and collection should remain unchanged
    let template: Template<Int> = .loop(
      variable: "item",
      collection: .variable("items", payload: 1),
      body: .variable("item", payload: 2)
    )
    let mapped = template.map { $0 * 10 }

    guard
      case .loop(
        variable: "item",
        collection: .variable("items", payload: 10),
        body: .variable("item", payload: 20)
      ) = mapped
    else {
      XCTFail("Mapping changed loop structure")
      return
    }
  }

  func testMapPreservesDeclarationStructure() {
    // Variable name and type should remain unchanged
    let template: Template<String> = .variableDeclaration(
      name: "myVar",
      type: "Int",
      initializer: .variable("value", payload: "init")
    )
    let mapped = template.map { $0.uppercased() }

    guard
      case .variableDeclaration(
        name: "myVar",
        type: "Int",
        initializer: .variable("value", payload: "INIT")
      ) = mapped
    else {
      XCTFail("Mapping changed variable declaration structure")
      return
    }
  }
}
