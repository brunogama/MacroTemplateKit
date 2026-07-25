import Darwin
import SwiftSyntax

// MARK: - Process memory

/// The OS-level memory the process is charged for. `mstats().bytes_used`
/// reports malloc's *live* bytes, which drop as soon as an allocation is
/// freed; `phys_footprint` reports what the kernel still holds, which does
/// not. A real compiler pays the second one, so both are recorded — a case
/// where they diverge is itself the finding.
func physFootprintBytes() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
}

// MARK: - Lifetime models

/// What happens to a rendered tree once the expansion that produced it ends.
enum OutputLifetime: String {
    /// A macro plugin serialises its result to source text and hands that
    /// back to the compiler over the plugin protocol. Nothing tree-shaped
    /// outlives the expansion, so every arena it allocated becomes garbage
    /// immediately.
    case dropped

    /// What `measureLoop` does: every output is appended to an array and
    /// kept alive for the whole measurement. This is the model the headline
    /// "retained KB/run" number is built on.
    case retained
}

struct AccumulationSample {
    let pipeline: String
    let lifetime: OutputLifetime
    let expansions: Int
    let mallocDeltaBytes: Double
    let footprintDeltaBytes: Double
}

/// Serialises an expansion the way the plugin protocol does and returns only
/// a scalar, so the tree is unreachable the moment this returns.
@inline(never)
func serializeAndDrop(_ output: ExpansionOutput) -> Int {
    var length = output.storageMember.description.utf8.count
    for accessor in output.accessors {
        length &+= accessor.description.utf8.count
    }
    return length
}

/// Runs `expansions` expansions under one lifetime model and reports how much
/// memory the process gained across the whole run.
///
/// The question this answers is not "how big is one tree" but "does the cost
/// compound". If `dropped` stays flat as `expansions` grows by 64×, then a
/// plugin's peak memory is one expansion's worth regardless of how many
/// expansions a build performs, and any per-expansion difference between
/// pipelines never accumulates into anything a user could observe.
func measureAccumulation<Pipeline>(
    pipeline: Pipeline,
    name: String,
    lifetime: OutputLifetime,
    expansions: Int,
    settleIterations: Int,
    expand: (Pipeline) -> ExpansionOutput
) -> AccumulationSample {
    // Settle SwiftSyntax's process-wide state (keyword tables, interning
    // caches, allocator arenas) so first-touch growth is not attributed to
    // the measured run.
    for _ in 0..<settleIterations {
        consume(serializeAndDrop(expand(pipeline)))
    }

    let mallocBefore = mstats().bytes_used
    let footprintBefore = physFootprintBytes()

    switch lifetime {
    case .dropped:
        var checksum = 0
        for _ in 0..<expansions {
            checksum &+= serializeAndDrop(expand(pipeline))
        }
        sink &+= checksum & 1

    case .retained:
        var held: [ExpansionOutput] = []
        held.reserveCapacity(expansions)
        for _ in 0..<expansions {
            held.append(expand(pipeline))
        }
        let mallocAfter = mstats().bytes_used
        let footprintAfter = physFootprintBytes()
        consume(held)
        return AccumulationSample(
            pipeline: name,
            lifetime: lifetime,
            expansions: expansions,
            mallocDeltaBytes: Double(mallocAfter) - Double(mallocBefore),
            footprintDeltaBytes: Double(footprintAfter) - Double(footprintBefore)
        )
    }

    let mallocAfter = mstats().bytes_used
    let footprintAfter = physFootprintBytes()

    return AccumulationSample(
        pipeline: name,
        lifetime: lifetime,
        expansions: expansions,
        mallocDeltaBytes: Double(mallocAfter) - Double(mallocBefore),
        footprintDeltaBytes: Double(footprintAfter) - Double(footprintBefore)
    )
}

// MARK: - Reporting

func printAccumulationTable(_ samples: [AccumulationSample]) {
    print("| pipeline | lifetime | expansions | malloc Δ MB | footprint Δ MB | malloc Δ KB/expansion |")
    print("|---|---|---|---|---|---|")
    for sample in samples {
        let perExpansion = sample.mallocDeltaBytes / Double(sample.expansions) / 1024
        print(
            "| \(sample.pipeline) | \(sample.lifetime.rawValue) | \(sample.expansions) "
                + "| \(String(format: "%.2f", sample.mallocDeltaBytes / 1_048_576)) "
                + "| \(String(format: "%.2f", sample.footprintDeltaBytes / 1_048_576)) "
                + "| \(String(format: "%.1f", perExpansion)) |"
        )
    }
    print("")
}
