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

  /// Documents a real hole rather than asserting desired behaviour.
  ///
  /// `renderLeaf` builds `.variable` structurally to avoid allocating a parse
  /// arena per call, which means the name is never validated — a malformed
  /// identifier becomes a malformed token and reaches the compiler unchecked.
  /// The parse gate only guards templates that actually go through the parser.
  ///
  /// Closing this needs a decision: validating identifiers would also reject
  /// `.variable` used as a raw-text escape hatch, which is what callers had to
  /// do before `.syntax` existed.
  func testLeafPathCurrentlyBypassesTheParseGate() throws {
    let malformed = Template<Void>.variable("(((", payload: ())

    let rendered = try Renderer.render(malformed)

    // Worse than an error node: a structurally built token simply *holds* the
    // garbage text, so `hasError` is false and nothing downstream notices
    // until the compiler tries to make sense of the emitted source.
    XCTAssertFalse(rendered.hasError)
    XCTAssertEqual(rendered.description, "(((")
  }

  func testWellFormedTemplatesDoNotThrow() throws {
    XCTAssertNoThrow(try Renderer.render(Template<Void>.variable("value", payload: ())))
    XCTAssertNoThrow(try Renderer.render(Statement<Void>.expression(.variable("value"))))
  }
}
