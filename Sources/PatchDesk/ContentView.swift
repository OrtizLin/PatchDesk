import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - View model

@MainActor
final class PatchDeskViewModel: ObservableObject {
    @Published var issueFile: URL?
    @Published var repoFolder: URL?
    @Published var cliFolder: URL?
    @Published var dryRun = true
    @Published var isRunning = false
    @Published var outcome: RunOutcome?
    @Published var errorMessage: String?
    @Published var savedMessage: String?

    init() {
        self.cliFolder = CLIRunner.defaultCLIFolder()
    }

    var canRun: Bool {
        issueFile != nil && repoFolder != nil && cliFolder != nil && !isRunning
    }

    var cliFolderIsValid: Bool {
        guard let cliFolder else { return false }
        return CLIRunner.isValidCLIFolder(cliFolder)
    }

    func run() {
        guard let issueFile, let repoFolder, let cliFolder, !isRunning else { return }
        guard CLIRunner.isValidCLIFolder(cliFolder) else {
            errorMessage = "CLI folder is missing \(CLIRunner.cliEntryPoint). Choose the folder that contains the issue-to-patch-agent project."
            return
        }
        isRunning = true
        outcome = nil
        errorMessage = nil
        savedMessage = nil
        Task.detached { [dryRun] in
            let result = CLIRunner.run(cliFolder: cliFolder, issueFile: issueFile, repoFolder: repoFolder, dryRun: dryRun)
            await MainActor.run {
                self.outcome = result
                self.isRunning = false
                if result.status == .failed && result.stderr.isEmpty == false {
                    self.errorMessage = result.stderr
                }
            }
        }
    }

    func copyPatch() {
        guard let patch = outcome?.patchText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(patch, forType: .string)
        savedMessage = "Patch copied to the clipboard."
    }

    func savePatch() {
        guard let patch = outcome?.patchText else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "patch.diff"
        panel.allowedContentTypes = [.init(filenameExtension: "diff")].compactMap { $0 }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try patch.write(to: url, atomically: true, encoding: .utf8)
            savedMessage = "Patch saved to \(url.lastPathComponent)."
        } catch {
            errorMessage = "Could not save the patch: \(error.localizedDescription)"
        }
    }
}

// MARK: - File pickers (AppKit panels; SwiftUI has no folder picker)

enum PanelPicker {
    static func pickFile(allowedExtensions: [String], prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.prompt = prompt
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func pickFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

// MARK: - View

struct ContentView: View {
    @StateObject private var model = PatchDeskViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            pickers
            optionsRow
            runRow
            statusSection
            resultsSection
            Spacer()
            footer
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PatchDesk").font(.largeTitle).bold()
            Text("A patch draft, reviewed before anything is applied. Powered by the Issue-to-Patch Agent CLI — dry-run needs no key and no network.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var pickers: some View {
        Group {
            pickerRow(label: "Issue file", value: model.issueFile?.path, placeholder: "Choose an issue .md file…") {
                if let url = PanelPicker.pickFile(allowedExtensions: ["md"], prompt: "Choose Issue") {
                    model.issueFile = url
                }
            }
            pickerRow(label: "Repo folder", value: model.repoFolder?.path, placeholder: "Choose the repo folder to patch…") {
                if let url = PanelPicker.pickFolder(prompt: "Choose Repo") {
                    model.repoFolder = url
                }
            }
            pickerRow(label: "CLI folder", value: model.cliFolder?.path, placeholder: "Choose the issue-to-patch-agent folder…") {
                if let url = PanelPicker.pickFolder(prompt: "Choose CLI Folder") {
                    model.cliFolder = url
                }
            }
            if let cliFolder = model.cliFolder, !model.cliFolderIsValid {
                Label("That folder does not contain \(CLIRunner.cliEntryPoint). Pick the folder that holds the issue-to-patch-agent project.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
    }

    private func pickerRow(label: String, value: String?, placeholder: String, choose: @escaping () -> Void) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .trailing)
            Text(value ?? placeholder)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(value == nil ? .secondary : .primary)
            Spacer()
            Button("Choose…", action: choose)
        }
    }

    private var optionsRow: some View {
        HStack {
            Toggle("Dry-run (offline rules, no key)", isOn: $model.dryRun)
            Spacer()
            Text(model.dryRun ? "Rule-based patcher" : "LLM mode — needs LLM_API_KEY in your shell")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var runRow: some View {
        HStack {
            Button(model.isRunning ? "Running…" : "Run") { model.run() }
                .disabled(!model.canRun)
                .keyboardShortcut(.defaultAction)
            if model.isRunning {
                ProgressView().scaleEffect(0.8)
            }
            Spacer()
            if let saved = model.savedMessage {
                Text(saved).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        Group {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.octagon")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if let outcome = model.outcome {
                HStack(spacing: 8) {
                    Text(outcome.status.displayText).bold()
                    if let summary = outcome.diffSummary, summary.isValid {
                        Text("\(summary.files.count) file(s) · \(summary.hunks) hunk(s) · +\(summary.addedLines) −\(summary.removedLines)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if outcome.patchText != nil {
                        Button("Copy Patch") { model.copyPatch() }
                        Button("Save Patch…") { model.savePatch() }
                    }
                }
            }
        }
    }

    private var resultsSection: some View {
        Group {
            if let outcome = model.outcome {
                TabView {
                    ScrollView {
                        Text(outcome.patchText ?? "No patch was produced for this issue.")
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .tabItem { Label("Patch", systemImage: "doc.text") }
                    ScrollView {
                        Text(outcome.reportText ?? outcome.stdout)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .tabItem { Label("Report", systemImage: "list.clipboard") }
                }
            } else {
                Text("Run an issue to see its patch and report here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var footer: some View {
        Text("The CLI validates every patch in a temporary copy and never applies, commits, or merges. Review patch.diff, then run `git apply patch.diff` yourself if you agree with it.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
