import XCTest
@testable import PatchDesk

/// Tests for `RunStatus.from`, the mapping from a finished CLI run
/// (exit code + report text + whether patch.diff exists) to the status
/// the UI shows. The strings mirror `issue_to_patch_agent/agent.py`.
final class RunStatusTests: XCTestCase {
    private let readyReport = """
        # Patch Report: Empty average
        Mode: dry-run (prompt issue-patch-v1)
        Status: patch ready for human review (not applied to the repo)
        """

    func testPatchedWhenReadyAndPatchWritten() {
        XCTAssertEqual(
            RunStatus.from(exitCode: 0, stdout: readyReport, patchWritten: true),
            .patched
        )
    }

    func testUnknownWhenReadyButNoPatchFile() {
        // The report says ready but no patch.diff exists: contradictory,
        // so the UI must not claim success.
        XCTAssertEqual(
            RunStatus.from(exitCode: 0, stdout: readyReport, patchWritten: false),
            .unknown
        )
    }

    func testNoPatchStatus() {
        let stdout = "Status: no patch: no file looks relevant to this issue"
        XCTAssertEqual(RunStatus.from(exitCode: 0, stdout: stdout, patchWritten: false), .noPatch)
    }

    func testRejectedStatus() {
        let stdout = "Status: patch rejected: diff touches files outside the located set"
        XCTAssertEqual(RunStatus.from(exitCode: 0, stdout: stdout, patchWritten: false), .rejected)
    }

    func testNonZeroExitIsFailed() {
        XCTAssertEqual(RunStatus.from(exitCode: 1, stdout: readyReport, patchWritten: false), .failed)
    }

    func testErrorLineIsFailedEvenWithExitZero() {
        XCTAssertEqual(RunStatus.from(exitCode: 0, stdout: "Error: repo folder not found", patchWritten: false), .failed)
    }

    func testUnrecognisedStatusIsUnknown() {
        XCTAssertEqual(RunStatus.from(exitCode: 0, stdout: "Status: something new", patchWritten: false), .unknown)
    }

    func testDisplayTextIsNonEmptyForEveryCase() {
        for status in RunStatus.allCases {
            XCTAssertFalse(status.displayText.isEmpty, "\(status) has no display text")
        }
    }
}
