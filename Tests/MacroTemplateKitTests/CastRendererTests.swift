import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

/// Tests for `Template.cast`, which models `as` / `as?` / `as!`.
///
/// Each flavour is checked twice: once for the source text the emitter
/// produces, and once for token parity against the legacy structural renderer,
/// so the parse-backed and structural paths cannot drift apart.
final class CastRendererTests: XCTestCase {

  private func expr(_ name: String) -> Template<Void> {
    .variable(name, payload: ())
  }

  // MARK: - Emitted source

  func testForcedCast_emitsAsBang() throws {
    var buffer = ""
    SourceEmitter.emit(
      Template<Void>.cast(expr("value"), type: "String", kind: .forced), into: &buffer)

    XCTAssertEqual(buffer, "value as! String")
  }

  func testConditionalCast_emitsAsQuestion() throws {
    var buffer = ""
    SourceEmitter.emit(
      Template<Void>.cast(expr("value"), type: "String", kind: .conditional), into: &buffer)

    XCTAssertEqual(buffer, "value as? String")
  }

  func testCoercion_emitsPlainAs() throws {
    var buffer = ""
    SourceEmitter.emit(
      Template<Void>.cast(expr("value"), type: "Any", kind: .coerce), into: &buffer)

    XCTAssertEqual(buffer, "value as Any")
  }

  func testGenericTypeIsEmittedVerbatim() throws {
    var buffer = ""
    SourceEmitter.emit(
      Template<Void>.cast(expr("box"), type: "[String: Int]", kind: .forced), into: &buffer)

    XCTAssertEqual(buffer, "box as! [String: Int]")
  }

  // MARK: - Parity with the legacy structural renderer

  func testAllKinds_matchLegacyTokens() throws {
    for kind in [CastKind.coerce, .conditional, .forced] {
      let template = Template<Void>.cast(expr("value"), type: "String", kind: kind)

      let parsed = try Renderer.render(template)

      XCTAssertFalse(parsed.hasError, "\(kind) should parse cleanly")
      XCTAssertEqual(parsed.trimmedDescription, "value \(kind.operatorText) String")
    }
  }

  // MARK: - Composition

  func testCastComposesWithSubscriptCall_theDictionaryStorageGetterShape() throws {
    // The exact expression MacroTemplateKit could not express before:
    //   _storage["name", default: 0] as! Int
    let template = Template<Void>.cast(
      .subscriptCall(
        base: expr("_storage"),
        arguments: [
          (label: nil, value: .literal(.string("name"))),
          (label: "default", value: .literal(.integer(0))),
        ]
      ),
      type: "Int",
      kind: .forced
    )

    var buffer = ""
    SourceEmitter.emit(template, into: &buffer)

    XCTAssertEqual(buffer, "_storage[\"name\", default: 0] as! Int")
    XCTAssertFalse(try Renderer.render(template).hasError)
  }

  // MARK: - Functor law

  func testMapPreservesCastStructure() throws {
    let template = Template<Int>.cast(
      .variable("v", payload: 1), type: "String", kind: .conditional)

    let mapped: Template<String> = template.map { String($0) }

    guard case .cast(_, let type, let kind) = mapped else {
      return XCTFail("map did not preserve the cast case")
    }
    XCTAssertEqual(type, "String")
    XCTAssertEqual(kind, .conditional)
  }
}
