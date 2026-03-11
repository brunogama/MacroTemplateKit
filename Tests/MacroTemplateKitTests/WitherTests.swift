import XCTest

@testable import MacroTemplateKit

final class WitherTests: XCTestCase {

    // MARK: - FunctionSignature

    func testFunctionSignature_withName() {
        let sig = FunctionSignature<Void>(name: "original")
        let modified = sig.withName("renamed")
        XCTAssertEqual(modified.name, "renamed")
        XCTAssertEqual(modified.accessLevel, sig.accessLevel)
        XCTAssertEqual(modified.isAsync, sig.isAsync)
    }

    func testFunctionSignature_withAccessLevel() {
        let sig = FunctionSignature<Void>(name: "test")
        let modified = sig.withAccessLevel(.public)
        XCTAssertEqual(modified.accessLevel, .public)
        XCTAssertEqual(modified.name, "test")
    }

    func testFunctionSignature_withIsAsync() {
        let sig = FunctionSignature<Void>(name: "test")
        let modified = sig.withIsAsync(true)
        XCTAssertTrue(modified.isAsync)
        XCTAssertEqual(modified.name, "test")
    }

    func testFunctionSignature_withCanThrow() {
        let sig = FunctionSignature<Void>(name: "test")
        let modified = sig.withCanThrow(true)
        XCTAssertTrue(modified.canThrow)
    }

    func testFunctionSignature_withReturnType() {
        let sig = FunctionSignature<Void>(name: "test")
        let modified = sig.withReturnType("String")
        XCTAssertEqual(modified.returnType, "String")
    }

    func testFunctionSignature_addingParameter() {
        let sig = FunctionSignature<Void>(name: "test")
        let modified = sig.addingParameter(
            ParameterSignature(label: nil, name: "x", type: "Int")
        )
        XCTAssertEqual(modified.parameters.count, 1)
        XCTAssertEqual(modified.parameters[0].name, "x")
    }

    func testFunctionSignature_removingParameter() {
        let sig = FunctionSignature<Void>(
            name: "test",
            parameters: [
                ParameterSignature(label: nil, name: "a", type: "Int"),
                ParameterSignature(label: nil, name: "b", type: "Int"),
            ]
        )
        let modified = sig.removingParameter(named: "a")
        XCTAssertEqual(modified.parameters.count, 1)
        XCTAssertEqual(modified.parameters[0].name, "b")
    }

    func testFunctionSignature_addingAttribute() {
        let sig = FunctionSignature<Void>(name: "test")
        let modified = sig.addingAttribute(.mainActor)
        XCTAssertEqual(modified.attributes.count, 1)
        XCTAssertEqual(modified.attributes[0].name, "MainActor")
    }

    // MARK: - InitializerSignature

    func testInitializerSignature_withIsFailable() {
        let sig = InitializerSignature<Void>()
        let modified = sig.withIsFailable(true)
        XCTAssertTrue(modified.isFailable)
    }

    func testInitializerSignature_addingParameter() {
        let sig = InitializerSignature<Void>()
        let modified = sig.addingParameter(
            ParameterSignature(label: nil, name: "value", type: "String")
        )
        XCTAssertEqual(modified.parameters.count, 1)
    }

    // MARK: - PropertySignature

    func testPropertySignature_withName() {
        let sig = PropertySignature<Void>(name: "count", type: "Int")
        let modified = sig.withName("total")
        XCTAssertEqual(modified.name, "total")
        XCTAssertEqual(modified.type, "Int")
    }

    func testPropertySignature_withIsLet() {
        let sig = PropertySignature<Void>(name: "count", type: "Int", isLet: true)
        let modified = sig.withIsLet(false)
        XCTAssertFalse(modified.isLet)
    }

    // MARK: - ComputedPropertySignature

    func testComputedPropertySignature_withType() {
        let sig = ComputedPropertySignature<Void>(
            name: "value", type: "Int", getter: []
        )
        let modified = sig.withType("String")
        XCTAssertEqual(modified.type, "String")
        XCTAssertEqual(modified.name, "value")
    }

    // MARK: - SetterSignature

    func testSetterSignature_withParameterName() {
        let sig = SetterSignature<Void>(body: [])
        let modified = sig.withParameterName("val")
        XCTAssertEqual(modified.parameterName, "val")
    }

    // MARK: - ExtensionSignature

    func testExtensionSignature_addingConformance() {
        let sig = ExtensionSignature<Void>(typeName: "MyType")
        let modified = sig.addingConformance("Equatable")
        XCTAssertEqual(modified.conformances, ["Equatable"])
        XCTAssertEqual(modified.typeName, "MyType")
    }

    func testExtensionSignature_addingMember() {
        let sig = ExtensionSignature<Void>(typeName: "MyType")
        let member = Declaration<Void>.function(FunctionSignature(name: "foo", body: []))
        let modified = sig.addingMember(member)
        XCTAssertEqual(modified.members.count, 1)
    }

    // MARK: - StructSignature

    func testStructSignature_withName() {
        let sig = StructSignature<Void>(name: "Point")
        let modified = sig.withName("Vector")
        XCTAssertEqual(modified.name, "Vector")
    }

    func testStructSignature_addingConformance() {
        let sig = StructSignature<Void>(name: "Point")
        let modified = sig.addingConformance("Hashable")
        XCTAssertEqual(modified.conformances, ["Hashable"])
    }

    // MARK: - EnumSignature

    func testEnumSignature_addingCase() {
        let sig = EnumSignature<Void>(name: "Direction")
        let modified = sig.addingCase(EnumCaseSignature(name: "north"))
        XCTAssertEqual(modified.cases.count, 1)
        XCTAssertEqual(modified.cases[0].name, "north")
    }

    func testEnumSignature_withName() {
        let sig = EnumSignature<Void>(name: "Old")
        let modified = sig.withName("New")
        XCTAssertEqual(modified.name, "New")
    }

    // MARK: - TypeAliasSignature

    func testTypeAliasSignature_withExistingType() {
        let sig = TypeAliasSignature(name: "Handler", existingType: "() -> Void")
        let modified = sig.withExistingType("(Int) -> Void")
        XCTAssertEqual(modified.existingType, "(Int) -> Void")
        XCTAssertEqual(modified.name, "Handler")
    }

    func testTypeAliasSignature_withName() {
        let sig = TypeAliasSignature(name: "Old", existingType: "Int")
        let modified = sig.withName("New")
        XCTAssertEqual(modified.name, "New")
        XCTAssertEqual(modified.existingType, "Int")
    }
}
