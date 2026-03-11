import SwiftSyntax
import XCTest

@testable import MacroTemplateKit

final class ExtractorTests: XCTestCase {

    // MARK: - Function round-trip

    func testExtractFunction_simple() {
        let original = Declaration<Void>.function(
            FunctionSignature(name: "greet", body: [])
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function, got \(String(describing: extracted))")
        }
        XCTAssertEqual(sig.name, "greet")
        XCTAssertEqual(sig.accessLevel, .internal)
        XCTAssertFalse(sig.isAsync)
        XCTAssertFalse(sig.canThrow)
        XCTAssertNil(sig.returnType)
        XCTAssertTrue(sig.parameters.isEmpty)
    }

    func testExtractFunction_withParameters() {
        let original = Declaration<Void>.function(
            FunctionSignature(
                accessLevel: .public,
                isStatic: true,
                isMutating: false,
                name: "add",
                parameters: [
                    ParameterSignature(label: nil, name: "a", type: "Int"),
                    ParameterSignature(label: "to", name: "b", type: "Int"),
                ],
                isAsync: true,
                canThrow: true,
                returnType: "Int",
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function")
        }
        XCTAssertEqual(sig.name, "add")
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertTrue(sig.isStatic)
        XCTAssertTrue(sig.isAsync)
        XCTAssertTrue(sig.canThrow)
        XCTAssertEqual(sig.returnType, "Int")
        XCTAssertEqual(sig.parameters.count, 2)
        XCTAssertEqual(sig.parameters[0].name, "a")
        XCTAssertEqual(sig.parameters[1].label, "to")
        XCTAssertEqual(sig.parameters[1].name, "b")
    }

    func testExtractFunction_withGenerics() {
        let original = Declaration<Void>.function(
            FunctionSignature(
                name: "transform",
                genericParameters: [
                    GenericParameterSignature(name: "T", constraint: "Hashable")
                ],
                parameters: [
                    ParameterSignature(label: nil, name: "value", type: "T")
                ],
                returnType: "T",
                whereRequirements: [
                    .conformance("T", "Sendable")
                ],
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function")
        }
        XCTAssertEqual(sig.genericParameters.count, 1)
        XCTAssertEqual(sig.genericParameters[0].name, "T")
        XCTAssertEqual(sig.genericParameters[0].constraint, "Hashable")
        XCTAssertEqual(sig.whereRequirements.count, 1)
        XCTAssertEqual(sig.whereRequirements[0].leftType, "T")
        XCTAssertEqual(sig.whereRequirements[0].rightType, "Sendable")
    }

    // MARK: - Initializer round-trip

    func testExtractInitializer() {
        let original = Declaration<Void>.initDecl(
            InitializerSignature(
                accessLevel: .public,
                isFailable: true,
                parameters: [
                    ParameterSignature(label: nil, name: "value", type: "Int")
                ],
                canThrow: true,
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .initDecl(let sig) = extracted else {
            return XCTFail("Expected .initDecl")
        }
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertTrue(sig.isFailable)
        XCTAssertTrue(sig.canThrow)
        XCTAssertEqual(sig.parameters.count, 1)
    }

    // MARK: - Property round-trip

    func testExtractStoredProperty() {
        let original = Declaration<Void>.property(
            PropertySignature(
                accessLevel: .public,
                name: "count",
                type: "Int",
                isStatic: true,
                isLet: true
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .property(let sig) = extracted else {
            return XCTFail("Expected .property, got \(String(describing: extracted))")
        }
        XCTAssertEqual(sig.name, "count")
        XCTAssertEqual(sig.type, "Int")
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertTrue(sig.isStatic)
        XCTAssertTrue(sig.isLet)
    }

    func testExtractComputedProperty() {
        let original = Declaration<Void>.computedProperty(
            ComputedPropertySignature(
                accessLevel: .public,
                name: "value",
                type: "Int",
                getter: [.returnStatement(.literal(.integer(42)))],
                setter: SetterSignature(
                    parameterName: "val",
                    body: [.expression(.variable("val", payload: ()))]
                )
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .computedProperty(let sig) = extracted else {
            return XCTFail("Expected .computedProperty, got \(String(describing: extracted))")
        }
        XCTAssertEqual(sig.name, "value")
        XCTAssertEqual(sig.type, "Int")
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertNotNil(sig.setter)
        XCTAssertEqual(sig.setter?.parameterName, "val")
        XCTAssertTrue(sig.getter.isEmpty)
    }

    // MARK: - Extension round-trip

    func testExtractExtension() {
        let original = Declaration<Void>.extensionDecl(
            ExtensionSignature(
                typeName: "MyType",
                conformances: ["Equatable", "Hashable"],
                members: [
                    .function(FunctionSignature(name: "foo", body: []))
                ]
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .extensionDecl(let sig) = extracted else {
            return XCTFail("Expected .extensionDecl")
        }
        XCTAssertEqual(sig.typeName, "MyType")
        XCTAssertEqual(sig.conformances, ["Equatable", "Hashable"])
        XCTAssertEqual(sig.members.count, 1)
    }

    // MARK: - Struct round-trip

    func testExtractStruct() {
        let original = Declaration<Void>.structDecl(
            StructSignature(
                accessLevel: .public,
                name: "Point",
                conformances: ["Equatable"],
                members: [
                    .property(PropertySignature(name: "x", type: "Int", isLet: true)),
                    .property(PropertySignature(name: "y", type: "Int", isLet: true)),
                ]
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .structDecl(let sig) = extracted else {
            return XCTFail("Expected .structDecl")
        }
        XCTAssertEqual(sig.name, "Point")
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertEqual(sig.conformances, ["Equatable"])
        XCTAssertEqual(sig.members.count, 2)
    }

    // MARK: - Enum round-trip

    func testExtractEnum() {
        let original = Declaration<Void>.enumDecl(
            EnumSignature(
                accessLevel: .public,
                name: "Direction",
                conformances: ["String"],
                cases: [
                    EnumCaseSignature(name: "north", rawValue: "north"),
                    EnumCaseSignature(name: "south", rawValue: "south"),
                ]
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .enumDecl(let sig) = extracted else {
            return XCTFail("Expected .enumDecl")
        }
        XCTAssertEqual(sig.name, "Direction")
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertEqual(sig.conformances, ["String"])
        XCTAssertEqual(sig.cases.count, 2)
        XCTAssertEqual(sig.cases[0].name, "north")
        XCTAssertEqual(sig.cases[0].rawValue, "north")
    }

    func testExtractEnum_withAssociatedTypes() {
        let original = Declaration<Void>.enumDecl(
            EnumSignature(
                name: "Result",
                cases: [
                    EnumCaseSignature(name: "success", associatedTypes: ["String"]),
                    EnumCaseSignature(name: "failure", associatedTypes: ["Error"]),
                ]
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .enumDecl(let sig) = extracted else {
            return XCTFail("Expected .enumDecl")
        }
        XCTAssertEqual(sig.cases.count, 2)
        XCTAssertEqual(sig.cases[0].associatedTypes, ["String"])
        XCTAssertEqual(sig.cases[1].associatedTypes, ["Error"])
    }

    // MARK: - TypeAlias round-trip

    func testExtractTypeAlias() {
        let original = Declaration<Void>.typeAlias(
            TypeAliasSignature(
                accessLevel: .public,
                name: "Callback",
                existingType: "() -> Void"
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .typeAlias(let sig) = extracted else {
            return XCTFail("Expected .typeAlias")
        }
        XCTAssertEqual(sig.name, "Callback")
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertEqual(sig.existingType, "() -> Void")
    }

    // MARK: - Stored property initializer (intentionally not extracted)

    func testExtractStoredProperty_initializerIsNotExtracted() {
        let decl = DeclSyntax("var count: Int = 42")
        let result = Extractor.extract(decl)

        guard case .property(let sig) = result else {
            return XCTFail("Expected .property, got \(String(describing: result))")
        }
        XCTAssertEqual(sig.name, "count")
        XCTAssertEqual(sig.type, "Int")
        XCTAssertFalse(sig.isLet)
        // Initializers are intentionally not extracted; attach them after
        // extraction via withInitializer(_:) or by constructing a new signature.
        XCTAssertNil(sig.initializer)
    }

    // MARK: - Multi-binding extraction

    func testExtractAll_multiBindingVar() {
        let decl = DeclSyntax("var x: Int, y: Int")
        let results = Extractor.extractAll(decl)

        XCTAssertEqual(results.count, 2)

        guard case .property(let first) = results[0] else {
            return XCTFail("Expected .property for first binding")
        }
        XCTAssertEqual(first.name, "x")
        XCTAssertEqual(first.type, "Int")
        XCTAssertFalse(first.isLet)

        guard case .property(let second) = results[1] else {
            return XCTFail("Expected .property for second binding")
        }
        XCTAssertEqual(second.name, "y")
        XCTAssertEqual(second.type, "Int")
    }

    func testExtractAll_multiBindingLet() {
        let decl = DeclSyntax("public static let a: String, b: String")
        let results = Extractor.extractAll(decl)

        XCTAssertEqual(results.count, 2)

        guard case .property(let first) = results[0] else {
            return XCTFail("Expected .property")
        }
        XCTAssertEqual(first.name, "a")
        XCTAssertTrue(first.isLet)
        XCTAssertTrue(first.isStatic)
        XCTAssertEqual(first.accessLevel, .public)

        guard case .property(let second) = results[1] else {
            return XCTFail("Expected .property")
        }
        XCTAssertEqual(second.name, "b")
        XCTAssertTrue(second.isLet)
        XCTAssertTrue(second.isStatic)
        XCTAssertEqual(second.accessLevel, .public)
    }

    func testExtract_multiBinding_returnsFirst() {
        let decl = DeclSyntax("var x: Int, y: Int")
        let result = Extractor.extract(decl)

        guard case .property(let sig) = result else {
            return XCTFail("Expected .property")
        }
        XCTAssertEqual(sig.name, "x")
    }

    func testExtractAll_nonVariable_returnsSingleElement() {
        let decl = DeclSyntax("func foo() {}")
        let results = Extractor.extractAll(decl)
        XCTAssertEqual(results.count, 1)
    }

    func testExtractAll_unsupported_returnsEmpty() {
        let decl = DeclSyntax("class Foo {}")
        let results = Extractor.extractAll(decl)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Untyped computed property (skipped)

    func testExtractComputedProperty_withoutTypeAnnotation_returnsNil() {
        let decl = DeclSyntax("var x { 1 }")
        let result = Extractor.extract(decl)
        XCTAssertNil(result, "Untyped computed properties cannot be represented and should be skipped")
    }

    // MARK: - Unsupported

    func testExtractUnsupported_returnsNil() {
        let classDecl = DeclSyntax("class Foo {}")
        XCTAssertNil(Extractor.extract(classDecl))
    }

    // MARK: - Mutating function

    func testExtractFunction_mutating() {
        let original = Declaration<Void>.function(
            FunctionSignature(
                isMutating: true,
                name: "toggle",
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function")
        }
        XCTAssertTrue(sig.isMutating)
    }

    // MARK: - Parameter attributes

    func testExtractFunction_escapingParameter() {
        let original = Declaration<Void>.function(
            FunctionSignature(
                name: "perform",
                parameters: [
                    ParameterSignature(
                        label: nil,
                        name: "handler",
                        type: "() -> Void",
                        attributes: [.escaping]
                    )
                ],
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function")
        }
        XCTAssertEqual(sig.parameters.count, 1)
        XCTAssertEqual(sig.parameters[0].type, "() -> Void")
        XCTAssertTrue(
            sig.parameters[0].attributes.contains { $0.name == "escaping" }
        )
    }

    // MARK: - Availability attribute round-trip

    func testExtractFunction_withAvailableAttribute() {
        let original = Declaration<Void>.function(
            FunctionSignature(
                attributes: [
                    .available([
                        .platform("macOS", version: "13"),
                        .token("*"),
                    ])
                ],
                name: "newer",
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function")
        }
        XCTAssertEqual(sig.attributes.count, 1)
        XCTAssertEqual(sig.attributes[0].name, "available")

        guard case .availability(let args) = sig.attributes[0].arguments else {
            return XCTFail("Expected .availability arguments")
        }
        XCTAssertEqual(args.count, 2)

        if case .platform(let platform, let version) = args[0] {
            XCTAssertEqual(platform, "macOS")
            XCTAssertEqual(version, "13")
        } else {
            XCTFail("Expected .platform, got \(args[0])")
        }

        if case .token(let token) = args[1] {
            XCTAssertEqual(token, "*")
        } else {
            XCTFail("Expected .token(*), got \(args[1])")
        }
    }

    func testExtractFunction_withRawAttributeArguments() {
        let decl = DeclSyntax(#"@objc(mySelector:) func bridge() {}"#)
        let result = Extractor.extract(decl)

        guard case .function(let sig) = result else {
            return XCTFail("Expected .function")
        }
        XCTAssertEqual(sig.attributes.count, 1)
        XCTAssertEqual(sig.attributes[0].name, "objc")

        guard case .raw(let text) = sig.attributes[0].arguments else {
            return XCTFail(
                "Expected .raw arguments, got \(String(describing: sig.attributes[0].arguments))")
        }
        XCTAssertTrue(text.contains("mySelector"))
    }

    // MARK: - Typed variable extraction

    func testExtractVariable_typedOverload() {
        let decl = DeclSyntax("public var x: Int, y: String")
            .as(VariableDeclSyntax.self)!
        let results = Extractor.extract(decl)

        XCTAssertEqual(results.count, 2)

        guard case .property(let first) = results[0] else {
            return XCTFail("Expected .property")
        }
        XCTAssertEqual(first.name, "x")
        XCTAssertEqual(first.type, "Int")
        XCTAssertEqual(first.accessLevel, .public)

        guard case .property(let second) = results[1] else {
            return XCTFail("Expected .property")
        }
        XCTAssertEqual(second.name, "y")
        XCTAssertEqual(second.type, "String")
    }

    // MARK: - Extension accessLevel extraction

    func testExtractExtension_withAccessLevel() {
        let decl = DeclSyntax("public extension MyType {}")
        let result = Extractor.extract(decl)

        guard case .extensionDecl(let sig) = result else {
            return XCTFail("Expected .extensionDecl")
        }
        XCTAssertEqual(sig.accessLevel, .public)
        XCTAssertEqual(sig.typeName, "MyType")
    }

    func testExtractFunction_withAvailableDeprecated() {
        let original = Declaration<Void>.function(
            FunctionSignature(
                attributes: [
                    .available([
                        .token("*"),
                        .token("deprecated"),
                        .labeled("message", .string("Use newMethod")),
                    ])
                ],
                name: "oldMethod",
                body: []
            )
        )
        let rendered = Renderer.render(original)
        let extracted = Extractor.extract(rendered)

        guard case .function(let sig) = extracted else {
            return XCTFail("Expected .function")
        }
        guard case .availability(let args) = sig.attributes[0].arguments else {
            return XCTFail("Expected .availability arguments")
        }
        XCTAssertEqual(args.count, 3)

        if case .token(let token) = args[0] {
            XCTAssertEqual(token, "*")
        } else {
            XCTFail("Expected .token(*)")
        }

        if case .token(let token) = args[1] {
            XCTAssertEqual(token, "deprecated")
        } else {
            XCTFail("Expected .token(deprecated)")
        }

        if case .labeled(let label, let value) = args[2] {
            XCTAssertEqual(label, "message")
            if case .string(let msg) = value {
                XCTAssertEqual(msg, "Use newMethod")
            } else {
                XCTFail("Expected .string value")
            }
        } else {
            XCTFail("Expected .labeled argument")
        }
    }
}
