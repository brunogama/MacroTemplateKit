import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Renders `node` to its raw source-accurate token stream, space-joined.
///
/// Compares nodes by token text rather than full-tree equality, so trivia
/// differences (e.g. layout-only whitespace) don't cause false negatives.
func tokenStream(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

/// Corpus of `Template`, `Statement`, and `Declaration` values covering every
/// case of all three enums (per `Sources/MacroTemplateKit/Template.swift`,
/// `Statement.swift`, and `Declaration.swift`, which are the sole authority
/// on case names and associated values).
///
/// This corpus is consumed by `GoldenStreamTests`: every entry must render
/// without error, and must produce the token stream recorded there.
enum ParityCorpus {
  enum TemplateCase: CaseIterable, Hashable {
    case literal
    case variable
    case conditional
    case loop
    case functionCall
    case methodCall
    case binaryOperation
    case propertyAccess
    case implicitMember
    case variableDeclaration
    case tryExpression
    case awaitExpression
    case inOut
    case genericCall
    case arrayLiteral
    case tupleLiteral
    case dictionaryLiteral
    case subscriptAccess
    case subscriptCall
    case forceUnwrap
    case syntax
    case cast
    case stringInterpolation
    case closure
    case assignment
    case selfAccess
  }

  enum StatementCase: CaseIterable, Hashable {
    case letBinding
    case varBinding
    case guardStatement
    case ifStatement
    case forInStatement
    case ifLetBinding
    case returnStatement
    case throwStatement
    case deferStatement
    case expression
    case guardLetBinding
    case switchStatement
    case assignmentStatement
    case guardCase
    case ifCase
    case breakStatement
  }

  static func templateCase(of template: Template<Void>) -> TemplateCase {
    switch template {
    case .literal: .literal
    case .variable: .variable
    case .conditional: .conditional
    case .loop: .loop
    case .functionCall: .functionCall
    case .methodCall: .methodCall
    case .binaryOperation: .binaryOperation
    case .propertyAccess: .propertyAccess
    case .implicitMember: .implicitMember
    case .variableDeclaration: .variableDeclaration
    case .tryExpression: .tryExpression
    case .awaitExpression: .awaitExpression
    case .inOut: .inOut
    case .genericCall: .genericCall
    case .arrayLiteral: .arrayLiteral
    case .tupleLiteral: .tupleLiteral
    case .dictionaryLiteral: .dictionaryLiteral
    case .subscriptAccess: .subscriptAccess
    case .subscriptCall: .subscriptCall
    case .forceUnwrap: .forceUnwrap
    case .syntax: .syntax
    case .cast: .cast
    case .stringInterpolation: .stringInterpolation
    case .closure: .closure
    case .assignment: .assignment
    case .selfAccess: .selfAccess
    }
  }

  static func statementCase(of statement: Statement<Void>) -> StatementCase {
    switch statement {
    case .letBinding: .letBinding
    case .varBinding: .varBinding
    case .guardStatement: .guardStatement
    case .ifStatement: .ifStatement
    case .forInStatement: .forInStatement
    case .ifLetBinding: .ifLetBinding
    case .returnStatement: .returnStatement
    case .throwStatement: .throwStatement
    case .deferStatement: .deferStatement
    case .expression: .expression
    case .guardLetBinding: .guardLetBinding
    case .switchStatement: .switchStatement
    case .assignmentStatement: .assignmentStatement
    case .guardCase: .guardCase
    case .ifCase: .ifCase
    case .breakStatement: .breakStatement
    }
  }

  /// Cover every Template case. The exhaustive classifier above makes additions
  /// to `Template` a compile-time prompt to update this corpus.
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

    .conditional(
      condition: .variable("flag"), thenBranch: .literal(.integer(1)),
      elseBranch: .literal(.integer(2))
    ),
    .loop(
      variable: "item", collection: .variable("items"),
      body: .methodCall(base: .variable("item"), method: "run", arguments: [])
    ),

    // MARK: Operations

    .functionCall(function: "print", arguments: [(label: nil, value: .literal(.string("hi")))]),
    .methodCall(
      base: .variable("date"), method: "timeIntervalSince",
      arguments: [(label: nil, value: .variable("start"))]
    ),
    .binaryOperation(left: .variable("a"), operator: "+", right: .variable("b")),
    .propertyAccess(base: .variable("user"), property: "name"),

    // MARK: Declarations (expression-position variable declaration)

    .variableDeclaration(name: "x", type: "Int", initializer: .literal(.integer(0))),

    // MARK: Effects

    .tryExpression(.functionCall(function: "load", arguments: [])),
    .awaitExpression(.functionCall(function: "fetch", arguments: [])),

    // MARK: Generic Calls

    .genericCall(
      function: "SQVField", typeArguments: ["String"],
      arguments: [(label: nil, value: .literal(.string("name")))]
    ),

    // MARK: Collections

    .arrayLiteral([.literal(.integer(1)), .literal(.integer(2))]),
    .tupleLiteral([.literal(.integer(1)), .literal(.string("a"))]),
    .dictionaryLiteral([(key: .literal(.string("k")), value: .literal(.integer(1)))]),
    .dictionaryLiteral([]),

    // MARK: Access

    .subscriptAccess(base: .variable("array"), index: .literal(.integer(0))),
    .subscriptCall(
      base: .variable("dict"),
      arguments: [
        (label: nil, value: .literal(.string("k"))),
        (label: "default", value: .literal(.integer(0))),
      ]
    ),

    // MARK: Unwrapping

    .forceUnwrap(.variable("optional")),

    // MARK: String Interpolation

    .stringInterpolation([.text("prefix_"), .expression(.variable("name")), .text("_suffix")]),
    // Mixes interpolation with a `.text` segment containing an escaped
    // `\n`, to confirm `mightNeedSegmentMerge`'s spelling-based scan (not
    // location-based) still correctly triggers `StringSegmentMerger` when
    // the escape sequence originates from raw interpolation text rather
    // than from `LiteralValue.string` escaping.
    .stringInterpolation([
      .text("line1\\nline2_"), .expression(.variable("name")), .text("_line3\\nline4"),
    ]),

    // MARK: Closure

    .closure(
      params: [], returnType: nil,
      body: [.expression(.functionCall(function: "doWork", arguments: []))]
    ),
    .closure(params: [("x", "Int")], returnType: "Int", body: [.returnStatement(.variable("x"))]),

    // MARK: Assignment Expression

    .assignment(lhs: .variable("x"), rhs: .literal(.integer(1))),

    // MARK: Self Access

    .selfAccess("MyType"),

    // MARK: Nested combinations (precedence-sensitive cases)

    // .binaryOperation nested inside .conditional's condition.
    .conditional(
      condition: .binaryOperation(left: .variable("a"), operator: "<", right: .variable("b")),
      thenBranch: .literal(.integer(1)),
      elseBranch: .literal(.integer(2))
    ),
    // .methodCall whose base is another .methodCall.
    .methodCall(
      base: .methodCall(
        base: .variable("date"), method: "addingTimeInterval",
        arguments: [(label: nil, value: .literal(.double(1.0)))]
      ),
      method: "timeIntervalSince",
      arguments: [(label: nil, value: .variable("start"))]
    ),

    // MARK: SwiftSyntax Interop and Casting

    .syntax(ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("embedded")))),
    .cast(.variable("value"), type: "String", kind: .conditional),
    .implicitMember("get"),
    .inOut(.variable("request")),
  ]

  /// Cover every Statement case. The exhaustive classifier above makes additions
  /// to `Statement` a compile-time prompt to update this corpus.
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
      thenBody: [
        .expression(
          .functionCall(function: "use", arguments: [(label: nil, value: .variable("value"))])
        )
      ],
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
    .guardCase(
      pattern: .value(.literal(.integer(200))),
      value: .variable("status"),
      elseBody: [.returnStatement(nil)]
    ),
    .ifCase(
      pattern: .value(.literal(.integer(201))),
      value: .variable("status"),
      thenBody: [.breakStatement],
      elseBody: [.breakStatement]
    ),
  ]

  /// Cover EVERY Declaration case (8 total).
  static let declarations: [Declaration<Void>] = [
    .property(
      PropertySignature(
        name: "_storage", type: "[String: Any]", isLet: false,
        initializer: .dictionaryLiteral([])
      )
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
          .property(
            PropertySignature(name: "tag", type: "String", initializer: .literal(.string("x")))
          )
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
        body: [
          .assignmentStatement(
            lhs: .propertyAccess(base: .variable("self"), property: "value"),
            rhs: .variable("value")
          )
        ]
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

    // MARK: Attributes (declaration-level attribute, plus a parameter-level

    // attribute exercised through FunctionSignature.parameters) — easy to
    // miss since every case above uses the empty-attributes default.
    .function(
      FunctionSignature(
        attributes: [.mainActor],
        isStatic: true,
        name: "run",
        parameters: [
          ParameterSignature(
            label: "with", name: "handler", type: "() -> Void", attributes: [.escaping]
          )
        ],
        isAsync: true,
        canThrow: true,
        body: [.expression(.functionCall(function: "handler", arguments: []))]
      )
    ),

    // MARK: Generic constraints (SignatureSupport.swift's

    // GenericParameterSignature/WhereRequirement) — a generic parameter with
    // a constraint, a parameter pack with no constraint, and a `where`
    // clause exercising both `WhereRequirement.Relation` cases.
    .structDecl(
      StructSignature(
        name: "Box",
        genericParameters: [
          GenericParameterSignature(name: "Element", constraint: "Equatable"),
          GenericParameterSignature(name: "Wrapped", isParameterPack: true),
        ],
        conformances: ["Equatable"],
        whereRequirements: [
          .conformance("Element", "Hashable"),
          .sameType("Wrapped", "Element"),
        ],
        members: [
          .property(PropertySignature(name: "value", type: "Element", isLet: true))
        ]
      )
    ),
  ]
}
