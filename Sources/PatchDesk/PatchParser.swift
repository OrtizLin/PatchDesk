import Foundation

/// A summary of one unified diff, produced without applying it.
/// Parses the `--- a/path` / `+++ b/path` file headers and the
/// `@@ -a,b +c,d @@` hunk headers emitted by Python's `difflib`,
/// which is what `issue_to_patch_agent/patcher.py` (`make_diff`) uses.
public struct DiffSummary: Equatable {
    /// Repo-relative paths touched by the diff, in order of appearance.
    public var files: [String] = []
    /// Number of `@@` hunks.
    public var hunks: Int = 0
    /// Added lines, excluding the `+++` file header.
    public var addedLines: Int = 0
    /// Removed lines, excluding the `---` file header.
    public var removedLines: Int = 0
    /// False when the text is not a well-formed unified diff.
    public var isValid: Bool = true
    /// Human-readable reason when `isValid` is false.
    public var error: String?

    public init() {}
}

public enum PatchParser {
    /// Parse unified-diff text into a `DiffSummary`.
    /// Never throws: malformed input yields `isValid == false` with an
    /// explanation in `error`, so the UI can show it instead of crashing.
    public static func parse(_ text: String) -> DiffSummary {
        var summary = DiffSummary()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summary.isValid = false
            summary.error = "Empty diff: nothing to parse."
            return summary
        }

        var insideHunk = false
        var sawFileHeader = false
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("diff --git ") {
                sawFileHeader = true
                insideHunk = false
            } else if line.hasPrefix("--- ") {
                sawFileHeader = true
                insideHunk = false
            } else if line.hasPrefix("+++ ") {
                // The new-file path is the file this hunk section touches.
                let path = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
                let cleaned = path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
                if cleaned != "/dev/null" && !summary.files.contains(cleaned) {
                    summary.files.append(cleaned)
                }
                insideHunk = false
            } else if line.hasPrefix("@@ ") {
                guard isHunkHeader(line) else {
                    summary.isValid = false
                    summary.error = "Malformed hunk header on line \(index + 1): \(line)"
                    return summary
                }
                summary.hunks += 1
                insideHunk = true
            } else if line.hasPrefix("+") {
                guard insideHunk else {
                    summary.isValid = false
                    summary.error = "Added line outside any hunk on line \(index + 1)."
                    return summary
                }
                summary.addedLines += 1
            } else if line.hasPrefix("-") {
                guard insideHunk else {
                    summary.isValid = false
                    summary.error = "Removed line outside any hunk on line \(index + 1)."
                    return summary
                }
                summary.removedLines += 1
            } else if line.hasPrefix(" ") || line.hasPrefix("\\") || line.isEmpty {
                // Context line, "\ No newline at end of file", or a blank
                // line inside a hunk: allowed only inside a hunk.
                guard insideHunk else {
                    summary.isValid = false
                    summary.error = "Content line outside any hunk on line \(index + 1)."
                    return summary
                }
            } else {
                // Any other line (e.g. "index ...", "new file mode ...")
                // is metadata between sections; it does not end a hunk,
                // but a bare content line is not expected either.
                if !sawFileHeader && !insideHunk {
                    summary.isValid = false
                    summary.error = "Unrecognised line before any diff header on line \(index + 1): \(line)"
                    return summary
                }
            }
            index += 1
        }

        if summary.files.isEmpty && summary.hunks == 0 {
            summary.isValid = false
            summary.error = "No file headers or hunks found: not a unified diff."
            return summary
        }
        return summary
    }

    /// A hunk header looks like `@@ -1,3 +1,4 @@` or `@@ -1 +1 @@`
    /// with an optional trailing function context.
    private static func isHunkHeader(_ line: String) -> Bool {
        // Split on "@@" and require two numeric ranges.
        let parts = line.split(separator: "@@", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        let ranges = parts[1].trimmingCharacters(in: .whitespaces)
        let rangeParts = ranges.split(separator: " ")
        guard rangeParts.count >= 2 else { return false }
        for rangePart in rangeParts.prefix(2) {
            guard rangePart.hasPrefix("-") || rangePart.hasPrefix("+") else { return false }
            let numbers = rangePart.dropFirst().split(separator: ",")
            guard numbers.count >= 1 && numbers.count <= 2 else { return false }
            for number in numbers {
                guard Int(number) != nil else { return false }
            }
        }
        return true
    }
}
