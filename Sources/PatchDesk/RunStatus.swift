import Foundation

/// The outcome of one Issue-to-Patch CLI run, derived from the process
/// exit code and the `Status:` line the CLI prints in its report.
/// The mapping mirrors the status strings produced by
/// `issue_to_patch_agent/agent.py` (`run_issue`).
public enum RunStatus: String, Equatable, CaseIterable {
    /// The CLI validated a patch and wrote `patch.diff`.
    case patched
    /// The CLI ran fine but proposed no patch (no relevant file, or no
    /// supported dry-run pattern matched).
    case noPatch
    /// The CLI drafted a patch but validation rejected it.
    case rejected
    /// The CLI exited non-zero or printed an `Error:` line.
    case failed
    /// The CLI exited 0 but its status line could not be recognised.
    case unknown

    public var displayText: String {
        switch self {
        case .patched: return "Patch ready — validated, not applied"
        case .noPatch: return "No patch proposed"
        case .rejected: return "Patch rejected by validation"
        case .failed: return "Run failed"
        case .unknown: return "Unknown result"
        }
    }

    /// Map a finished CLI run to a status.
    /// - Parameters:
    ///   - exitCode: the process termination status (0 means success).
    ///   - stdout: the CLI's standard output, which contains the report.
    ///   - patchWritten: whether the run produced a `patch.diff` file.
    public static func from(exitCode: Int32, stdout: String, patchWritten: Bool) -> RunStatus {
        if exitCode != 0 {
            return .failed
        }
        if stdout.contains("Error:") {
            return .failed
        }
        let statusLine = stdout
            .split(separator: "\n")
            .first { $0.hasPrefix("Status:") }
            .map(String.init) ?? ""
        if statusLine.contains("patch ready for human review") {
            return patchWritten ? .patched : .unknown
        }
        if statusLine.contains("no patch:") {
            return .noPatch
        }
        if statusLine.contains("patch rejected:") {
            return .rejected
        }
        return .unknown
    }
}
