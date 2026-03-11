import XCTest

@testable import MacroTemplateKit

/// Verifies that `map` is publicly accessible on all signature types.
final class SignatureMapTests: XCTestCase {

    func testFunctionSignature_mapIsPublic() {
        let sig = FunctionSignature<Never>(name: "test")
        let mapped: FunctionSignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.name, "test")
    }

    func testPropertySignature_mapIsPublic() {
        let sig = PropertySignature<Never>(name: "value", type: "Int")
        let mapped: PropertySignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.name, "value")
    }

    func testComputedPropertySignature_mapIsPublic() {
        let sig = ComputedPropertySignature<Never>(
            name: "value", type: "Int", getter: []
        )
        let mapped: ComputedPropertySignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.name, "value")
    }

    func testSetterSignature_mapIsPublic() {
        let sig = SetterSignature<Never>(body: [])
        let mapped: SetterSignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.parameterName, "newValue")
    }

    func testExtensionSignature_mapIsPublic() {
        let sig = ExtensionSignature<Never>(typeName: "MyType")
        let mapped: ExtensionSignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.typeName, "MyType")
    }

    func testStructSignature_mapIsPublic() {
        let sig = StructSignature<Never>(name: "Point")
        let mapped: StructSignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.name, "Point")
    }

    func testEnumSignature_mapIsPublic() {
        let sig = EnumSignature<Never>(name: "Direction")
        let mapped: EnumSignature<Void> = sig.map { _ in () }
        XCTAssertEqual(mapped.name, "Direction")
    }

    func testInitializerSignature_mapIsPublic() {
        let sig = InitializerSignature<Never>()
        let mapped: InitializerSignature<Void> = sig.map { _ in () }
        XCTAssertFalse(mapped.isFailable)
    }

    func testDeclaration_mapIsPublic() {
        let decl = Declaration<Never>.function(FunctionSignature(name: "test"))
        let mapped: Declaration<Void> = decl.map { _ in () }
        if case .function(let sig) = mapped {
            XCTAssertEqual(sig.name, "test")
        } else {
            XCTFail("Expected .function")
        }
    }

    func testExtractThenMap_pipeline() {
        let sig = FunctionSignature<Never>(name: "extracted")
        let withBody: FunctionSignature<Void> = sig.map { _ in () }
        XCTAssertEqual(withBody.name, "extracted")
        XCTAssertTrue(withBody.body.isEmpty)
    }
}
