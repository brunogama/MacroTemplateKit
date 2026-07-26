import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

final class SwiftSyntaxCompatibilityTests: XCTestCase {
  func testGenericCallRendersTypeArgument() throws {
    let template: Template<Void> = .genericCall(
      function: "decode",
      typeArguments: ["Payload"],
      arguments: []
    )

    XCTAssertEqual(try Renderer.render(template).formatted().description, "decode<Payload>()")
  }

  func testGenericParameterPackAndRequirementRender() throws {
    let declaration = genericDeclaration()
    let source = try Renderer.render(declaration).formatted().description

    XCTAssertTrue(source.contains("func load<each Element>()"))
    XCTAssertTrue(source.contains("where each Element: Sendable"))
  }

  func testExtractorReadsGenericParameterPackAndRequirement() throws {
    let extracted = try Extractor.extract(Renderer.render(genericDeclaration()))

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
    func testInvalidLateTypeSpecifierIsRejectedByParseGate() {
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

      XCTAssertThrowsError(try Renderer.render(declaration)) { error in
        XCTAssertTrue(error is RenderError)
      }
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
