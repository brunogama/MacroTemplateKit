import SwiftSyntax
import SwiftSyntaxBuilder

/// Shared attribute rendering helpers used by both expression and declaration rendering.
extension Renderer {
    static func renderAttributes(_ attributes: [AttributeSignature]) -> AttributeListSyntax {
        AttributeListSyntax(
            attributes.map { attribute in
                AttributeListSyntax.Element(
                    AttributeSyntax(stringLiteral: renderAttributeSource(attribute))
                )
            }
        )
    }

    static func renderAttributeSource(_ attribute: AttributeSignature) -> String {
        var source = "@\(attribute.name)"
        if let arguments = attribute.arguments {
            source += "(\(renderAttributeArgumentsSource(arguments)))"
        }
        return source
    }

    static func renderAttributeArgumentsSource(
        _ arguments: AttributeSignature.Arguments
    ) -> String {
        switch arguments {
        case .argumentList(let arguments):
            return arguments.map { argument in
                if let label = argument.label {
                    return "\(label): \(argument.value)"
                }
                return argument.value
            }.joined(separator: ", ")
        case .availability(let arguments):
            return arguments.map(renderAvailabilityArgumentSource).joined(separator: ", ")
        case .raw(let text):
            return text
        }
    }

    static func renderAvailabilityArgumentSource(
        _ argument: AttributeSignature.AvailabilityArgument
    ) -> String {
        switch argument {
        case .token(let token):
            return token
        case .platform(let platform, let version):
            guard let version else { return platform }
            return "\(platform) \(version)"
        case .labeled(let label, let value):
            return "\(label): \(renderAvailabilityValueSource(value))"
        }
    }

    static func renderAvailabilityValueSource(
        _ value: AttributeSignature.AvailabilityValue
    ) -> String {
        switch value {
        case .string(let string):
            return "\"\(string)\""
        case .version(let version):
            return version
        }
    }

    static func renderAttributeArguments(
        _ arguments: AttributeSignature.Arguments?
    ) -> AttributeSyntax.Arguments? {
        guard let arguments else { return nil }

        switch arguments {
        case .argumentList(let arguments):
            return .argumentList(
                LabeledExprListSyntax(
                    arguments.enumerated().map { index, argument in
                        LabeledExprSyntax(
                            label: argument.label.map { .identifier($0) },
                            colon: argument.label != nil ? .colonToken() : nil,
                            expression: ExprSyntax(stringLiteral: argument.value),
                            trailingComma: index < arguments.count - 1
                                ? .commaToken(trailingTrivia: .space)
                                : nil
                        )
                    }
                )
            )
        case .availability(let arguments):
            return .availability(
                AvailabilityArgumentListSyntax(
                    arguments.enumerated().map { index, argument in
                        renderAvailabilityArgument(argument, isLast: index == arguments.count - 1)
                    }
                )
            )
        case .raw(let text):
            return .argumentList(
                LabeledExprListSyntax([
                    LabeledExprSyntax(expression: ExprSyntax(stringLiteral: text))
                ])
            )
        }
    }

    static func renderAvailabilityArgument(
        _ argument: AttributeSignature.AvailabilityArgument,
        isLast: Bool
    ) -> AvailabilityArgumentSyntax {
        let trailingComma = isLast ? nil : TokenSyntax.commaToken(trailingTrivia: .space)

        switch argument {
        case .token(let token):
            return AvailabilityArgumentSyntax(
                argument: .token(renderAvailabilityToken(token)),
                trailingComma: trailingComma
            )
        case .platform(let platform, let version):
            return AvailabilityArgumentSyntax(
                argument: .availabilityVersionRestriction(
                    PlatformVersionSyntax(
                        platform: .identifier(platform),
                        version: version.map(renderVersionTuple)
                    )),
                trailingComma: trailingComma
            )
        case .labeled(let label, let value):
            return AvailabilityArgumentSyntax(
                argument: .availabilityLabeledArgument(
                    AvailabilityLabeledArgumentSyntax(
                        label: .identifier(label),
                        value: renderAvailabilityValue(value)
                    )),
                trailingComma: trailingComma
            )
        }
    }

    static func renderAvailabilityToken(_ token: String) -> TokenSyntax {
        switch token {
        case "*":
            return .wildcardToken()
        case "deprecated":
            return .keyword(.deprecated)
        case "unavailable":
            return .keyword(.unavailable)
        default:
            return .identifier(token)
        }
    }

    static func renderAvailabilityValue(
        _ value: AttributeSignature.AvailabilityValue
    ) -> AvailabilityLabeledArgumentSyntax.Value {
        switch value {
        case .string(let string):
            return .string(renderSimpleStringLiteral(string))
        case .version(let version):
            return .version(renderVersionTuple(version))
        }
    }

    static func renderSimpleStringLiteral(_ string: String)
    -> SimpleStringLiteralExprSyntax
    {
        SimpleStringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: SimpleStringLiteralSegmentListSyntax([
                StringSegmentSyntax(content: .stringSegment(string))
            ]),
            closingQuote: .stringQuoteToken()
        )
    }

    static func renderVersionTuple(_ version: String) -> VersionTupleSyntax {
        let parts = version.split(separator: ".").map(String.init)
        let major = parts.first ?? "0"
        let components = parts.dropFirst().map { component in
            VersionComponentSyntax(number: .integerLiteral(component))
        }

        return VersionTupleSyntax(
            major: .integerLiteral(major),
            components: VersionComponentListSyntax(components)
        )
    }
}
