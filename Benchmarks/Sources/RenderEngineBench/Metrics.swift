import Darwin
import SwiftSyntax

/// Prevents the optimizer from discarding pipeline output.
var sink: Int = 0

@inline(never)
func consume<T>(_ output: T) {
    withExtendedLifetime(output) { sink &+= 1 }
}

struct TimingStats {
    let minMicros: Double
    let p50Micros: Double
    let p90Micros: Double
    let meanMicros: Double
}

struct BenchResult {
    let pipeline: String
    let propertyCount: Int
    let timing: TimingStats
    let retainedBytesPerIteration: Double
}

private func micros(_ duration: Duration) -> Double {
    let (seconds, attoseconds) = duration.components
    return Double(seconds) * 1_000_000 + Double(attoseconds) / 1_000_000_000_000
}

/// Times `iterations` runs of `body` individually (after `warmup` discarded
/// runs) so percentiles are available, then runs a separate retained-memory
/// pass: outputs are kept alive while malloc `bytes_used` is sampled
/// before/after, approximating the syntax-arena footprint one run leaves behind.
func measureLoop<Output>(
    warmup: Int,
    iterations: Int,
    memoryIterations: Int = 32,
    _ body: () -> Output
) -> (TimingStats, retainedBytesPerIteration: Double) {
    let clock = ContinuousClock()

    for _ in 0..<warmup {
        consume(body())
    }

    var samples: [Double] = []
    samples.reserveCapacity(iterations)
    for _ in 0..<iterations {
        let start = clock.now
        let output = body()
        let elapsed = clock.now - start
        consume(output)
        samples.append(micros(elapsed))
    }
    samples.sort()

    let stats = TimingStats(
        minMicros: samples.first ?? 0,
        p50Micros: samples[samples.count / 2],
        p90Micros: samples[min(samples.count - 1, Int(Double(samples.count) * 0.9))],
        meanMicros: samples.reduce(0, +) / Double(samples.count)
    )

    var retained: [Output] = []
    retained.reserveCapacity(memoryIterations)
    let before = mstats().bytes_used
    for _ in 0..<memoryIterations {
        retained.append(body())
    }
    let after = mstats().bytes_used
    let retainedPerIteration = (Double(after) - Double(before)) / Double(memoryIterations)
    retained.removeAll()

    return (stats, retainedPerIteration)
}

// MARK: - Output equivalence

private func tokenStream(_ node: some SyntaxProtocol) -> String {
    node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

/// Labeled token streams for one pipeline's output — the unit of comparison.
typealias OutputParts = [(label: String, stream: String)]

func outputParts(of output: ExpansionOutput) -> OutputParts {
    [("storage member", tokenStream(output.storageMember))]
        + output.accessors.enumerated().map { ("accessor #\($0.offset)", tokenStream($0.element)) }
}

func outputParts(of output: DeclSyntax) -> OutputParts {
    [("edited struct", tokenStream(output))]
}

/// Compares every pipeline's output parts against the first pipeline's; all
/// must be token-identical (trivia excluded). Returns a human-readable
/// mismatch description, or nil when everything matches.
func firstMismatch(_ outputs: [(name: String, parts: OutputParts)]) -> String? {
    guard let reference = outputs.first else { return nil }

    for candidate in outputs.dropFirst() {
        guard candidate.parts.count == reference.parts.count else {
            return "output part count differs: \(reference.name)=\(reference.parts.count) "
                + "\(candidate.name)=\(candidate.parts.count)"
        }
        for (referencePart, part) in zip(reference.parts, candidate.parts)
        where referencePart.stream != part.stream {
            return """
                \(part.label) differs between \(reference.name) and \(candidate.name):
                  \(reference.name): \(referencePart.stream.prefix(200))
                  \(candidate.name): \(part.stream.prefix(200))
                """
        }
    }
    return nil
}
