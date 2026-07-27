import SwiftSyntax

/// Prints each pipeline's output verbatim, trivia included.
///
/// The equivalence gate compares *token streams*, which strips trivia by
/// construction. That makes it blind to a real difference in work: the
/// structural baselines attach no trivia at all and emit
/// `staticfuncmakeCase0(_value:String)->Fixture2{...}`, while the MTK
/// pipelines emit spaced, newline-separated source. Whitespace is bytes in a
/// buffer and tokens to allocate, so the baselines are measured doing strictly
/// less work than the pipeline they are compared against.
///
/// The bias runs *against* MacroTemplateKit — a trivia-matched baseline would
/// be slower, widening MTK's margin — which is why it was never noticed. It is
/// left unfixed and documented rather than silently corrected, because a
/// correction that improves your own numbers deserves more scrutiny than one
/// that worsens them. Run with `--workloads trivia`.
func triviaAudit() {
    let enumFixture = Fixtures.enumDecl(caseCount: 2)
    let cases = extractEnumCases(from: enumFixture)
    let enumName = enumFixture.name.text

    print("## Workload: trivia — verbatim output, showing what the token gate cannot see\n")

    for pipeline in allCaseFactoryPipelines {
        print("=== case-factory: \(type(of: pipeline).name) ===")
        for decl in pipeline.expand(cases: cases, enumName: enumName) {
            print(decl.description)
        }
        print("")
    }

    for pipeline in allCasePathPipelines {
        print("=== case-path: \(type(of: pipeline).name) ===")
        for decl in pipeline.expand(cases: cases, enumName: enumName) {
            print(decl.description)
        }
        print("")
    }

    let structFixture = Fixtures.structDecl(propertyCount: 2)
    let properties = extractStoredProperties(from: structFixture)

    for pipeline in allPipelines where ["structural", "structural-interned", "mtk"].contains(
        type(of: pipeline).name)
    {
        print("=== generate: \(type(of: pipeline).name) ===")
        let output = pipeline.expand(properties: properties)
        print(output.storageMember.description)
        for accessor in output.accessors { print(accessor.description) }
        print("")
    }
}
