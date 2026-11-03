import Foundation

@main
struct DeveloperIntelligenceTests {
    @MainActor
    static func main() throws {
        try testSwiftModuleResolution()
        try testRelativeModuleResolution()
        try testExternalAndAmbiguousImportsAreExcluded()
        try testProjectScanBuildsGraphAndFindings()
        try testBuildFailureFingerprinting()
        try testAgentWorkflowTransitionsAndPersistence()
        print("PASS: 6 Developer Intelligence and Agent Orchestrator test groups")
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

        try expect(store.activeWorkflow?.steps.first?.status == .running, "Workflow should start its first stage")
        store.completeCurrentAndAdvance("Architecture inspected.")
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Plan") })?.status == .running,
                   "Orchestrator should run the planning stage after architecture")
        store.completeCurrentAndAdvance("Implementation plan prepared.")
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Implement") })?.status == .running,
                   "Orchestrator should enter implementation before Goose runs")
        store.proposalReady()
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Review") })?.status == .awaitingApproval,
                   "Patch review must wait for explicit approval")
        store.reviewCompleted(appliedCount: 1, rejectedCount: 0)
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Build") })?.status == .awaitingApproval,
                   "Build stage must wait for explicit approval")
        store.approveCurrentStep()
        store.buildFailed("Compiler error: missing symbol")
        try expect(store.activeWorkflow?.status == .failed, "Build failure should fail the workflow")
        store.resumeForFix()
        try expect(store.activeWorkflow?.steps.first(where: { $0.title.contains("Implement") })?.status == .running,
                   "Fix retry should restart at implementation")
        store.proposalReady()
        store.reviewCompleted(appliedCount: 1, rejectedCount: 0)
        store.approveCurrentStep()
        store.buildSucceeded()
        try expect(store.activeWorkflow == nil, "Successful build should close the active workflow")
        let restored = AgentOrchestratorStore(storageURL: storage)
        try expect(restored.workflows.first?.status == .succeeded, "Completed workflow should persist across launches")
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
