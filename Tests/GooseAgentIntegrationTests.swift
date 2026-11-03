import Foundation
import SwiftUI

@main
struct GooseAgentIntegrationTests {
    @MainActor
    static func main() throws {
        try testApprovalGateAndProviderConfiguration()
        try testGooseProcessEnvironmentAndPrompt()
        try testGooseProcessCancellation()
        print("PASS: 3 Goose CLI process integration groups")
    }

    @MainActor
    static func testApprovalGateAndProviderConfiguration() throws {
        let root = try makeTemporaryDirectory("CODO-Goose-Gates")
        defer { try? FileManager.default.removeItem(at: root) }
        let project = CODOProject(name: "Goose Fixture", path: root.path, kind: .macOS)
        let executable = root.appendingPathComponent("fake-goose")
        try writeExecutable("#!/bin/sh\necho SHOULD_NOT_RUN\n", to: executable)

        let missingKey = GooseAgentService(executableURL: executable, apiKeyProvider: { nil })
        missingKey.runAnalysis(prompt: "No approval", project: project, root: root, approvalGranted: false)
        try expect(!missingKey.isRunning, "Goose must not start before explicit approval")
        try expect(missingKey.status == "Not connected", "A denied approval must not mutate connection state")

        missingKey.runAnalysis(prompt: "Missing key", project: project, root: root, approvalGranted: true)
        try expect(!missingKey.isRunning, "Goose must not start without a provider key")
        try expect(missingKey.status == GooseConnectionError.missingConfiguration.localizedDescription,
                   "Missing provider credentials must produce a clear configuration error")
    }

    @MainActor
    static func testGooseProcessEnvironmentAndPrompt() throws {
        let root = try makeTemporaryDirectory("CODO-Goose-Process")
        defer { try? FileManager.default.removeItem(at: root) }
        let environmentCapture = root.appendingPathComponent("environment.txt")
        let promptCapture = root.appendingPathComponent("prompt.txt")
        let script = """
        #!/bin/sh
        printf '%s\\n' "$GOOSE_PROVIDER" "$GOOSE_MODEL" "$GOOSE_API_KEY" "$OPENAI_API_KEY" > '\(environmentCapture.path)'
        printf '%s\\n' "$3" > '\(promptCapture.path)'
        echo FAKE_GOOSE_OK
        """
        let executable = root.appendingPathComponent("fake-goose")
        try writeExecutable(script, to: executable)
        let project = CODOProject(name: "Goose Fixture", path: root.path, kind: .macOS)
        let service = GooseAgentService(executableURL: executable, apiKeyProvider: { "test-provider-key" })
        service.configuration = GooseConfiguration(provider: "openai", model: "test-model")

        var completionCode: Int32?
        service.onCompletion = { completionCode = $0 }
        service.runAnalysis(
            prompt: "Add a safe sample feature",
            project: project,
            root: root,
            approvalGranted: true
        )
        try waitForCompletion(service, completionCode: { completionCode })
        try expect(completionCode == 0, "A successful Goose CLI process should report exit code zero")
        let environment = try String(contentsOf: environmentCapture, encoding: .utf8)
            .split(separator: "\n").map(String.init)
        try expect(environment == ["openai", "test-model", "test-provider-key", "test-provider-key"],
                   "Provider, model and provider-specific API key environment variables must be passed to Goose")
        let prompt = try String(contentsOf: promptCapture, encoding: .utf8)
        try expect(prompt.contains("USER TASK:\nAdd a safe sample feature"),
                   "The requested task must be passed as the Goose prompt")
        try expect(prompt.contains("ANALYSIS AND PROPOSAL ONLY") &&
                   prompt.contains("Do not create, edit, delete, rename, or move files"),
                   "Goose must receive the read-only proposal safety boundary")
        try expect(!service.isRunning, "The service must clear its running state after process completion")
    }

    @MainActor
    static func testGooseProcessCancellation() throws {
        let root = try makeTemporaryDirectory("CODO-Goose-Cancel")
        defer { try? FileManager.default.removeItem(at: root) }
        let script = """
        #!/bin/sh
        trap 'exit 143' TERM
        while true; do /bin/sleep 0.1; done
        """
        let executable = root.appendingPathComponent("fake-goose")
        try writeExecutable(script, to: executable)
        let project = CODOProject(name: "Goose Fixture", path: root.path, kind: .macOS)
        let service = GooseAgentService(executableURL: executable, apiKeyProvider: { "test-key" })
        var completionCode: Int32?
        service.onCompletion = { completionCode = $0 }
        service.runAnalysis(prompt: "Cancellation fixture", project: project, root: root, approvalGranted: true)
        try expect(service.isRunning, "The fake Goose process should start")
        service.stop()
        try waitForCompletion(service, completionCode: { completionCode })
        try expect(completionCode != nil && completionCode != 0,
                   "Stopping Goose must surface a non-zero process completion")
        try expect(!service.isRunning, "Cancellation must release the running state")
    }

    @MainActor
    static func waitForCompletion(
        _ service: GooseAgentService,
        completionCode: () -> Int32?,
        timeout: TimeInterval = 8
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while completionCode() == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        try expect(completionCode() != nil, "Goose process did not complete before the integration-test timeout")
    }

    static func makeTemporaryDirectory(_ prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func writeExecutable(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw NSError(domain: "GooseAgentIntegrationTests", code: 1,
                                               userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
