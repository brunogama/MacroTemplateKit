import Foundation
import SwiftSyntax

// MARK: - Registry

let allPipelines: [ASTGeneratorPipeline] = [
    StructuralPipeline(),
    MTKPipeline(),
    MTKLeafPipeline(),
    InterpolationPipeline(),
    ReparsePipeline(),
    ParseBackedMTKPipeline(),
    InternedStructuralPipeline(),
    MemoizedMTKPipeline(),
]

let allCaseFactoryPipelines: [CaseFactoryPipeline] = [
    StructuralCaseFactoryPipeline(),
    MTKCaseFactoryPipeline(),
]

let allEditPipelines: [TreeEditPipeline] = [
    WithEditPipeline(),
    RewriterEditPipeline(),
]

// Keep in sync with the exact pin in Package.swift.
let swiftSyntaxVersion = "603.0.2"

// MARK: - CLI

struct Options {
    var pipelineNames = allPipelines.map { type(of: $0).name }
    var editPipelineNames = allEditPipelines.map { type(of: $0).name }
    var caseFactoryPipelineNames = allCaseFactoryPipelines.map { type(of: $0).name }
    var workloads = ["generate", "edit", "case-factory"]
    var sizes = [4, 16, 64, 256]
    var iterations = 300
    var warmup = 50
    var listOnly = false

    static func parse(_ arguments: [String]) -> Options {
        var options = Options()
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--pipelines":
                options.pipelineNames = iterator.next()?.split(separator: ",").map(String.init) ?? []
            case "--edit-pipelines":
                options.editPipelineNames =
                    iterator.next()?.split(separator: ",").map(String.init) ?? []
            case "--workloads":
                options.workloads = iterator.next()?.split(separator: ",").map(String.init) ?? []
            case "--sizes":
                options.sizes = iterator.next()?.split(separator: ",").compactMap { Int($0) } ?? []
            case "--iterations":
                options.iterations = iterator.next().flatMap { Int($0) } ?? options.iterations
            case "--warmup":
                options.warmup = iterator.next().flatMap { Int($0) } ?? options.warmup
            case "--list":
                options.listOnly = true
            default:
                FileHandle.standardError.write(Data("unknown option: \(argument)\n".utf8))
                exit(64)
            }
        }
        return options
    }
}

let options = Options.parse(CommandLine.arguments)

if options.listOnly {
    print("generate workload (--pipelines):")
    for pipeline in allPipelines {
        let kind = type(of: pipeline)
        print("  \(kind.name): \(kind.summary)")
    }
    print("edit workload (--edit-pipelines):")
    for pipeline in allEditPipelines {
        let kind = type(of: pipeline)
        print("  \(kind.name): \(kind.summary)")
    }
    exit(0)
}

#if DEBUG
print("⚠️  DEBUG build — results are not meaningful. Re-run with: swift run -c release RenderEngineBench")
#endif

// MARK: - Reporting

func format(_ value: Double) -> String {
    value >= 1000 ? String(format: "%.0f", value) : String(format: "%.1f", value)
}

func printTable(results: [BenchResult], sizes: [Int], baselineName: String) {
    print("| pipeline | props | min µs | p50 µs | p90 µs | mean µs | vs \(baselineName) | retained KB/run |")
    print("|---|---|---|---|---|---|---|---|")
    for size in sizes {
        let group = results.filter { $0.propertyCount == size }
        let baseline = group.first { $0.pipeline == baselineName }?.timing.p50Micros
        for result in group {
            let ratio: String
            if let baseline, baseline > 0 {
                ratio = String(format: "%.2f×", result.timing.p50Micros / baseline)
            } else {
                ratio = "—"
            }
            print(
                "| \(result.pipeline) | \(result.propertyCount) "
                    + "| \(format(result.timing.minMicros)) | \(format(result.timing.p50Micros)) "
                    + "| \(format(result.timing.p90Micros)) | \(format(result.timing.meanMicros)) "
                    + "| \(ratio) | \(String(format: "%.1f", result.retainedBytesPerIteration / 1024)) |"
            )
        }
    }
    print("")
}

// MARK: - Workload runner

let equivalenceFixture = Fixtures.structDecl(propertyCount: 6)
let caseFactoryEquivalenceFixture = Fixtures.enumDecl(caseCount: 6)

/// Runs one workload end-to-end: select pipelines by name, gate on output
/// equivalence, measure every (pipeline × size) cell, and print the table
/// with the first selected pipeline as the ratio baseline.
func runWorkload<Pipeline, Fixture>(
    header: String,
    registry: [Pipeline],
    requestedNames: [String],
    name: (Pipeline) -> String,
    fixture: (Int) -> Fixture,
    equivalenceFixture: Fixture,
    parts: (Pipeline, Fixture) -> OutputParts,
    measure: (Pipeline, Fixture) -> (TimingStats, retainedBytesPerIteration: Double)
) {
    let selected = requestedNames.compactMap { requested in
        registry.first { name($0) == requested }
    }
    guard !selected.isEmpty else {
        FileHandle.standardError.write(Data("no matching pipelines; use --list\n".utf8))
        exit(64)
    }

    print(header)
    print("Pipelines: \(selected.map(name).joined(separator: ", "))")

    if let mismatch = firstMismatch(selected.map { (name($0), parts($0, equivalenceFixture)) }) {
        print("❌ Output equivalence check FAILED — timings below compare different work:\n\(mismatch)\n")
    } else {
        print("✅ Output equivalence check passed (token-identical across pipelines)\n")
    }

    var results: [BenchResult] = []
    for size in options.sizes {
        let sizedFixture = fixture(size)
        for pipeline in selected {
            let (timing, retained) = measure(pipeline, sizedFixture)
            results.append(
                BenchResult(
                    pipeline: name(pipeline),
                    propertyCount: size,
                    timing: timing,
                    retainedBytesPerIteration: retained
                )
            )
        }
    }
    printTable(results: results, sizes: options.sizes, baselineName: name(selected[0]))
}

// MARK: - Workloads

if options.workloads.contains("generate") {
    runWorkload(
        header: "## Workload: generate — DictionaryStorage-style expansion (storage member + accessors per property)",
        registry: allPipelines,
        requestedNames: options.pipelineNames,
        name: { type(of: $0).name },
        fixture: { Fixtures.structDecl(propertyCount: $0) },
        equivalenceFixture: equivalenceFixture,
        parts: { pipeline, fixture in
            outputParts(of: pipeline.expand(properties: extractStoredProperties(from: fixture)))
        },
        measure: { pipeline, structDecl in
            measureLoop(warmup: options.warmup, iterations: options.iterations) {
                pipeline.expand(properties: extractStoredProperties(from: structDecl))
            }
        }
    )
}

if options.workloads.contains("edit") {
    runWorkload(
        header: "## Workload: edit — inject one _storage member into an existing N-property struct",
        registry: allEditPipelines,
        requestedNames: options.editPipelineNames,
        name: { type(of: $0).name },
        fixture: { Fixtures.structDecl(propertyCount: $0) },
        equivalenceFixture: equivalenceFixture,
        parts: { pipeline, fixture in outputParts(of: pipeline.edit(fixture)) },
        measure: { pipeline, structDecl in
            measureLoop(warmup: options.warmup, iterations: options.iterations) {
                pipeline.edit(structDecl)
            }
        }
    )
}

if options.workloads.contains("case-factory") {
    runWorkload(
        header: "## Workload: case-factory — one static factory per enum case (declaration shape, not accessor shape)",
        registry: allCaseFactoryPipelines,
        requestedNames: options.caseFactoryPipelineNames,
        name: { type(of: $0).name },
        fixture: { Fixtures.enumDecl(caseCount: $0) },
        equivalenceFixture: caseFactoryEquivalenceFixture,
        parts: { pipeline, fixture in
            outputParts(
                of: pipeline.expand(
                    cases: extractEnumCases(from: fixture), enumName: fixture.name.text))
        },
        measure: { pipeline, enumDecl in
            measureLoop(warmup: options.warmup, iterations: options.iterations) {
                pipeline.expand(cases: extractEnumCases(from: enumDecl), enumName: enumDecl.name.text)
            }
        }
    )
}

print("iterations=\(options.iterations) warmup=\(options.warmup) swift-syntax=\(swiftSyntaxVersion) (sink=\(sink))")
