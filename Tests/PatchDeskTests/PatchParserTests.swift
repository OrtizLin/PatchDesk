import XCTest
@testable import PatchDesk

/// Tests for `PatchParser`, the pure unified-diff parser used by the
/// Patch tab's summary line. No file system, no Process, no UI.
final class PatchParserTests: XCTestCase {
    private let singleFileDiff = """
        --- a/examples/sample_repo/calc.py
        +++ b/examples/sample_repo/calc.py
        @@ -1,4 +1,6 @@
         def average(numbers):
        +    if not numbers:
        +        return 0.0
             return sum(numbers) / len(numbers)
        """

    func testParsesSingleFileDiff() {
        let summary = PatchParser.parse(singleFileDiff)
        XCTAssertTrue(summary.isValid)
        XCTAssertEqual(summary.files, ["examples/sample_repo/calc.py"])
        XCTAssertEqual(summary.hunks, 1)
        XCTAssertEqual(summary.addedLines, 2)
        XCTAssertEqual(summary.removedLines, 0)
    }

    func testParsesMultiFileDiff() {
        let diff = """
            diff --git a/a.py b/a.py
            --- a/a.py
            +++ b/a.py
            @@ -1 +1 @@
            -print("hi")
            +import logging
            diff --git a/b.py b/b.py
            --- a/b.py
            +++ b/b.py
            @@ -5,2 +5,3 @@
             x = 1
            +y = 2
             z = 3
            """
        let summary = PatchParser.parse(diff)
        XCTAssertTrue(summary.isValid)
        XCTAssertEqual(summary.files, ["a.py", "b.py"])
        XCTAssertEqual(summary.hunks, 2)
        XCTAssertEqual(summary.addedLines, 2)
        XCTAssertEqual(summary.removedLines, 1)
    }

    func testHeaderLinesAreNotCountedAsChanges() {
        // The +++ / --- headers must not inflate the line counts.
        let summary = PatchParser.parse(singleFileDiff)
        XCTAssertEqual(summary.addedLines, 2)
        XCTAssertEqual(summary.removedLines, 0)
    }

    func testEmptyDiffIsInvalid() {
        let summary = PatchParser.parse("")
        XCTAssertFalse(summary.isValid)
        XCTAssertNotNil(summary.error)
    }

    func testAddedLineOutsideHunkIsInvalid() {
        let diff = """
            --- a/a.py
            +++ b/a.py
            +stray line with no hunk header
            """
        let summary = PatchParser.parse(diff)
        XCTAssertFalse(summary.isValid)
        XCTAssertTrue(summary.error?.contains("outside any hunk") ?? false)
    }

    func testMalformedHunkHeaderIsInvalid() {
        let diff = """
            --- a/a.py
            +++ b/a.py
            @@ not a range @@
            +x = 1
            """
        let summary = PatchParser.parse(diff)
        XCTAssertFalse(summary.isValid)
        XCTAssertTrue(summary.error?.contains("Malformed hunk header") ?? false)
    }

    func testTextWithNoDiffStructureIsInvalid() {
        let summary = PatchParser.parse("just some prose, not a diff at all")
        XCTAssertFalse(summary.isValid)
        XCTAssertNotNil(summary.error)
    }
}
