import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Tests the parse gate.
///
/// The gate was previously an `assert`, which the compiler strips from release
/// builds — the only configuration a macro plugin ships in. A malformed emit
/// therefore reached the compiler as an error-laden tree and produced a
/// diagnostic against the *user's* code. It now throws in every build.
final class RenderErrorTests: XCTestCase {

  func testUnparsableSourceThrows() {
    // A composite goes through emit-and-parse, so the gate applies. The
    // function name is emitted verbatim, making the buffer unparsable.
    let broken = Template<Void>.functionCall(function: "(((", arguments: [])

    XCTAssertThrowsError(try Renderer.render(broken)) { error in
      guard let renderError = error as? RenderError else {
        return XCTFail("expected RenderError, got \(type(of: error))")
      }
      XCTAssertEqual(renderError.kind, .expression)
      XCTAssertTrue(
        renderError.source.contains("((("),
        "the offending source belongs in the report, got: \(renderError.source)"
      )
    }
  }

  func testErrorDescriptionNamesTheLibraryAsTheCulprit() {
    let error = RenderError(kind: .declaration, source: "var", diagnostics: ["unexpected end"])

    // A macro author seeing this in a build log should not go looking through
    // their own macro for the bug.
    XCTAssertTrue(error.description.contains("bug in MacroTemplateKit"))
    XCTAssertTrue(error.description.contains("var"))
    XCTAssertTrue(error.description.contains("unexpected end"))
  }

  /// The leaf fast path must not become a hole in the parse gate.
  ///
  /// `renderLeaf` builds `.variable` structurally to avoid a parse arena per
  /// call, so its contents are never parsed. It therefore takes the fast path
  /// only for bare identifiers; anything else falls through to emit-and-parse
  /// and is caught here.
  func testMalformedIdentifierFallsThroughToTheParseGate() {
    XCTAssertThrowsError(try Renderer.render(Template<Void>.variable("(((", payload: ()))) {
      XCTAssertEqual(($0 as? RenderError)?.kind, .expression)
    }
  }

  /// `.variable` doubles as the raw-source escape hatch — `AddAsyncMacro` uses
  /// it for a pattern — so non-identifier contents must still render, just via
  /// the parser rather than the fast path.
  func testVariableStillWorksAsARawSourceEscapeHatch() throws {
    let rendered = try Renderer.render(Template<Void>.variable("foo.bar()", payload: ()))

    XCTAssertFalse(rendered.hasError)
    XCTAssertEqual(rendered.trimmedDescription, "foo.bar()")
  }

  func testWellFormedTemplatesDoNotThrow() throws {
    XCTAssertNoThrow(try Renderer.render(Template<Void>.variable("value", payload: ())))
    XCTAssertNoThrow(try Renderer.render(Statement<Void>.expression(.variable("value"))))
  }
}
