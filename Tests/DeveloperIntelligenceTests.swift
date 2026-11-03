import Foundation

@main
struct DeveloperIntelligenceTests {
    static func main() throws {
        try testSwiftModuleResolution()
        try testRelativeModuleResolution()
        try testExternalAndAmbiguousImportsAreExcluded()
        try testProjectScanBuildsGraphAndFindings()
        try testBuildFailureFingerprinting()
        print("PASS: 5 Developer Intelligence test groups")
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
        let report = DeveloperIntelligenceService.analyze(root: root, projectName: "Fixture")
        try expect(report.files.count == 2, "Scanner should index both Swift files")
        try expect(report.graphEdges.count == 1, "Scanner should return one resolved local graph edge")
        try expect(report.findings.contains(where: { $0.title == "Pending code note" }), "Scanner should detect TODO notes")
    }

    static func testBuildFailureFingerprinting() throws {
        let log = """
        Sources/App.swift:42:8: error: Cannot find type 'AudioUnit' in scope
        Sources/App.swift:91:8: error: Cannot find type 'AudioUnit' in scope
        Build failed.
        """
        let diagnostics = BuildFailureAnalyzer.extractDiagnostics(from: log)
        try expect(diagnostics.count == 1, "Repeated compiler errors should normalize to one signature")
        let merged = BuildFailureAnalyzer.merge(diagnostics + diagnostics, into: [])
        try expect(merged.count == 1, "Repeated signatures should merge into one memory pattern")
        try expect(merged[0].occurrenceCount == 2, "Pattern occurrence count should increase")
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
