// MARK: - OptionSetMacro (MemberMacro role) using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax
//   Examples/Sources/MacroExamples/Implementation/ComplexMacros/OptionSetMacro.swift
//
// The MemberMacro role of OptionSetMacro generates the stored members required
// to satisfy the OptionSet protocol:
//   - var rawValue: RawValue
//   - init() { self.rawValue = 0 }
//   - init(rawValue: RawValue) { self.rawValue = rawValue }
//   - static let <caseName>: Self = Self(rawValue: 1 << Options.<caseName>.rawValue)
//     (one per case in the nested Options enum)
//
// Note: `typealias RawValue = <RawType>` is not yet expressible through
// MacroTemplateKit's Declaration algebra; it is emitted via SwiftSyntax directly
// and noted below.
//
// Attached-macro declaration (user-facing):
//   @OptionSet<UInt8>
//   struct ShippingOptions {
//     private enum Options: Int {
//       case nextDay, secondDay, priority, standard
//     }
//   }

import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// extension OptionSetMacro: MemberMacro {
//   public static func expansion(...) throws -> [DeclSyntax] {
//     guard let (_, optionsEnum, rawType) = decodeExpansion(...) else { return [] }
//
//     let caseElements: [EnumCaseElementSyntax] = optionsEnum.memberBlock.members.flatMap { ... }
//     let access = decl.modifiers.first(where: \.isNeededAccessLevelModifier)
//
//     let staticVars = caseElements.map { element -> DeclSyntax in
//       // Multi-line string interpolation: mistakes produce runtime crashes, not
//       // compiler errors; the `<<` operator and member paths are untyped strings.
//       """
//       \(access) static let \(element.name): Self =
//         Self(rawValue: 1 << \(optionsEnum.name).\(element.name).rawValue)
//       """
//     }
//
//     return [
//       "\(access)typealias RawValue = \(rawType)",
//       "\(access)var rawValue: RawValue",
//       "\(access)init() { self.rawValue = 0 }",
//       "\(access)init(rawValue: RawValue) { self.rawValue = rawValue }",
//     ] + staticVars
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Generates the stored members required to satisfy the `OptionSet` protocol.
///
/// The MemberMacro role of `@OptionSet<RawType>` produces:
/// ```swift
/// typealias RawValue = UInt8       // emitted via SwiftSyntax (no MTK TypeAlias case yet)
/// var rawValue: RawValue
/// init() { self.rawValue = 0 }
/// init(rawValue: RawValue) { self.rawValue = rawValue }
/// static let nextDay: Self = Self(rawValue: 1 << Options.nextDay.rawValue)
/// // ... one per case in Options
/// ```
///
/// MacroTemplateKit approach:
/// - `Template<Void>` is used throughout (payload `()` satisfies every `Template<A>` site
///   without requiring a concrete data type).
/// - `PropertySignature` models the `rawValue` stored property and each static option.
/// - `InitializerSignature` models both `init()` and `init(rawValue:)`.
/// - The RHS of each static option is composed from nested `.binaryOperation` /
///   `.propertyAccess` / `.functionCall` templates — fully typed and structurally correct.
/// - `Renderer.render(_:)` converts each `Declaration<Void>` to `DeclSyntax`.
///
/// Template structure for a static option's RHS:
/// ```
/// .functionCall("Self", [(rawValue:
///   .binaryOperation(
///     left:     .literal(1),
///     operator: "<<",
///     right:    .propertyAccess(
///                 base:     .propertyAccess(base: .variable("Options"), property: caseName),
///                 property: "rawValue"
///               )
///   )
/// )])
/// ```
public enum OptionSetMemberMacro: MemberMacro {

  // MARK: - Constants

  /// Label for the `optionsName:` macro argument.
  private static let optionsEnumNameLabel = "optionsName"

  /// Default name for the nested options enum.
  private static let defaultOptionsEnumName = "Options"

  // MARK: - MemberMacro

  public static func expansion(
    of attribute: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: declaration,
          message: OptionSetMemberDiagnostic.requiresStruct
        )
      )
      return []
    }

    let optionsEnumName = resolveOptionsEnumName(from: attribute)

    guard let optionsEnum = findOptionsEnum(named: optionsEnumName, in: structDecl) else {
      context.diagnose(
        Diagnostic(
          node: declaration,
          message: OptionSetMemberDiagnostic.requiresOptionsEnum(optionsEnumName)
        )
      )
      return []
    }

    guard let rawTypeName = resolveRawTypeName(from: attribute) else {
      context.diagnose(
        Diagnostic(
          node: attribute,
          message: OptionSetMemberDiagnostic.requiresRawType
        )
      )
      return []
    }

    let accessLevel = resolveAccessLevel(from: structDecl)
    let caseNames = extractCaseNames(from: optionsEnum)

    // The `typealias RawValue` declaration has no MacroTemplateKit case yet.
    // Emit it directly via SwiftSyntax so the rest of the generated code works.
    let typeAliasDecl = makeTypeAliasDecl(
      accessLevel: accessLevel,
      rawTypeName: rawTypeName
    )

    let memberDeclarations = buildMemberDeclarations(
      accessLevel: accessLevel,
      optionsEnumName: optionsEnumName,
      caseNames: caseNames
    )

    let renderedMembers = memberDeclarations.map { Renderer.render($0) }
    return [typeAliasDecl] + renderedMembers
  }

  // MARK: - Private: Argument Decoding

  /// Reads the optional `optionsName:` argument from the attribute, falling back to
  /// `defaultOptionsEnumName` when the argument is absent.
  private static func resolveOptionsEnumName(from attribute: AttributeSyntax) -> String {
    guard case let .argumentList(arguments) = attribute.arguments,
      let nameArg = arguments.first(where: { $0.label?.text == optionsEnumNameLabel }),
      let stringLiteral = nameArg.expression.as(StringLiteralExprSyntax.self),
      let firstSegment = stringLiteral.segments.first,
      case let .stringSegment(segment) = firstSegment
    else {
      return defaultOptionsEnumName
    }
    return segment.content.text
  }

  /// Extracts the raw type name string from `@OptionSet<RawType>`.
  private static func resolveRawTypeName(from attribute: AttributeSyntax) -> String? {
    guard
      let genericArgs = attribute.attributeName.as(IdentifierTypeSyntax.self)?
        .genericArgumentClause,
      let firstArg = genericArgs.arguments.first
    else {
      return nil
    }
    return firstArg.trimmedDescription
  }

  // MARK: - Private: Struct Inspection

  /// Finds the nested enum with `name` inside `structDecl`.
  private static func findOptionsEnum(
    named name: String,
    in structDecl: StructDeclSyntax
  ) -> EnumDeclSyntax? {
    structDecl.memberBlock.members
      .compactMap { $0.decl.as(EnumDeclSyntax.self) }
      .first { $0.name.text == name }
  }

  /// Resolves the access level of the struct as an `AccessLevel`.
  private static func resolveAccessLevel(from structDecl: StructDeclSyntax) -> AccessLevel {
    guard let modifier = structDecl.modifiers.first(where: \.isNeededAccessLevelModifier) else {
      return .internal
    }
    switch modifier.name.tokenKind {
    case .keyword(.public):       return .public
    case .keyword(.private):      return .private
    case .keyword(.fileprivate):  return .fileprivate
    default:                      return .internal
    }
  }

  /// Collects all case element names from an `EnumDeclSyntax`.
  private static func extractCaseNames(from enumDecl: EnumDeclSyntax) -> [String] {
    enumDecl.memberBlock.members
      .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
      .flatMap { $0.elements }
      .map { $0.name.text }
  }

  // MARK: - Private: SwiftSyntax fallback for TypeAlias

  /// Emits `typealias RawValue = <rawTypeName>` directly via SwiftSyntax.
  ///
  /// MacroTemplateKit's `Declaration` algebra does not yet include a `.typeAlias` case.
  /// Rather than using string interpolation, we construct the `TypeAliasDeclSyntax` node
  /// by hand — which is structurally safe and gives us the same guarantees as the
  /// template approach.
  private static func makeTypeAliasDecl(
    accessLevel: AccessLevel,
    rawTypeName: String
  ) -> DeclSyntax {
    var modifiers: [DeclModifierSyntax] = []
    if let keyword = accessLevel.keyword {
      modifiers.append(DeclModifierSyntax(name: .keyword(keyword)))
    }
    let aliasDecl = TypeAliasDeclSyntax(
      modifiers: DeclModifierListSyntax(modifiers),
      name: .identifier("RawValue"),
      initializer: TypeInitializerClauseSyntax(
        value: TypeSyntax(stringLiteral: rawTypeName)
      )
    )
    return DeclSyntax(aliasDecl)
  }

  // MARK: - Private: Declaration Building

  /// Assembles the `Declaration<Void>` values required by `OptionSet` (excluding typealias).
  ///
  /// `Void` (i.e., `()`) is the payload type for every `Template<Void>` — it carries
  /// no semantic metadata but satisfies the generic constraint without requiring a
  /// fabricated value of an uninhabited type.
  private static func buildMemberDeclarations(
    accessLevel: AccessLevel,
    optionsEnumName: String,
    caseNames: [String]
  ) -> [Declaration<Void>] {
    var declarations: [Declaration<Void>] = [
      makeRawValueProperty(accessLevel: accessLevel),
      makeDefaultInit(accessLevel: accessLevel),
      makeRawValueInit(accessLevel: accessLevel),
    ]
    let staticOptions = caseNames.map { caseName in
      makeStaticOption(
        accessLevel: accessLevel,
        caseName: caseName,
        optionsEnumName: optionsEnumName
      )
    }
    declarations.append(contentsOf: staticOptions)
    return declarations
  }

  /// `var rawValue: RawValue`
  private static func makeRawValueProperty(accessLevel: AccessLevel) -> Declaration<Void> {
    .property(
      PropertySignature(
        accessLevel: accessLevel,
        name: "rawValue",
        type: "RawValue",
        isStatic: false,
        isLet: false,
        initializer: nil
      )
    )
  }

  /// `init() { self.rawValue = 0 }`
  private static func makeDefaultInit(accessLevel: AccessLevel) -> Declaration<Void> {
    let body: [Statement<Void>] = [
      .assignmentStatement(
        lhs: .propertyAccess(base: .variable("self", payload: ()), property: "rawValue"),
        rhs: .literal(.integer(0))
      )
    ]
    return .initDecl(
      InitializerSignature(
        accessLevel: accessLevel,
        isFailable: false,
        parameters: [],
        canThrow: false,
        body: body
      )
    )
  }

  /// `init(rawValue: RawValue) { self.rawValue = rawValue }`
  private static func makeRawValueInit(accessLevel: AccessLevel) -> Declaration<Void> {
    let body: [Statement<Void>] = [
      .assignmentStatement(
        lhs: .propertyAccess(base: .variable("self", payload: ()), property: "rawValue"),
        rhs: .variable("rawValue", payload: ())
      )
    ]
    return .initDecl(
      InitializerSignature(
        accessLevel: accessLevel,
        isFailable: false,
        parameters: [
          ParameterSignature(label: "rawValue", name: "rawValue", type: "RawValue")
        ],
        canThrow: false,
        body: body
      )
    )
  }

  /// `static let caseName: Self = Self(rawValue: 1 << Options.caseName.rawValue)`
  ///
  /// Template tree for the initializer argument:
  /// ```
  /// .binaryOperation(
  ///   left:     .literal(1),
  ///   operator: "<<",
  ///   right:    .propertyAccess(
  ///               base:     .propertyAccess(
  ///                           base:     .variable("Options", payload: ()),
  ///                           property: caseName
  ///                         ),
  ///               property: "rawValue"
  ///             )
  /// )
  /// ```
  private static func makeStaticOption(
    accessLevel: AccessLevel,
    caseName: String,
    optionsEnumName: String
  ) -> Declaration<Void> {
    // Options.caseName
    let enumMemberAccess: Template<Void> = .propertyAccess(
      base: .variable(optionsEnumName, payload: ()),
      property: caseName
    )

    // Options.caseName.rawValue
    let rawValueAccess: Template<Void> = .propertyAccess(
      base: enumMemberAccess,
      property: "rawValue"
    )

    // 1 << Options.caseName.rawValue
    let shiftExpression: Template<Void> = .binaryOperation(
      left: .literal(.integer(1)),
      operator: "<<",
      right: rawValueAccess
    )

    // Self(rawValue: 1 << Options.caseName.rawValue)
    let selfInit: Template<Void> = .functionCall(
      function: "Self",
      arguments: [(label: "rawValue", value: shiftExpression)]
    )

    return .property(
      PropertySignature(
        accessLevel: accessLevel,
        name: caseName,
        type: "Self",
        isStatic: true,
        isLet: true,
        initializer: selfInit
      )
    )
  }
}

// MARK: - Diagnostic Messages

private enum OptionSetMemberDiagnostic: DiagnosticMessage {
  case requiresStruct
  case requiresOptionsEnum(String)
  case requiresRawType

  var message: String {
    switch self {
    case .requiresStruct:
      return "'OptionSet' macro can only be applied to a struct"
    case .requiresOptionsEnum(let name):
      return "'OptionSet' macro requires a nested options enum named '\(name)'"
    case .requiresRawType:
      return "'OptionSet' macro requires a generic RawValue type argument"
    }
  }

  var severity: DiagnosticSeverity { .error }

  var diagnosticID: MessageID {
    MessageID(domain: "MacroTemplateKit.Examples", id: "OptionSetMember.\(self)")
  }
}
