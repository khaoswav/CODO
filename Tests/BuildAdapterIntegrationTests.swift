import Foundation

@main
struct BuildAdapterIntegrationTests {
    static func main() throws {
        print("RUN: project detection and analysis")
        try testProjectDetectionAndAnalysis()
        print("PASS: project detection and analysis")
        print("RUN: Unity command contract")
        try testUnityInvocationContract()
        print("PASS: Unity command contract")
        print("RUN: npm build and test")
        try testWebBuildAndTestExecution()
        print("PASS: npm build and test")
        print("RUN: CODO Xcode build through planner")
        try testXcodeBuildThroughPlanner()
        print("PASS: Xcode, Unity adapter contract, and web build/test end-to-end checks")
    }

    static func testProjectDetectionAndAnalysis() throws {
        let unityRoot = makeTemporaryDirectory("CODO-Unity-Analysis")
        defer { try? FileManager.default.removeItem(at: unityRoot) }
        try makeDirectory(unityRoot.appendingPathComponent("Assets", isDirectory: true))
        try makeDirectory(unityRoot.appendingPathComponent("ProjectSettings", isDirectory: true))
        try makeDirectory(unityRoot.appendingPathComponent("Packages", isDirectory: true))
        try "m_EditorVersion: 6000.0.25f1\n".write(
            to: unityRoot.appendingPathComponent("ProjectSettings/ProjectVersion.txt"),
            atomically: true, encoding: .utf8
        )
        try "{}\n".write(
            to: unityRoot.appendingPathComponent("Packages/manifest.json"),
            atomically: true, encoding: .utf8
        )
        try expect(ProjectKind.detect(at: unityRoot) == .unity,
                   "A Unity Assets + ProjectSettings layout must be detected as Unity")
        let unityAnalysis = ProjectAnalyzer.analyze(at: unityRoot, kind: .unity)
        try expect(unityAnalysis.metadata.contains(where: {
            $0.label == "Unity Editor" && $0.value == "6000.0.25f1"
        }), "Unity analysis must read the project's declared editor version")

        let webRoot = makeTemporaryDirectory("CODO-Web-Analysis")
        defer { try? FileManager.default.removeItem(at: webRoot) }
        try "{\"name\":\"codo-web-fixture\",\"scripts\":{\"build\":\"node build.js\"}}"
            .write(to: webRoot.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try expect(ProjectKind.detect(at: webRoot) == .web,
                   "A package.json project must be detected as web")
        let webAnalysis = ProjectAnalyzer.analyze(at: webRoot, kind: .web)
        try expect(webAnalysis.metadata.contains(where: { $0.label == "Package name" && $0.value == "codo-web-fixture" }),
                   "Web analysis must read package metadata")
    }

    static func testUnityInvocationContract() throws {
        let root = makeTemporaryDirectory("CODO-Unity-E2E")
        defer { try? FileManager.default.removeItem(at: root) }
        try makeDirectory(root.appendingPathComponent("Assets", isDirectory: true))
        try makeDirectory(root.appendingPathComponent("ProjectSettings", isDirectory: true))
        try makeDirectory(root.appendingPathComponent("Packages", isDirectory: true))
        try makeDirectory(root.appendingPathComponent("Builds", isDirectory: true))
        try "m_EditorVersion: 6000.0.25f1\n".write(
            to: root.appendingPathComponent("ProjectSettings/ProjectVersion.txt"),
            atomically: true, encoding: .utf8
        )
        try "{}\n".write(to: root.appendingPathComponent("Packages/manifest.json"),
                         atomically: true, encoding: .utf8)

        let editorRoot = makeTemporaryDirectory("CODO-Unity-Editor")
        defer { try? FileManager.default.removeItem(at: editorRoot) }
        let executable = editorRoot
            .appendingPathComponent("6000.0.25f1/Unity.app/Contents/MacOS/Unity")
        try makeDirectory(executable.deletingLastPathComponent())
        let marker = root.appendingPathComponent("unity-arguments.txt")
        let script = "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$CODO_UNITY_ARGS_FILE\"\nexit 0\n"
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let project = CODOProject(name: root.lastPathComponent, path: root.path, kind: .unity)
        guard let planned = ProjectBuildPlanner.plan(
            .unityMacBuild, root: root, project: project, unityEditorRoots: [editorRoot]
        ) else {
            throw HarnessFailure.assertion("Unity planner should find the injected fixture editor")
        }
        try execute(planned, workingDirectory: root, environment: ["CODO_UNITY_ARGS_FILE": marker.path])
        let arguments = try String(contentsOf: marker, encoding: .utf8)
        try expect(arguments.contains("-batchmode"), "Unity must run in batch mode")
        try expect(arguments.contains("-projectPath\n\(root.path)"), "Unity must receive the selected project root")
        try expect(arguments.contains("-buildTarget\nStandaloneOSX"), "Unity must target macOS standalone")
        try expect(arguments.contains("-buildOSXPlayer"), "Unity must receive the macOS player build argument")
    }

    static func testWebBuildAndTestExecution() throws {
        let root = makeTemporaryDirectory("CODO-Web-E2E")
        defer { try? FileManager.default.removeItem(at: root) }
        let scripts = root.appendingPathComponent("scripts", isDirectory: true)
        try makeDirectory(scripts)
        let package = """
        {
          "name": "codo-web-e2e-fixture",
          "private": true,
          "scripts": {
            "build": "node scripts/build.js",
            "test": "node scripts/test.js"
          }
        }
        """
        try package.write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try """
        const fs = require("fs");
        fs.mkdirSync("dist", { recursive: true });
        fs.writeFileSync("dist/build-result.txt", "CODO_WEB_BUILD_OK\\n");
        console.log("fixture build completed");
        """.write(to: scripts.appendingPathComponent("build.js"), atomically: true, encoding: .utf8)
        try """
        const fs = require("fs");
        const result = fs.readFileSync("dist/build-result.txt", "utf8");
        if (result !== "CODO_WEB_BUILD_OK\\n") process.exit(1);
        console.log("fixture test completed");
        """.write(to: scripts.appendingPathComponent("test.js"), atomically: true, encoding: .utf8)

        let project = CODOProject(name: root.lastPathComponent, path: root.path, kind: .web)
        guard let build = ProjectBuildPlanner.plan(.webBuild, root: root, project: project),
              let test = ProjectBuildPlanner.plan(.webTest, root: root, project: project) else {
            throw HarnessFailure.assertion("Web planner must produce both fixture scripts")
        }
        try execute(build, workingDirectory: root)
        try execute(test, workingDirectory: root)
        let artifact = root.appendingPathComponent("dist/build-result.txt")
        try expect(FileManager.default.fileExists(atPath: artifact.path),
                   "The real npm build script must create its output artifact")
    }

    static func testXcodeBuildThroughPlanner() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .standardizedFileURL
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("CODO.xcodeproj").path) else {
            throw HarnessFailure.assertion("CI working directory must contain the real CODO.xcodeproj")
        }
        let project = CODOProject(name: "CODO", path: root.path, kind: .macOS)
        let configuration = ProcessInfo.processInfo.environment["CODO_BUILD_CONFIGURATION"] ?? "Debug"
        let command: ProjectCommand = configuration == "Release" ? .xcodeReleaseBuild : .xcodeDebugBuild
        guard let planned = ProjectBuildPlanner.plan(command, root: root, project: project) else {
            throw HarnessFailure.assertion("Xcode planner must produce a command for the real CODO project")
        }
        try expect(planned.arguments.contains(configuration),
                   "Xcode planner must preserve the requested CI configuration")
        try execute(planned, workingDirectory: root)
        print("PASS: real CODO.xcodeproj built through ProjectBuildPlanner (\\(configuration))")
    }

    @discardableResult
    static func execute(_ command: PlannedCommand, workingDirectory: URL,
                        environment additions: [String: String] = [:]) throws -> String {
        let process = Process()
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CODO-Command-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
            throw HarnessFailure.assertion("Could not create a temporary command log")
        }
        defer { try? FileManager.default.removeItem(at: logURL) }
        let logHandle = try FileHandle(forWritingTo: logURL)
        process.executableURL = command.executable
        process.arguments = command.arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = logHandle
        process.standardError = logHandle
        var environment = ProcessInfo.processInfo.environment
        additions.forEach { environment[$0.key] = $0.value }
        process.environment = environment
        try process.run()
        process.waitUntilExit()
        try? logHandle.close()
        let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        guard process.terminationStatus == 0 else {
            throw HarnessFailure.assertion(
                "Command failed (exit \(process.terminationStatus)): \(command.display)\n\(lastLines(output, count: 35))"
            )
        }
        return output
    }

    static func makeTemporaryDirectory(_ prefix: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try! makeDirectory(url)
        return url
    }

    static func makeDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func lastLines(_ value: String, count: Int) -> String {
        value.components(separatedBy: .newlines).suffix(count).joined(separator: "\n")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw HarnessFailure.assertion(message) }
    }
}

enum HarnessFailure: Error, CustomStringConvertible {
    case assertion(String)
    var description: String {
        switch self {
        case .assertion(let message): return "Assertion failed: " + message
        }
    }
}
