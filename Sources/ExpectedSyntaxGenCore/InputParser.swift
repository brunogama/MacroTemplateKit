import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

enum ParsedExpectedSyntax {
  case sourceFile(SourceFileSyntax)
  case declaration(DeclSyntax)
  case expression(ExprSyntax)
  case declarations([DeclSyntax])
}

enum ExpectedSyntaxInputParser {
  static func parse(source: String, kind: ExpectedSyntaxOutputKind) throws -> ParsedExpectedSyntax {
    let file = Parser.parse(source: source)
    try rejectMalformedSyntax(file)

    switch kind {
    case .sourceFile:
      return .sourceFile(file)
    case .declaration:
      return try parseDeclaration(file)
    case .expression:
      return try parseExpression(file)
    case .declarations:
      return try parseDeclarations(file, source: source)
    }
  }

  private static func parseDeclaration(_ file: SourceFileSyntax) throws -> ParsedExpectedSyntax {
    try rejectFileOnlySyntax(file)
    guard file.statements.count == 1, let item = file.statements.first else {
      throw ExpectedSyntaxGenerationError.rootMismatch(
        expected: .declaration,
        detail: "found \(file.statements.count) top-level items"
      )
    }
    try rejectSemicolon(in: item)
    guard var declaration = DeclSyntax(item.item) else {
      throw ExpectedSyntaxGenerationError.rootMismatch(
        expected: .declaration,
        detail: "the top-level item is not a declaration"
      )
    }
    declaration.trailingTrivia += endOfFileTrivia(file)
    return .declaration(declaration)
  }

  private static func parseExpression(_ file: SourceFileSyntax) throws -> ParsedExpectedSyntax {
    try rejectFileOnlySyntax(file)
    guard file.statements.count == 1, let item = file.statements.first else {
      throw ExpectedSyntaxGenerationError.rootMismatch(
        expected: .expression,
        detail: "found \(file.statements.count) top-level items"
      )
    }
    try rejectSemicolon(in: item)
    guard var expression = ExprSyntax(item.item) else {
      throw ExpectedSyntaxGenerationError.rootMismatch(
        expected: .expression,
        detail: "the top-level item is not an expression"
      )
    }
    expression.trailingTrivia += endOfFileTrivia(file)
    return .expression(expression)
  }

  private static func parseDeclarations(
    _ file: SourceFileSyntax,
    source: String
  ) throws -> ParsedExpectedSyntax {
    try rejectFileOnlySyntax(file)
    if file.statements.isEmpty {
      guard source.isEmpty else {
        throw ExpectedSyntaxGenerationError.unrepresentableFragment(
          "non-empty input without a declaration has no value that can own its trivia"
        )
      }
      return .declarations([])
    }

    var declarations: [DeclSyntax] = []
    declarations.reserveCapacity(file.statements.count)
    for item in file.statements {
      try rejectSemicolon(in: item)
      guard let declaration = DeclSyntax(item.item) else {
        throw ExpectedSyntaxGenerationError.rootMismatch(
          expected: .declarations,
          detail: "top-level item \(declarations.count + 1) is not a declaration"
        )
      }
      declarations.append(declaration)
    }

    if var last = declarations.popLast() {
      last.trailingTrivia += endOfFileTrivia(file)
      declarations.append(last)
    }
    return .declarations(declarations)
  }

  private static func rejectMalformedSyntax(_ file: SourceFileSyntax) throws {
    let converter = SourceLocationConverter(fileName: "input.swift", tree: file)
    let diagnostics = ParseDiagnosticsGenerator.diagnostics(for: file)
      .filter { $0.diagMessage.severity == .error }
      .map { diagnostic in
        let location = diagnostic.location(converter: converter)
        return ExpectedSyntaxDiagnostic(
          message: diagnostic.message,
          line: location.line,
          column: location.column
        )
      }

    guard file.hasError || !diagnostics.isEmpty else { return }

    if diagnostics.isEmpty {
      throw ExpectedSyntaxGenerationError.malformedSource([
        ExpectedSyntaxDiagnostic(
          message: "the parser produced missing or unexpected syntax", line: 1, column: 1)
      ])
    }
    throw ExpectedSyntaxGenerationError.malformedSource(diagnostics)
  }

  private static func rejectFileOnlySyntax(_ file: SourceFileSyntax) throws {
    if file.shebang != nil {
      throw ExpectedSyntaxGenerationError.unrepresentableFragment(
        "a shebang belongs to SourceFileSyntax; use --kind file"
      )
    }
  }

  private static func rejectSemicolon(in item: CodeBlockItemSyntax) throws {
    if item.semicolon != nil {
      throw ExpectedSyntaxGenerationError.unrepresentableFragment(
        "a semicolon belongs to CodeBlockItemSyntax; use --kind file"
      )
    }
  }

  private static func endOfFileTrivia(_ file: SourceFileSyntax) -> Trivia {
    file.endOfFileToken.leadingTrivia + file.endOfFileToken.trailingTrivia
  }
}
