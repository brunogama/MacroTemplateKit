import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Tests that reserved keywords used as identifiers are backtick-escaped, so
/// declarations extracted from real source (a property named `default`, a case
/// named `class`) render as parsable Swift instead of tripping the parse gate.
///
/// The complementary half matters just as much: contextual keywords, expression
/// keywords, and argument labels must render *bare*, since escaping those would
/// change meaning or add noise.
final class IdentifierEscapingTests: XCTestCase {

  // MARK: - Reserved keywords are escaped

  func testVariableReference_reservedKeyword_isEscaped() throws {
    var buffer = ""
    SourceEmitter.emit(Template<Void>.variable("default", payload: ()), into: &buffer)

    XCTAssertEqual(buffer, "`default`")
  }

  func testVariableReference_reservedKeyword_parsesCleanly() throws {
    let rendered = try Renderer.render(Template<Void>.variable("class", payload: ()))

    XCTAssertFalse(rendered.hasError, "Escaped identifier should parse without error")
    XCTAssertEqual(rendered.trimmedDescription, "`class`")
  }

  func testPropertyAccessBase_reservedKeyword_isEscaped() throws {
    // The base is a variable reference (needs escaping); the member after the
    // dot is not (Swift accepts keywords bare there).
    var buffer = ""
    SourceEmitter.emit(
      Template<Void>.propertyAccess(base: .variable("if", payload: ()), property: "default"),
      into: &buffer
    )

    XCTAssertEqual(buffer, "`if`.default")
  }

  // MARK: - Expression keywords are NOT escaped

  func testVariableReference_selfAndSuper_areNotEscaped() throws {
    for name in ["self", "Self", "super", "nil", "true", "false", "Any"] {
      var buffer = ""
      SourceEmitter.emit(Template<Void>.variable(name, payload: ()), into: &buffer)

      XCTAssertEqual(
        buffer, name,
        "\(name) is a legal expression; escaping it would change meaning"
      )
    }
  }

  // MARK: - Contextual keywords are NOT escaped

  func testContextualKeywords_areNotEscaped() throws {
    for name in ["open", "some", "any", "get", "set", "final", "lazy", "weak", "override"] {
      var buffer = ""
      SourceEmitter.emit(Template<Void>.variable(name, payload: ()), into: &buffer)

      XCTAssertEqual(
        buffer, name,
        "\(name) is contextual and legal as an identifier; escaping it is noise"
      )
    }
  }

  // MARK: - Ordinary identifiers are untouched

  func testOrdinaryIdentifier_isUnchanged() throws {
    var buffer = ""
    SourceEmitter.emit(Template<Void>.variable("userName", payload: ()), into: &buffer)

    XCTAssertEqual(buffer, "userName")
  }

  func testAlreadyBacktickedIdentifier_isNotDoubleEscaped() throws {
    XCTAssertEqual(SourceEmitter.escapeIdentifier("`default`"), "`default`")
  }
}
