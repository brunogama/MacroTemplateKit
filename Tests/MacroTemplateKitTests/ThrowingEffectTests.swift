import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

final class ThrowingEffectTests: XCTestCase {
  func testLegacyBooleanInitializerProjectsToCanonicalEffect() {
    let nonthrowing = FunctionSignature<Void>(name: "read", canThrow: false)
    let throwing = FunctionSignature<Void>(name: "read", canThrow: true)

    XCTAssertEqual(nonthrowing.throwingEffect, .none)
    XCTAssertFalse(nonthrowing.canThrow)
    XCTAssertEqual(throwing.throwingEffect, .throws())
    XCTAssertTrue(throwing.canThrow)
  }

  func testRendererPreservesThrowingEffectSpelling() throws {
    XCTAssertTrue(try render(.none).contains("func execute()"))
    XCTAssertTrue(try render(.throws()).contains("func execute() throws"))
    XCTAssertTrue(
      try render(.throws(errorType: "NetworkError"), isAsync: true)
        .contains("func execute() async throws(NetworkError)")
    )
    XCTAssertTrue(
      try render(.rethrows).contains("func execute(operation: () throws -> Void) rethrows")
    )
  }

  func testRendererAndExtractorRoundTripEveryThrowingEffect() throws {
    let effects: [ThrowingEffect] = [
      .none,
      .throws(),
      .throws(errorType: "NetworkError"),
      .rethrows,
    ]

    for effect in effects {
      let declaration = Declaration<Void>.function(signature(effect))
      let extracted = try Extractor.extract(Renderer.render(declaration))

      guard case .function(let function) = extracted else {
        return XCTFail("Expected a function declaration")
      }
      XCTAssertEqual(function.throwingEffect, effect)
    }
  }

  func testMapAndWithersPreserveTypedThrows() {
    let signature = FunctionSignature<Int>(
      name: "execute",
      throwingEffect: .throws(errorType: "NetworkError")
    )
    let mapped: FunctionSignature<String> = signature.map(String.init)
    let variants = [
      signature.withAccessLevel(.public),
      signature.withAttributes([]),
      signature.withIsStatic(true),
      signature.withIsMutating(true),
      signature.withName("renamed"),
      signature.withGenericParameters([]),
      signature.withParameters([]),
      signature.withIsAsync(true),
      signature.withReturnType("Int"),
      signature.withWhereRequirements([]),
      signature.withBody([]),
      signature.addingParameter(ParameterSignature(name: "value", type: "Int")),
      signature.removingParameter(named: "missing"),
      signature.addingAttribute(.sendable),
    ]

    XCTAssertEqual(mapped.throwingEffect, signature.throwingEffect)
    XCTAssertTrue(variants.allSatisfy { $0.throwingEffect == signature.throwingEffect })
  }

  func testBooleanWitherDoesNotDowngradeRichEffects() {
    let nonthrowing = FunctionSignature<Void>(name: "execute")
    let typed = FunctionSignature<Void>(
      name: "execute",
      throwingEffect: .throws(errorType: "NetworkError")
    )
    let rethrowing = FunctionSignature<Void>(name: "execute", throwingEffect: .rethrows)

    XCTAssertEqual(nonthrowing.withCanThrow(true).throwingEffect, .throws())
    XCTAssertEqual(typed.withCanThrow(true).throwingEffect, typed.throwingEffect)
    XCTAssertEqual(rethrowing.withCanThrow(true).throwingEffect, .rethrows)
    XCTAssertEqual(typed.withCanThrow(false).throwingEffect, .none)
  }

  private func render(
    _ effect: ThrowingEffect,
    isAsync: Bool = false
  ) throws -> String {
    try Renderer.render(Declaration<Void>.function(signature(effect, isAsync: isAsync)))
      .formatted().description
  }

  private func signature(
    _ effect: ThrowingEffect,
    isAsync: Bool = false
  ) -> FunctionSignature<Void> {
    FunctionSignature(
      name: "execute",
      parameters: effect == .rethrows
        ? [ParameterSignature(name: "operation", type: "() throws -> Void")]
        : [],
      isAsync: isAsync,
      throwingEffect: effect,
      body: []
    )
  }
}
