import Foundation

/// Locates the Issue-to-Patch Agent CLI folder and runs it with
/// `Foundation.Process`. The CLI itself is never bundled, copied, or
/// modified by PatchDesk: it stays in its own folder, and PatchDesk
/// only invokes it and reads the `patch.diff` / `report.md` it writes
/// into a fresh temporary directory.
public struct RunOutcome {
    public var status: RunStatus
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
    /// The generated patch text, when the run produced one.
    public var patchText: String?
    /// The generated report text (`report.md`), when the run wrote one.
    public var reportText: String?
    /// Parsed summary of `patchText`, when a patch exists and parses.
    public var diffSummary: DiffSummary?

    public init(status: RunStatus, exitCode: Int32, stdout: String, stderr: String,
                patchText: String? = nil, reportText: String? = nil, diffSummary: DiffSummary? = nil) {
        self.status = status
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.patchText = patchText
        self.reportText = reportText
        self.diffSummary = diffSummary
    }
}

public enum CLIRunner {
    /// The file that must exist inside a valid CLI folder.
    public static let cliEntryPoint = "issue_to_patch_agent/cli.py"

    /// True when `folder` contains the Issue-to-Patch Agent CLI.
    public static func isValidCLIFolder(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(cliEntryPoint).path)
    }

    /// Default CLI folder candidates, in order:
    /// 1. A folder named `issue-to-patch-agent` next to the current
    ///    working directory (the layout when both projects are checked
    ///    out side by side, e.g. under `ai-agent-portfolio/`).
    /// 2. A folder named `issue-to-patch-agent` inside the current
    ///    working directory.
    /// Returns the first candidate that actually contains the CLI, or
    /// nil when neither does — the UI then asks the user to choose.
    public static func defaultCLIFolder() -> URL? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.deletingLastPathComponent().appendingPathComponent("issue-to-patch-agent"),
            cwd.appendingPathComponent("issue-to-patch-agent")
        ]
        return candidates.first { isValidCLIFolder($0) }
    }

    /// Run the CLI once, synchronously. Call from a background queue:
    /// this blocks until the process exits.
    /// - Parameters:
    ///   - cliFolder: folder containing the Issue-to-Patch Agent CLI.
    ///   - issueFile: the `.md` issue file to patch.
    ///   - repoFolder: the repo folder the patch targets.
    ///   - dryRun: true uses the offline rule-based patcher (no key,
    ///     no network); false uses the LLM path and needs `LLM_API_KEY`.
    public static func run(cliFolder: URL, issueFile: URL, repoFolder: URL, dryRun: Bool) -> RunOutcome {
        guard isValidCLIFolder(cliFolder) else {
            return RunOutcome(
                status: .failed, exitCode: -1, stdout: "",
                stderr: "CLI folder is missing \(cliEntryPoint). Choose the folder that contains the issue-to-patch-agent project."
            )
        }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchDesk-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        } catch {
            return RunOutcome(status: .failed, exitCode: -1, stdout: "",
                              stderr: "Could not create a temporary output folder: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let outDiff = outputDir.appendingPathComponent("patch.diff")
        let outMD = outputDir.appendingPathComponent("report.md")
        let outJSON = outputDir.appendingPathComponent("report.json")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3", "-m", "issue_to_patch_agent.cli",
            "--issue", issueFile.path,
            "--repo", repoFolder.path,
            dryRun ? "--dry-run" : "--no-dry-run",
            "--out-diff", outDiff.path,
            "--out-md", outMD.path,
            "--out-json", outJSON.path
        ]
        process.currentDirectoryURL = cliFolder

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return RunOutcome(status: .failed, exitCode: -1, stdout: "",
                              stderr: "Could not start python3: \(error.localizedDescription)")
        }
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let patchText = try? String(contentsOf: outDiff, encoding: .utf8)
        let reportText = try? String(contentsOf: outMD, encoding: .utf8)
        let status = RunStatus.from(exitCode: process.terminationStatus, stdout: stdout, patchWritten: patchText != nil)
        let diffSummary = patchText.map { PatchParser.parse($0) }
        return RunOutcome(status: status, exitCode: process.terminationStatus,
                          stdout: stdout, stderr: stderr,
                          patchText: patchText, reportText: reportText, diffSummary: diffSummary)
    }
}
