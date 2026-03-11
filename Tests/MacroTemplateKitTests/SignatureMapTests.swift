import MacroTemplateKit
import XCTest

/// Verifies that `map` is publicly accessible on all signature types.
///
/// Uses `Int` (not `Never`) as the source payload so closures are not
/// provably unreachable — avoiding "will never be executed" warnings.
final class SignatureMapTests: XCTestCase {

    func testFunctionSignature_mapIsPublic() {
        let sig = FunctionSignature<Int>(name: "test")
        let mapped: FunctionSignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.name, "test")
    }

    func testPropertySignature_mapIsPublic() {
        let sig = PropertySignature<Int>(name: "value", type: "Int")
        let mapped: PropertySignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.name, "value")
    }

    func testComputedPropertySignature_mapIsPublic() {
        let sig = ComputedPropertySignature<Int>(
            name: "value", type: "Int", getter: []
        )
        let mapped: ComputedPropertySignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.name, "value")
    }

    func testSetterSignature_mapIsPublic() {
        let sig = SetterSignature<Int>(body: [])
        let mapped: SetterSignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.parameterName, "newValue")
    }

    func testExtensionSignature_mapIsPublic() {
        let sig = ExtensionSignature<Int>(typeName: "MyType")
        let mapped: ExtensionSignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.typeName, "MyType")
    }

    func testStructSignature_mapIsPublic() {
        let sig = StructSignature<Int>(name: "Point")
        let mapped: StructSignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.name, "Point")
    }

    func testEnumSignature_mapIsPublic() {
        let sig = EnumSignature<Int>(name: "Direction")
        let mapped: EnumSignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(mapped.name, "Direction")
    }

    func testInitializerSignature_mapIsPublic() {
        let sig = InitializerSignature<Int>()
        let mapped: InitializerSignature<String> = sig.map { "\($0)" }
        XCTAssertFalse(mapped.isFailable)
    }

    func testDeclaration_mapIsPublic() {
        let decl = Declaration<Int>.function(FunctionSignature(name: "test"))
        let mapped: Declaration<String> = decl.map { "\($0)" }
        if case .function(let sig) = mapped {
            XCTAssertEqual(sig.name, "test")
        } else {
            XCTFail("Expected .function")
        }
    }

    func testExtractThenMap_pipeline() {
        let sig = FunctionSignature<Int>(name: "extracted")
        let withBody: FunctionSignature<String> = sig.map { "\($0)" }
        XCTAssertEqual(withBody.name, "extracted")
        XCTAssertTrue(withBody.body.isEmpty)
    }
}
