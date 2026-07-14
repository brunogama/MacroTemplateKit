import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

final class SwiftSyntaxCompatibilityTests: XCTestCase {
  func testGenericCallRendersTypeArgument() {
    let template: Template<Void> = .genericCall(
      function: "decode",
      typeArguments: ["Payload"],
      arguments: []
    )

    XCTAssertEqual(Renderer.render(template).formatted().description, "decode<Payload>()")
  }

  func testGenericParameterPackAndRequirementRender() {
    let declaration = genericDeclaration()
    let source = Renderer.render(declaration).formatted().description

    XCTAssertTrue(source.contains("func load<each Element>()"))
    XCTAssertTrue(source.contains("where each Element: Sendable"))
  }

  func testExtractorReadsGenericParameterPackAndRequirement() {
    let extracted = Extractor.extract(Renderer.render(genericDeclaration()))

    guard case .function(let signature) = extracted else {
      return XCTFail("Expected a function declaration")
    }

    XCTAssertEqual(signature.genericParameters.count, 1)
    XCTAssertTrue(signature.genericParameters[0].isParameterPack)
    XCTAssertEqual(signature.whereRequirements.count, 1)
    XCTAssertEqual(signature.whereRequirements[0].leftType, "each Element")
    XCTAssertEqual(signature.whereRequirements[0].rightType, "Sendable")
  }

  #if canImport(SwiftSyntax603)
    func testLateTypeSpecifierRoundTripsAfterAttributes() {
      let declaration = Declaration<Void>.function(
        FunctionSignature(
          name: "perform",
          parameters: [
            ParameterSignature(
              name: "handler",
              type: "() async -> Void",
              attributes: [.sendable],
              lateSpecifiers: ["nonisolated"]
            )
          ],
          body: []
        )
      )

      let rendered = Renderer.render(declaration)
      let source = rendered.formatted().description
      let extracted = Extractor.extract(rendered)

      XCTAssertTrue(source.contains("handler: @Sendable nonisolated () async -> Void"))
      guard case .function(let signature) = extracted else {
        return XCTFail("Expected a function declaration")
      }
      XCTAssertEqual(signature.parameters[0].lateSpecifiers, ["nonisolated"])
    }
  #endif

  private func genericDeclaration() -> Declaration<Void> {
    .function(
      FunctionSignature(
        name: "load",
        genericParameters: [
          GenericParameterSignature(name: "Element", isParameterPack: true)
        ],
        whereRequirements: [
          .conformance("each Element", "Sendable")
        ],
        body: []
      )
    )
  }
}
