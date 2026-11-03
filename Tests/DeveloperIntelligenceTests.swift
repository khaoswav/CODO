import Foundation

@main
struct DeveloperIntelligenceTests {
    @MainActor
    static func main() throws {
        try testSwiftModuleResolution()
        try testRelativeModuleResolution()
        try testGraphLayoutPreservesDependencyDirection()
        try testExternalAndAmbiguousImportsAreExcluded()
        try testProjectScanBuildsGraphAndFindings()
        try testBuildFailureFingerprinting()
        try testAgentWorkflowTransitionsAndPersistence()
        try testReviewWithoutAppliedChangesCancelsWorkflow()
        try testUnifiedDiffParserAndPathSafety()
        try testProjectFileChangeStaleReviewProtection()
        try testXcodeBuildPlanning()
        try testWebBuildPlanning()
        try testGitWorkflowInputPolicies()
        print("PASS: 13 Developer Intelligence, Agent Orchestrator, Diff, Build and Git regression groups")
    }

    static func testSwiftModuleResolution() throws {
        let files = [
            IntelligenceFile(path: "Sources/App.swift", language: "Swift", lineCount: 4, byteCount: 80),
            IntelligenceFile(path: "Sources/AudioEngine.swift", language: "Swift", lineCount: 8, byteCount: 120)
        ]
        let dependencies = [
            IntelligenceDependency(source: "Sources/App.swift", target: "AudioEngine", kind: "import")
        ]
        let edges = DeveloperIntelligenceService.resolveGraph(files: files, dependencies: dependencies)
        try expect(edges.count == 1, "Swift local module import should resolve")
        try expect(edges[0].targetFile == "Sources/AudioEngine.swift", "Swift edge target should match the local source file")
    }

    static func testRelativeModuleResolution() throws {
        let files = [
            IntelligenceFile(path: "Web/src/main.ts", language: "TypeScript", lineCount: 5, byteCount: 90),
            IntelligenceFile(path: "Web/src/lib/helpers.ts", language: "TypeScript", lineCount: 3, byteCount: 50)
        ]
        let dependencies = [
            IntelligenceDependency(source: "Web/src/main.ts", target: "./lib/helpers", kind: "module")
        ]
        let edges = DeveloperIntelligenceService.resolveGraph(files: files, dependencies: dependencies)
        try expect(edges.count == 1, "Relative TypeScript import should resolve")
        try expect(edges[0].targetFile == "Web/src/lib/helpers.ts", "Relative import should resolve against source directory")
    }

    static func testGraphLayoutPreservesDependencyDirection() throws {
        let files = [
            IntelligenceFile(path: "Sources/App.swift", language: "Swift", lineCount: 4, byteCount: 80),
            IntelligenceFile(path: "Sources/AudioEngine.swift", language: "Swift", lineCount: 8, byteCount: 120),
            IntelligenceFile(path: "Sources/AudioUnit.swift", language: "Swift", lineCount: 3, byteCount: 40)
        ]
        let edges = [
            IntelligenceGraphEdge(sourceFile: "Sources/App.swift", targetFile: "Sources/AudioEngine.swift",
                                  importedSymbol: "AudioEngine", kind: "import"),
            IntelligenceGraphEdge(sourceFile: "Sources/AudioEngine.swift", targetFile: "Sources/AudioUnit.swift",
                                  importedSymbol: "AudioUnit", kind: "import")
        ]
        let nodes = IntelligenceGraphLayout.layout(files: files, edges: edges)
        let byPath = Dictionary(uniqueKeysWithValues: nodes.map { ($0.path, $0) })
        try expect(nodes.count == 3, "Graph layout should include all connected source files")
        try expect(byPath["Sources/App.swift"]!.layer < byPath["Sources/AudioEngine.swift"]!.layer,
                   "Importing files should appear before their local dependencies")
        try expect(byPath["Sources/AudioEngine.swift"]!.x < byPath["Sources/AudioUnit.swift"]!.x,
                   "Graph x positions should follow dependency direction")
    }

    static func testExternalAndAmbiguousImportsAreExcluded() throws {
        let files = [
            IntelligenceFile(path: "App.swift", language: "Swift", lineCount: 2, byteCount: 20),
            IntelligenceFile(path: "First/Shared.swift", language: "Swift", lineCount: 2, byteCount: 20),
            IntelligenceFile(path: "Second/Shared.swift", language: "Swift", lineCount: 2, byteCount: 20)
        ]
        let dependencies = [
            IntelligenceDependency(source: "App.swift", target: "Foundation", kind: "import"),
            IntelligenceDependency(source: "App.swift", target: "Shared", kind: "import")
        ]
        let edges = DeveloperIntelligenceService.resolveGraph(files: files, dependencies: dependencies)
        try expect(edges.isEmpty, "External and ambiguous imports must not create guessed graph edges")
    }

    static func testProjectScanBuildsGraphAndFindings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-Intelligence-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "import AudioEngine\n// TODO: cover recording failure\n".write(
            to: root.appendingPathComponent("App.swift"), atomically: true, encoding: .utf8
        )
        try "struct AudioEngine {}\n".write(
            to: root.appendingPathComponent("AudioEngine.swift"), atomically: true, encoding: .utf8
        )
        let subfolder = root.appendingPathComponent("Sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "import { helper } from \"./Sub/helpers\";\n".write(
            to: root.appendingPathComponent("main.ts"), atomically: true, encoding: .utf8
        )
        try "export const helper = true;\n".write(
            to: subfolder.appendingPathComponent("helpers.ts"), atomically: true, encoding: .utf8
        )
        let report = DeveloperIntelligenceService.analyze(root: root, projectName: "Fixture")
        print("SCAN FILES: " + report.files.map(\.path).joined(separator: ", "))
        try expect(report.files.count == 4, "Scanner should index Swift and TypeScript source files, found \(report.files.count)")
        try expect(report.graphEdges.count == 2, "Scanner should return resolved Swift and TypeScript local graph edges")
        try expect(report.findings.contains(where: { $0.title == "Pending code note" }), "Scanner should detect TODO notes")
    }

    static func testBuildFailureFingerprinting() throws {
        let log = """
        Sources/App.swift:42:8: error: Cannot find type 'AudioUnit' in scope
        Sources/App.swift:91:8: error: Cannot find type 'AudioUnit' in scope
        Sources/Keys.swift:2:3: error: API_KEY=super-secret-123
        Build failed.
        """
        let diagnostics = BuildFailureAnalyzer.extractDiagnostics(from: log)
        try expect(diagnostics.count == 2, "Repeated compiler errors should normalize while distinct errors remain")
        try expect(diagnostics[0].category == "Missing symbol or type",
                   "Missing-symbol compiler errors should receive a diagnosis category")
        try expect(!diagnostics.contains(where: { $0.message.contains("super-secret-123") }),
                   "Credential-like values must be redacted from build memory")
        let safeLog = BuildFailureAnalyzer.sanitizeLog("API_KEY=super-secret-123\\nAuthorization: Bearer hidden-token-value")
        try expect(!safeLog.contains("super-secret-123") && !safeLog.contains("hidden-token-value"),
                   "Credential-like values must be redacted before Goose log handoff")

        let ansiAndWindowsLog = "\u{001B}[31mAssets/Player.cs(8,4): error CS0246: Missing Unity type\u{001B}[0m\\r\\nMSBuild error MSB3027: Retry limit exceeded\\r\\n"
        let mixedDiagnostics = BuildFailureAnalyzer.extractDiagnostics(from: ansiAndWindowsLog)
        try expect(mixedDiagnostics.count == 2,
                   "ANSI-colored Unity and MSBuild errors with CRLF endings must both be extracted")
        try expect(mixedDiagnostics[0].category == "Missing symbol or type",
                   "Unity CS diagnostics should retain their missing-symbol classification")
        try expect(BuildFailureAnalyzer.extractDiagnostics(from: "warning MSB3027: retrying copy").isEmpty,
                   "MSBuild warnings must not be recorded as build errors")
        try expect(BuildFailureAnalyzer.extractDiagnostics(from: ansiAndWindowsLog, limit: 0).isEmpty,
                   "A zero diagnostic limit must return no diagnostics")
        try expect(BuildFailureAnalyzer.extractDiagnostics(from: ansiAndWindowsLog, limit: 1).count == 1,
                   "Diagnostic extraction must respect its configured result limit")
        let ansiSafeLog = BuildFailureAnalyzer.sanitizeLog("\u{001B}[31mAPI_KEY=super-secret-123\u{001B}[0m")
        try expect(!ansiSafeLog.contains("\u{001B}") && !ansiSafeLog.contains("super-secret-123"),
                   "Sanitized Goose handoff logs must remove terminal color codes and secrets")
        let merged = BuildFailureAnalyzer.merge([diagnostics[0], diagnostics[0]], into: [])
        try expect(merged.count == 1, "Repeated signatures should merge into one memory pattern")
        try expect(merged[0].occurrenceCount == 2, "Pattern occurrence count should increase")
    }

    @MainActor
    static func testAgentWorkflowTransitionsAndPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-Agent-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appendingPathComponent("workflow.json")
        let project = CODOProject(name: "Fixture", path: directory.path, kind: .macOS)
        let store = AgentOrchestratorStore(storageURL: storage)
        let plan = IntelligenceTaskPlanner.makePlan(for: "Add a sample feature")
        store.start(project: project, request: "Add a sample feature", plan: plan)

        try expect(store.activeWorkflow?.status == .awaitingApproval &&
                   store.activeWorkflow?.steps.first?.status == .awaitingApproval,
                   "A new workflow must wait for the user's initial Goose approval")
        store.approveCurrentStep()
        try expect(store.activeWorkflow?.steps.first?.status == .running, "Workflow should run after explicit approval")
        try expect(store.activeWorkflow?.steps.first?.attemptCount == 1, "First stage should record its initial attempt")
        store.completeCurrentAndAdvance("Architecture inspected.", output: "ARCHITECTURE_CONTEXT API_KEY=super-secret-agent-output")
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Plan") })?.status == .running,
                   "Orchestrator should run the planning stage after architecture")
        store.completeCurrentAndAdvance("Implementation plan prepared.", output: "PLAN_CONTEXT: preserve the architecture decisions.")
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Implement") })?.status == .running,
                   "Orchestrator should enter implementation before Goose runs")
        store.proposalReady()
        try expect(store.activeWorkflow?.steps.first(where: { $0.title == "Review the proposal" })?.status == .running,
                   "Independent reviewer stage should run after implementation")
        store.completeCurrentAndAdvance("AI review complete.")
        try expect(store.activeWorkflow?.steps.first(where: { $0.title == "Review and approve" })?.status == .awaitingApproval,
                   "Human patch review must wait for explicit approval")
        store.reviewCompleted(appliedCount: 1, rejectedCount: 0)
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Build") })?.status == .awaitingApproval,
                   "Build stage must wait for explicit approval")
        store.approveCurrentStep()
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Build") })?.attemptCount == 1,
                   "Approval should begin and count the build attempt")
        store.buildFailed("Compiler error: missing symbol", output: "error: API_KEY=super-secret-build-output")
        try expect(store.activeWorkflow?.status == .failed, "Build failure should fail the workflow")
        let failedBuildStep = store.activeWorkflow?.steps.first(where: { $0.title.contains("Build") })
        try expect(failedBuildStep?.errorMessage != nil, "Failed steps should preserve a visible error summary")
        try expect(failedBuildStep?.outputExcerpt?.contains("super-secret-build-output") == false,
                   "Build output excerpts must redact credentials before persistence")

        // Simulate relaunch: failed workflows are restored as history and can be resumed explicitly.
        let recovered = AgentOrchestratorStore(storageURL: storage)
        try expect(recovered.activeWorkflow == nil, "A failed workflow should not resume automatically after relaunch")
        recovered.resumeForFix()
        let resumedWorkflow = recovered.activeWorkflow
        let implementationStatus = resumedWorkflow?.steps.first(where: { $0.title.contains("Implement") })?.status
        try expect(implementationStatus == .running,
                   "Fix retry should reselect the persisted failed workflow and restart at implementation; workflows=\(recovered.workflows.count), active=\(String(describing: resumedWorkflow?.status)), implementation=\(String(describing: implementationStatus))")
        recovered.proposalReady()
        recovered.completeCurrentAndAdvance("AI review complete.")
        recovered.reviewCompleted(appliedCount: 1, rejectedCount: 0)
        recovered.approveCurrentStep()
        recovered.buildSucceeded()
        try expect(recovered.activeWorkflow == nil, "Successful build should close the active workflow")
        let restored = AgentOrchestratorStore(storageURL: storage)
        try expect(restored.workflows.first?.status == .succeeded, "Completed workflow should persist across launches")
        try expect(restored.workflows.first?.steps.first?.outputExcerpt?.contains("super-secret") == false,
                   "Agent step output should redact credentials before local persistence")
    }

    @MainActor
    static func testReviewWithoutAppliedChangesCancelsWorkflow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-Agent-Cancel-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let project = CODOProject(name: "Fixture", path: directory.path, kind: .macOS)
        let store = AgentOrchestratorStore(storageURL: directory.appendingPathComponent("workflow.json"))
        store.start(project: project, request: "Add a sample feature",
                    plan: IntelligenceTaskPlanner.makePlan(for: "Add a sample feature"))
        store.approveCurrentStep()
        store.completeCurrentAndAdvance("Architecture inspected.")
        store.completeCurrentAndAdvance("Plan prepared.")
        store.completeCurrentAndAdvance("Diff proposed.")
        store.proposalReady()
        try expect(store.activeWorkflow?.steps.first(where: { $0.title == "Review and approve" })?.status == .awaitingApproval,
                   "Patch review must be approval-gated")
        store.reviewCompleted(appliedCount: 0, rejectedCount: 1)
        try expect(store.activeWorkflow == nil, "A fully rejected patch should close the workflow")
        try expect(store.workflows.first?.status == .cancelled,
                   "A workflow with no applied changes must be cancelled, not reported as successful")
        try expect(store.workflows.first?.steps.contains(where: { $0.status == .cancelled }) == true,
                   "Downstream steps should be marked cancelled when no patch is applied")
        try expect(store.workflows.first?.steps.allSatisfy({ $0.status != .pending }) == true,
                   "Cancelled workflows should not leave pending steps behind")
    }


    static func testUnifiedDiffParserAndPathSafety() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-Diff-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("App.swift")
        try "let title = \"Old\"\nprint(\"old\")\n".write(to: source, atomically: true, encoding: .utf8)
        let project = CODOProject(name: "Diff Fixture", path: root.path, kind: .macOS)
        let patch = """
        diff --git a/App.swift b/App.swift
        --- a/App.swift
        +++ b/App.swift
        @@ -1,2 +1,2 @@
         let title = "Old"
        -print("old")
        +print("new")
        """
        let changes = try AIUnifiedDiffParser.parse(patch, project: project, root: root)
        try expect(changes.count == 1, "A valid single-file unified diff should produce one review item")
        try expect(changes[0].relativePath == "App.swift", "Diff review should preserve a project-relative path")
        try expect(changes[0].proposedText == "let title = \"Old\"\nprint(\"new\")\n",
                   "Diff application should preserve unchanged lines and trailing newline")

        let traversal = """
        --- a/../outside.swift
        +++ b/../outside.swift
        @@ -1 +1 @@
        -old
        +new
        """
        do {
            _ = try AIUnifiedDiffParser.parse(traversal, project: project, root: root)
            throw TestFailure.assertion("Parent-directory traversal must be rejected")
        } catch AIUnifiedDiffError.unsafePath(_) {
            // Expected: project-root escape rejected.
        }

        let mismatch = """
        --- a/App.swift
        +++ b/App.swift
        @@ -1,1 +1,1 @@
        -not the current source
        +replacement
        """
        do {
            _ = try AIUnifiedDiffParser.parse(mismatch, project: project, root: root)
            throw TestFailure.assertion("A stale diff context must be rejected")
        } catch AIUnifiedDiffError.contextMismatch(_) {
            // Expected: stale source context rejected.
        }

        do {
            _ = try AIUnifiedDiffParser.parse("Goose response without a diff", project: project, root: root)
            throw TestFailure.assertion("Output without a unified diff must be rejected")
        } catch AIUnifiedDiffError.noChanges {
            // Expected: no supported diff found.
        }
    }

    static func testProjectFileChangeStaleReviewProtection() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-FileChange-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Settings.json")
        try "{\"value\":1}\n".write(to: file, atomically: true, encoding: .utf8)
        let project = CODOProject(name: "Change Fixture", path: root.path, kind: .macOS)
        let change = try ProjectFileChangeService.prepare(
            file: file, project: project, root: root, proposedText: "{\"value\":2}\n"
        )
        try expect(change.relativePath == "Settings.json", "Prepared changes must store a relative path")

        try "{\"value\":3}\n".write(to: file, atomically: true, encoding: .utf8)
        do {
            try ProjectFileChangeService.apply(change, project: project, root: root, approved: true)
            throw TestFailure.assertion("Applying a stale review must fail")
        } catch ProjectFileChangeError.fileChanged {
            // Expected: stale review cannot overwrite newer user edits.
        }
        let current = try String(contentsOf: file, encoding: .utf8)
        try expect(current == "{\"value\":3}\n", "Stale review rejection must preserve the user's latest file")

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString).swift")
        try "let value = 1\n".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }
        do {
            _ = try ProjectFileChangeService.prepare(file: outside, project: project, root: root, proposedText: "let value = 2\n")
            throw TestFailure.assertion("Files outside the imported project must be rejected")
        } catch ProjectFileChangeError.outsideProject {
            // Expected: project boundary enforced.
        }
    }

    static func testXcodeBuildPlanning() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-XcodePlan-Test-\(UUID().uuidString)", isDirectory: true)
        let projectBundle = root.appendingPathComponent("Fixture.xcodeproj", isDirectory: true)
        let schemes = projectBundle.appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
        try FileManager.default.createDirectory(at: schemes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "<Scheme/>".write(to: schemes.appendingPathComponent("Zeta.xcscheme"), atomically: true, encoding: .utf8)
        try "<Scheme/>".write(to: schemes.appendingPathComponent("Alpha.xcscheme"), atomically: true, encoding: .utf8)
        let project = CODOProject(name: "Fixture", path: root.path, kind: .macOS)
        let debug = ProjectBuildPlanner.plan(.xcodeDebugBuild, root: root, project: project)
        let release = ProjectBuildPlanner.plan(.xcodeReleaseBuild, root: root, project: project)
        try expect(debug?.executable.path == "/usr/bin/xcodebuild", "Xcode builds must use the explicit xcodebuild executable")
        try expect(debug?.arguments.contains("Debug") == true, "Debug action must select Debug configuration")
        try expect(release?.arguments.contains("Release") == true, "Release action must select Release configuration")
        try expect(debug?.arguments.contains("Alpha") == true, "Shared schemes should be selected deterministically by name")
        try expect(debug?.arguments.contains("-project") == true, "Xcode project containers should use the -project argument")
        try expect(debug?.arguments.contains("macosx") == true, "macOS builds must select the macOS SDK explicitly")
        try expect(debug?.arguments.contains("platform=macOS,arch=arm64") == true,
                   "macOS builds must select a deterministic Apple Silicon destination")

        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-NoXcode-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        try expect(ProjectBuildPlanner.plan(.xcodeDebugBuild, root: empty, project: project) == nil,
                   "An Xcode build without a project or workspace must not be planned")
    }

    static func testWebBuildPlanning() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-WebPlan-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appendingPathComponent("package.json")
        try "{\"name\":\"fixture\",\"packageManager\":\"pnpm@9.0.0\",\"scripts\":{\"build\":\"vite build\",\"test\":\"vitest run\"}}"
            .write(to: package, atomically: true, encoding: .utf8)
        try Data().write(to: root.appendingPathComponent("pnpm-lock.yaml"))
        let project = CODOProject(name: "Web Fixture", path: root.path, kind: .web)
        let build = ProjectBuildPlanner.plan(.webBuild, root: root, project: project)
        let test = ProjectBuildPlanner.plan(.webTest, root: root, project: project)
        try expect(build?.executable.path == "/usr/bin/env", "Web scripts should be launched through env without shell interpolation")
        try expect(build?.arguments == ["pnpm", "run", "build"], "Declared pnpm package manager should be respected")
        try expect(test?.arguments == ["pnpm", "run", "test"], "Web test planner should select the test script")
        try "{\"name\":\"fixture\",\"scripts\":{\"build\":\"vite build\"}}"
            .write(to: package, atomically: true, encoding: .utf8)
        try expect(ProjectBuildPlanner.plan(.webTest, root: root, project: project) == nil,
                   "Missing web test scripts must not produce a runnable command")
    }

    @MainActor
    static func testGitWorkflowInputPolicies() throws {
        try expect(GitWorkflowService.isValidBranchName("feature/audio-engine"),
                   "A conventional feature branch name should be accepted")
        for invalid in ["", "-force", "../outside", "feature//bad", "feature/name.", "bad name", "x;rm"] {
            try expect(!GitWorkflowService.isValidBranchName(invalid), "Unsafe branch name should be rejected: \(invalid)")
        }
        try expect(GitWorkflowService.isValidBaseBranch("main"), "A normal base branch should be accepted")
        try expect(!GitWorkflowService.isValidBaseBranch("--upload-pack=evil"),
                   "Option-like base branch names must be rejected")
        try expect(GitWorkflowService.stagedCommitArguments("  Update audio engine\n") == ["commit", "-m", "Update audio engine"],
                   "Commit message must remain a single argument, not shell syntax")
        try expect(GitWorkflowService.stagedCommitArguments(" \n ") == nil,
                   "Empty commit messages must be rejected")
        try expect(GitWorkflowService.stagedCommitArguments("safe; echo injected") == ["commit", "-m", "safe; echo injected"],
                   "Shell metacharacters in commit messages must remain inert argument content")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw TestFailure.assertion(message)
        }
    }
}

enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)
    var description: String {
        switch self {
        case .assertion(let message): return "Assertion failed: " + message
        }
    }
}
