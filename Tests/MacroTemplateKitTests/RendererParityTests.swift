import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Renders `node` to its raw source-accurate token stream, space-joined.
///
/// Used by `assertTokenParity` to compare two SwiftSyntax nodes structurally
/// via their token text rather than via full-tree equality, so trivia
/// differences (e.g. layout-only whitespace) don't cause false negatives.
func tokenStream(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

/// Asserts that two SwiftSyntax nodes render to the same token stream.
///
/// This is the core parity check used to compare the legacy per-node
/// structural renderer against the future source-emit-then-parse renderer:
/// two syntactically different render pipelines should still produce the
/// same sequence of tokens for the same input.
func assertTokenParity(
  _ reference: some SyntaxProtocol,
  _ candidate: some SyntaxProtocol,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertEqual(tokenStream(reference), tokenStream(candidate), file: file, line: line)
}

/// Corpus of `Template`, `Statement`, and `Declaration` values covering every
/// case of all three enums (per `Sources/MacroTemplateKit/Template.swift`,
/// `Statement.swift`, and `Declaration.swift`, which are the sole authority
/// on case names and associated values).
///
/// This corpus is consumed by the token-parity test suite that validates the
/// new source-emit-then-parse renderer against the existing structural
/// renderer: every entry here must render without error under the current
/// renderer, and (once the new renderer exists) must produce an identical
/// token stream under both renderers.
enum ParityCorpus {
  // Cover EVERY Template case (22 total, including `subscriptCall` which is
  // present in Template.swift but was omitted from the original task-brief
  // sketch — the enum, not the plan prose, is authoritative).
  static let templates: [Template<Void>] = [
    // MARK: Literals
    .literal(.integer(42)),
    .literal(.double(1.5)),
    .literal(.string("he said \"hi\"\nline2")),
    .literal(.boolean(true)),
    .literal(.nil),

    // MARK: Variables
    .variable("newValue"),

    // MARK: Control Flow
    .conditional(condition: .variable("flag"), thenBranch: .literal(.integer(1)), elseBranch: .literal(.integer(2))),
    .loop(variable: "item", collection: .variable("items"), body: .methodCall(base: .variable("item"), method: "run", arguments: [])),

    // MARK: Operations
    .functionCall(function: "print", arguments: [(label: nil, value: .literal(.string("hi")))]),
    .methodCall(base: .variable("date"), method: "timeIntervalSince", arguments: [(label: nil, value: .variable("start"))]),
    .binaryOperation(left: .variable("a"), operator: "+", right: .variable("b")),
    .propertyAccess(base: .variable("user"), property: "name"),

    // MARK: Declarations (expression-position variable declaration)
    .variableDeclaration(name: "x", type: "Int", initializer: .literal(.integer(0))),

    // MARK: Effects
    .tryExpression(.functionCall(function: "load", arguments: [])),
    .awaitExpression(.functionCall(function: "fetch", arguments: [])),

    // MARK: Generic Calls
    .genericCall(function: "SQVField", typeArguments: ["String"], arguments: [(label: nil, value: .literal(.string("name")))]),

    // MARK: Collections
    .arrayLiteral([.literal(.integer(1)), .literal(.integer(2))]),
    .tupleLiteral([.literal(.integer(1)), .literal(.string("a"))]),
    .dictionaryLiteral([(key: .literal(.string("k")), value: .literal(.integer(1)))]),
    .dictionaryLiteral([]),

    // MARK: Access
    .subscriptAccess(base: .variable("array"), index: .literal(.integer(0))),
    .subscriptCall(base: .variable("dict"), arguments: [(label: nil, value: .literal(.string("k"))), (label: "default", value: .literal(.integer(0)))]),

    // MARK: Unwrapping
    .forceUnwrap(.variable("optional")),

    // MARK: String Interpolation
    .stringInterpolation([.text("prefix_"), .expression(.variable("name")), .text("_suffix")]),

    // MARK: Closure
    .closure(params: [], returnType: nil, body: [.expression(.functionCall(function: "doWork", arguments: []))]),
    .closure(params: [("x", "Int")], returnType: "Int", body: [.returnStatement(.variable("x"))]),

    // MARK: Assignment Expression
    .assignment(lhs: .variable("x"), rhs: .literal(.integer(1))),

    // MARK: Self Access
    .selfAccess("MyType"),
  ]

  // Cover EVERY Statement case (14 total).
  static let statements: [Statement<Void>] = [
    .assignmentStatement(lhs: .variable("x"), rhs: .literal(.integer(1))),
    .returnStatement(.variable("x")),
    .breakStatement,
    .deferStatement([.expression(.functionCall(function: "cleanup", arguments: []))]),
    .expression(.functionCall(function: "log", arguments: [])),
    .forInStatement(
      variable: "item",
      collection: .variable("items"),
      body: [.expression(.methodCall(base: .variable("item"), method: "run", arguments: []))]
    ),
    .guardLetBinding(
      name: "value",
      type: nil,
      initializer: .variable("optionalValue"),
      elseBody: [.returnStatement(nil)]
    ),
    .guardStatement(
      condition: .variable("flag"),
      elseBody: [.returnStatement(nil)]
    ),
    .ifLetBinding(
      name: "value",
      type: "Int",
      initializer: .variable("optionalValue"),
      thenBody: [.expression(.functionCall(function: "use", arguments: [(label: nil, value: .variable("value"))]))],
      elseBody: [.expression(.functionCall(function: "fallback", arguments: []))]
    ),
    .ifStatement(
      condition: .variable("flag"),
      thenBody: [.expression(.functionCall(function: "onTrue", arguments: []))],
      elseBody: [.expression(.functionCall(function: "onFalse", arguments: []))]
    ),
    .letBinding(name: "x", type: "Int", initializer: .literal(.integer(1))),
    .switchStatement(
      subject: .variable("value"),
      cases: [
        SwitchCase(pattern: .stringLiteral("hello"), body: [.breakStatement]),
        SwitchCase(pattern: .expression(.literal(.integer(1))), body: [.breakStatement]),
        SwitchCase(pattern: .defaultCase, body: [.breakStatement]),
      ]
    ),
    .throwStatement(.functionCall(function: "MyError", arguments: [])),
    .varBinding(name: "y", type: nil, initializer: .literal(.integer(2))),
  ]

  // Cover EVERY Declaration case (8 total).
  static let declarations: [Declaration<Void>] = [
    .property(
      PropertySignature(
        name: "_storage", type: "[String: Any]", isLet: false,
        initializer: .dictionaryLiteral([]))
    ),
    .computedProperty(
      ComputedPropertySignature(
        name: "isValid",
        type: "Bool",
        getter: [.returnStatement(.literal(.boolean(true)))],
        setter: SetterSignature(
          parameterName: "newValue",
          body: [.assignmentStatement(lhs: .variable("_valid"), rhs: .variable("newValue"))]
        )
      )
    ),
    .enumDecl(
      EnumSignature(
        name: "Direction",
        conformances: ["String", "CaseIterable"],
        cases: [
          EnumCaseSignature(name: "north", rawValue: "north"),
          EnumCaseSignature(name: "point", associatedTypes: ["Int", "Int"]),
        ]
      )
    ),
    .extensionDecl(
      ExtensionSignature(
        typeName: "MyType",
        conformances: ["Equatable"],
        members: [
          .property(PropertySignature(name: "tag", type: "String", initializer: .literal(.string("x"))))
        ]
      )
    ),
    .function(
      FunctionSignature(
        name: "greet",
        parameters: [ParameterSignature(name: "name", type: "String")],
        returnType: "String",
        body: [.returnStatement(.variable("name"))]
      )
    ),
    .initDecl(
      InitializerSignature(
        parameters: [ParameterSignature(name: "value", type: "Int")],
        body: [.assignmentStatement(lhs: .propertyAccess(base: .variable("self"), property: "value"), rhs: .variable("value"))]
      )
    ),
    .structDecl(
      StructSignature(
        name: "Point",
        conformances: ["Equatable"],
        members: [
          .property(PropertySignature(name: "x", type: "Int", isLet: true)),
          .property(PropertySignature(name: "y", type: "Int", isLet: true)),
        ]
      )
    ),
    .typeAlias(
      TypeAliasSignature(name: "StringMap", existingType: "[String: String]")
    ),
  ]
}

final class ParityHarnessTests: XCTestCase {
  func testHarnessDetectsEquality() {
    let node = Renderer.render(Template<Void>.variable("x"))
    assertTokenParity(node, node)
  }

  func testCorpusRendersWithoutErrors() {
    for template in ParityCorpus.templates {
      XCTAssertFalse(Renderer.render(template).hasError, "\(template)")
    }
    for statement in ParityCorpus.statements {
      XCTAssertFalse(Renderer.render(statement).hasError, "\(statement)")
    }
    for declaration in ParityCorpus.declarations {
      XCTAssertFalse(Renderer.render(declaration).hasError, "\(declaration)")
    }
  }
}
