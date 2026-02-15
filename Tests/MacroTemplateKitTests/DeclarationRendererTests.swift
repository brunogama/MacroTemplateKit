import XCTest
import SwiftSyntax
@testable import MacroTemplateKit

// swiftlint:disable file_length type_body_length
// Justification: Comprehensive declaration renderer tests covering all 5 Declaration cases
// with multiple test scenarios per case. Tests verify complex SwiftSyntax generation including
// function signatures, property accessors, and nested declarations. Splitting would reduce
// test cohesion and clarity.

/// Tests for Declaration rendering to SwiftSyntax DeclSyntax.
///
/// Verifies that Renderer.render correctly transforms all Declaration cases
/// into valid SwiftSyntax declaration nodes with proper signatures, modifiers,
/// and member structures.
final class DeclarationRendererTests: XCTestCase {

  // MARK: - Function Declaration Tests

  func testRenderFunction_simple() {
    let function = Declaration<Void>.function(
      FunctionSignature(
        name: "greet",
        parameters: [],
        isAsync: false,
        canThrow: false,
        returnType: nil,
        body: [
          .expression(.functionCall(function: "print", arguments: [
            (label: nil, value: .literal(.string("Hello")))
          ]))
        ]
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func greet"), "Should contain function name")
    XCTAssertTrue(description.contains("()"), "Should contain empty parameter list")
    XCTAssertTrue(description.contains("{"), "Should contain opening brace")
    XCTAssertTrue(description.contains("print"), "Should contain body statement")
    XCTAssertTrue(description.contains("}"), "Should contain closing brace")
  }

  func testRenderFunction_withParameters() {
    let function = Declaration<String>.function(
      FunctionSignature(
        name: "add",
        parameters: [
          ParameterSignature(label: nil, name: "a", type: "Int"),
          ParameterSignature(label: nil, name: "b", type: "Int"),
        ],
        returnType: "Int",
        body: [
          .returnStatement(
            .binaryOperation(
              left: .variable("a", payload: "meta1"),
              operator: "+",
              right: .variable("b", payload: "meta2")
            )
          )
        ]
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func add"), "Should contain function name")
    XCTAssertTrue(description.contains("a: Int"), "Should contain first parameter")
    XCTAssertTrue(description.contains("b: Int"), "Should contain second parameter")
    XCTAssertTrue(description.contains("-> Int"), "Should contain return type")
    XCTAssertTrue(description.contains("return a + b"), "Should contain return statement")
  }

  func testRenderFunction_withLabelsAndParameters() {
    let function = Declaration<Int>.function(
      FunctionSignature(
        name: "greet",
        parameters: [
          ParameterSignature(label: "name", name: "userName", type: "String"),
          ParameterSignature(label: "times", name: "count", type: "Int"),
        ],
        body: []
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func greet"), "Should contain function name")
    XCTAssertTrue(description.contains("name userName: String"), "Should contain labeled parameter")
    XCTAssertTrue(description.contains("times count: Int"), "Should contain second labeled parameter")
  }

  func testRenderFunction_async() {
    let function = Declaration<Void>.function(
      FunctionSignature(
        name: "fetchData",
        parameters: [],
        isAsync: true,
        canThrow: false,
        returnType: "Data",
        body: [
          .returnStatement(.variable("data", payload: ()))
        ]
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func fetchData"), "Should contain function name")
    XCTAssertTrue(description.contains("async"), "Should contain async keyword")
    XCTAssertTrue(description.contains("-> Data"), "Should contain return type")
  }

  func testRenderFunction_throws() {
    let function = Declaration<Bool>.function(
      FunctionSignature(
        name: "validate",
        parameters: [
          ParameterSignature(label: nil, name: "input", type: "String")
        ],
        isAsync: false,
        canThrow: true,
        returnType: "Bool",
        body: [
          .guardStatement(
            condition: .binaryOperation(
              left: .propertyAccess(
                base: .variable("input", payload: true),
                property: "isEmpty"
              ),
              operator: "==",
              right: .literal(.boolean(false))
            ),
            elseBody: [
              .throwStatement(.variable("ValidationError", payload: false))
            ]
          ),
          .returnStatement(.literal(.boolean(true))),
        ]
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func validate"), "Should contain function name")
    XCTAssertTrue(description.contains("throws"), "Should contain throws keyword")
    XCTAssertTrue(description.contains("-> Bool"), "Should contain return type")
    XCTAssertTrue(description.contains("guard"), "Should contain guard statement")
    XCTAssertTrue(description.contains("throw"), "Should contain throw statement")
  }

  func testRenderFunction_asyncThrows() {
    let function = Declaration<String>.function(
      FunctionSignature(
        name: "process",
        parameters: [],
        isAsync: true,
        canThrow: true,
        returnType: "Result",
        body: [
          .returnStatement(.variable("result", payload: "meta"))
        ]
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func process"), "Should contain function name")
    XCTAssertTrue(description.contains("async"), "Should contain async keyword")
    XCTAssertTrue(description.contains("throws"), "Should contain throws keyword")
    XCTAssertTrue(description.contains("-> Result"), "Should contain return type")
  }

  func testRenderFunction_inoutParameter() {
    let function = Declaration<Void>.function(
      FunctionSignature(
        name: "swap",
        parameters: [
          ParameterSignature(label: nil, name: "a", type: "Int", isInout: true),
          ParameterSignature(label: nil, name: "b", type: "Int", isInout: true),
        ],
        body: []
      )
    )
    let result = Renderer.render(function)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("func swap"), "Should contain function name")
    XCTAssertTrue(description.contains("inout Int"), "Should contain inout modifier on parameters")
  }

  // MARK: - Property Declaration Tests

  func testRenderProperty_letWithType() {
    let property = Declaration<Int>.property(
      PropertySignature(
        name: "constantValue",
        type: "Int",
        isStatic: false,
        isLet: true,
        initializer: .literal(.integer(42))
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("let constantValue"), "Should contain let property name")
    XCTAssertTrue(description.contains(": Int"), "Should contain type annotation")
    XCTAssertTrue(description.contains("= 42"), "Should contain initializer")
    XCTAssertFalse(description.contains("static"), "Should not contain static modifier")
  }

  func testRenderProperty_varWithoutType() {
    let property = Declaration<Void>.property(
      PropertySignature(
        name: "mutableValue",
        type: nil,
        isStatic: false,
        isLet: false,
        initializer: .literal(.string("default"))
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var mutableValue"), "Should contain var property name")
    XCTAssertTrue(description.contains("= \"default\""), "Should contain initializer")
    XCTAssertFalse(description.contains(":"), "Should not contain type annotation")
  }

  func testRenderProperty_static() {
    let property = Declaration<String>.property(
      PropertySignature(
        name: "shared",
        type: "Instance",
        isStatic: true,
        isLet: true,
        initializer: .functionCall(function: "Instance", arguments: [])
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("static"), "Should contain static modifier")
    XCTAssertTrue(description.contains("let shared"), "Should contain property name")
    XCTAssertTrue(description.contains(": Instance"), "Should contain type annotation")
    XCTAssertTrue(description.contains("Instance()"), "Should contain initializer call")
  }

  func testRenderProperty_withoutInitializer() {
    let property = Declaration<Bool>.property(
      PropertySignature(
        name: "placeholder",
        type: "String?",
        isStatic: false,
        isLet: false,
        initializer: nil
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var placeholder"), "Should contain var property name")
    XCTAssertTrue(description.contains(": String?"), "Should contain type annotation")
    XCTAssertFalse(description.contains("="), "Should not contain initializer")
  }

  // MARK: - Computed Property Tests

  func testRenderComputedProperty_getterOnly() {
    let property = Declaration<Void>.computedProperty(
      ComputedPropertySignature(
        name: "fullName",
        type: "String",
        isStatic: false,
        getter: [
          .returnStatement(
            .binaryOperation(
              left: .variable("firstName", payload: ()),
              operator: "+",
              right: .variable("lastName", payload: ())
            )
          )
        ],
        setter: nil
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var fullName"), "Should contain property name")
    XCTAssertTrue(description.contains(": String"), "Should contain type annotation")
    XCTAssertTrue(description.contains("get"), "Should contain get accessor")
    XCTAssertTrue(description.contains("return firstName + lastName"), "Should contain getter body")
    XCTAssertFalse(description.contains("set"), "Should not contain set accessor")
  }

  func testRenderComputedProperty_getterAndSetter() {
    let property = Declaration<Int>.computedProperty(
      ComputedPropertySignature(
        name: "count",
        type: "Int",
        isStatic: false,
        getter: [
          .returnStatement(.propertyAccess(
            base: .variable("storage", payload: 1),
            property: "count"
          ))
        ],
        setter: SetterSignature(
          parameterName: "newValue",
          body: [
            .expression(.functionCall(function: "updateStorage", arguments: [
              (label: "count", value: .variable("newValue", payload: 2))
            ]))
          ]
        )
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var count"), "Should contain property name")
    XCTAssertTrue(description.contains(": Int"), "Should contain type annotation")
    XCTAssertTrue(description.contains("get"), "Should contain get accessor")
    XCTAssertTrue(description.contains("set"), "Should contain set accessor")
    XCTAssertTrue(description.contains("newValue"), "Should contain setter parameter")
    XCTAssertTrue(description.contains("updateStorage"), "Should contain setter body")
  }

  func testRenderComputedProperty_static() {
    let property = Declaration<String>.computedProperty(
      ComputedPropertySignature(
        name: "className",
        type: "String",
        isStatic: true,
        getter: [
          .returnStatement(.literal(.string("MyClass")))
        ],
        setter: nil
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("static"), "Should contain static modifier")
    XCTAssertTrue(description.contains("var className"), "Should contain property name")
    XCTAssertTrue(description.contains(": String"), "Should contain type annotation")
    XCTAssertTrue(description.contains("get"), "Should contain get accessor")
  }

  func testRenderComputedProperty_customSetterParameter() {
    let property = Declaration<Bool>.computedProperty(
      ComputedPropertySignature(
        name: "isEnabled",
        type: "Bool",
        isStatic: false,
        getter: [
          .returnStatement(.variable("internalFlag", payload: true))
        ],
        setter: SetterSignature(
          parameterName: "enabled",
          body: [
            .varBinding(
              name: "internalFlag",
              type: nil,
              initializer: .variable("enabled", payload: false)
            )
          ]
        )
      )
    )
    let result = Renderer.render(property)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("var isEnabled"), "Should contain property name")
    XCTAssertTrue(description.contains("set(enabled)"), "Should contain custom setter parameter")
    XCTAssertTrue(description.contains("internalFlag = enabled"), "Should contain setter body")
  }

  // MARK: - Extension Declaration Tests

  func testRenderExtension_withoutConformances() {
    let extensionDecl = Declaration<Void>.extensionDecl(
      ExtensionSignature(
        typeName: "MyType",
        conformances: [],
        members: []
      )
    )
    let result = Renderer.render(extensionDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("extension MyType"), "Should contain extension keyword")
    XCTAssertTrue(description.contains("{"), "Should contain opening brace")
    XCTAssertTrue(description.contains("}"), "Should contain closing brace")
    XCTAssertFalse(description.contains(":"), "Should not contain conformance colon")
  }

  func testRenderExtension_withConformances() {
    let extensionDecl = Declaration<Int>.extensionDecl(
      ExtensionSignature(
        typeName: "MyType",
        conformances: ["Equatable", "Hashable"],
        members: []
      )
    )
    let result = Renderer.render(extensionDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("extension MyType"), "Should contain extension keyword")
    XCTAssertTrue(description.contains(":"), "Should contain conformance colon")
    XCTAssertTrue(description.contains("Equatable"), "Should contain first conformance")
    XCTAssertTrue(description.contains("Hashable"), "Should contain second conformance")
  }

  func testRenderExtension_withMembers() {
    let extensionDecl = Declaration<String>.extensionDecl(
      ExtensionSignature(
        typeName: "MyType",
        conformances: ["CustomStringConvertible"],
        members: [
          .property(PropertySignature(
            name: "description",
            type: "String",
            isStatic: false,
            isLet: false,
            initializer: .literal(.string("MyType instance"))
          )),
          .function(FunctionSignature(
            name: "greet",
            parameters: [],
            body: [
              .expression(.functionCall(function: "print", arguments: [
                (label: nil, value: .literal(.string("Hello")))
              ]))
            ]
          )),
        ]
      )
    )
    let result = Renderer.render(extensionDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("extension MyType"), "Should contain extension keyword")
    XCTAssertTrue(description.contains("CustomStringConvertible"), "Should contain conformance")
    XCTAssertTrue(description.contains("var description"), "Should contain property member")
    XCTAssertTrue(description.contains("func greet"), "Should contain function member")
  }

  // MARK: - Struct Declaration Tests

  func testRenderStruct_empty() {
    let structDecl = Declaration<Void>.structDecl(
      StructSignature(
        name: "EmptyStruct",
        conformances: [],
        members: []
      )
    )
    let result = Renderer.render(structDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("struct EmptyStruct"), "Should contain struct keyword")
    XCTAssertTrue(description.contains("{"), "Should contain opening brace")
    XCTAssertTrue(description.contains("}"), "Should contain closing brace")
  }

  func testRenderStruct_withConformances() {
    let structDecl = Declaration<Bool>.structDecl(
      StructSignature(
        name: "Person",
        conformances: ["Codable", "Sendable"],
        members: []
      )
    )
    let result = Renderer.render(structDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("struct Person"), "Should contain struct name")
    XCTAssertTrue(description.contains(":"), "Should contain conformance colon")
    XCTAssertTrue(description.contains("Codable"), "Should contain first conformance")
    XCTAssertTrue(description.contains("Sendable"), "Should contain second conformance")
  }

  func testRenderStruct_withMembers() {
    let structDecl = Declaration<Int>.structDecl(
      StructSignature(
        name: "Point",
        conformances: ["Equatable"],
        members: [
          .property(PropertySignature(
            name: "x",
            type: "Double",
            isStatic: false,
            isLet: true,
            initializer: nil
          )),
          .property(PropertySignature(
            name: "y",
            type: "Double",
            isStatic: false,
            isLet: true,
            initializer: nil
          )),
          .function(FunctionSignature(
            name: "distance",
            parameters: [
              ParameterSignature(label: "to", name: "other", type: "Point")
            ],
            returnType: "Double",
            body: [
              .returnStatement(.literal(.double(0.0)))
            ]
          )),
        ]
      )
    )
    let result = Renderer.render(structDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("struct Point"), "Should contain struct name")
    XCTAssertTrue(description.contains("Equatable"), "Should contain conformance")
    XCTAssertTrue(description.contains("let x: Double"), "Should contain x property")
    XCTAssertTrue(description.contains("let y: Double"), "Should contain y property")
    XCTAssertTrue(description.contains("func distance"), "Should contain function member")
    XCTAssertTrue(description.contains("to other: Point"), "Should contain function parameter")
  }

  // MARK: - Nested Declaration Tests

  func testRenderStruct_withNestedStruct() {
    let structDecl = Declaration<String>.structDecl(
      StructSignature(
        name: "OuterStruct",
        conformances: [],
        members: [
          .structDecl(StructSignature(
            name: "InnerStruct",
            conformances: [],
            members: [
              .property(PropertySignature(
                name: "value",
                type: "Int",
                isStatic: false,
                isLet: true,
                initializer: .literal(.integer(0))
              ))
            ]
          ))
        ]
      )
    )
    let result = Renderer.render(structDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("struct OuterStruct"), "Should contain outer struct")
    XCTAssertTrue(description.contains("struct InnerStruct"), "Should contain nested struct")
    XCTAssertTrue(description.contains("let value: Int"), "Should contain nested property")
  }

  func testRenderExtension_withNestedExtensions() {
    let extensionDecl = Declaration<Void>.extensionDecl(
      ExtensionSignature(
        typeName: "MyType",
        conformances: [],
        members: [
          .extensionDecl(ExtensionSignature(
            typeName: "NestedType",
            conformances: ["Codable"],
            members: []
          ))
        ]
      )
    )
    let result = Renderer.render(extensionDecl)

    let description = result.formatted().description
    XCTAssertTrue(description.contains("extension MyType"), "Should contain outer extension")
    XCTAssertTrue(description.contains("extension NestedType"), "Should contain nested extension")
    XCTAssertTrue(description.contains("Codable"), "Should contain nested conformance")
  }
}
