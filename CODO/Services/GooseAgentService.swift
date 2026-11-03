import Foundation
import Security
import SwiftUI

struct GooseConfiguration: Equatable {
    var provider = "openai"
    var model = "gpt-4.1"
}

enum GooseConnectionError: LocalizedError {
    case notInstalled
    case missingConfiguration
    case alreadyRunning
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "Goose CLI was not found. Install Goose and reopen CODO."
        case .missingConfiguration: "Choose a provider and model, then save your API key in CODO settings."
        case .alreadyRunning: "A Goose task is already running."
        case .launchFailed(let message): "Goose could not start: \(message)"
        }
    }
}

enum CODOKeychain {
    private static let service = "com.kialne.codo.goose"

    static func save(_ value: String, account: String = "provider-api-key") throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func read(account: String = "provider-api-key") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String = "provider-api-key") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class GooseAgentService: ObservableObject {
    @Published private(set) var output = ""
    @Published private(set) var status = "Not connected"
    @Published private(set) var isRunning = false
    @Published private(set) var proposal = ""

    private var process: Process?
    private var pipe: Pipe?
    private var scopedRoot: URL?

    var configuration = GooseConfiguration()
    var onOutput: ((String) -> Void)?
    var onCompletion: ((Int32) -> Void)?

    var isConfigured: Bool {
        !configuration.provider.isEmpty &&
        !configuration.model.isEmpty &&
        CODOKeychain.read() != nil
    }

    func saveAPIKey(_ key: String) throws {
        try CODOKeychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines))
        status = "Configured"
    }

    func removeAPIKey() {
        CODOKeychain.delete()
        status = "API key removed"
    }

    func locateGoose() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/goose",
            "/usr/local/bin/goose",
            "/usr/bin/goose",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/goose").path
        ]
        return candidates.map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func checkConnection() {
        guard let executable = locateGoose() else {
            status = "Goose CLI not installed"
            return
        }
        let check = Process()
        check.executableURL = executable
        check.arguments = ["--version"]
        let pipe = Pipe()
        check.standardOutput = pipe
        check.standardError = pipe
        do {
            try check.run()
            check.waitUntilExit()
            status = check.terminationStatus == 0 ? "Goose CLI detected" : "Goose CLI error"
        } catch {
            status = error.localizedDescription
        }
    }

    func runAnalysis(prompt: String, project: CODOProject, root: URL, approvalGranted: Bool) {
        guard approvalGranted else { return }
        guard !isRunning else { status = GooseConnectionError.alreadyRunning.localizedDescription; return }
        guard isConfigured else { status = GooseConnectionError.missingConfiguration.localizedDescription; return }
        guard let executable = locateGoose() else { status = GooseConnectionError.notInstalled.localizedDescription; return }

        let didStart = project.bookmarkData != nil ? root.startAccessingSecurityScopedResource() : false
        if project.bookmarkData != nil && !didStart {
            status = "Project folder access denied"
            return
        }

        let task = Process()
        let outputPipe = Pipe()
        var environment = ProcessInfo.processInfo.environment
        environment["GOOSE_PROVIDER"] = configuration.provider
        environment["GOOSE_MODEL"] = configuration.model
        if let key = CODOKeychain.read() {
            environment["GOOSE_API_KEY"] = key
            if configuration.provider == "openai" { environment["OPENAI_API_KEY"] = key }
            if configuration.provider == "anthropic" { environment["ANTHROPIC_API_KEY"] = key }
            if configuration.provider == "google" { environment["GEMINI_API_KEY"] = key }
        }

        let safePrompt = """
        You are working in a CODO-managed project. This is ANALYSIS AND PROPOSAL ONLY.
        Do not create, edit, delete, rename, or move files. Do not run shell commands, builds,
        tests, installers, network commands, or destructive actions. Inspect project files using
        read-only capabilities only. Return a concise plan, risks, and proposed unified diffs
        for each suggested file change. Clearly state when more context is needed.

        USER TASK:
        \(prompt)
        """

        task.executableURL = executable
        task.arguments = ["run", "--text", safePrompt]
        task.currentDirectoryURL = root
        task.environment = environment
        task.standardOutput = outputPipe
        task.standardError = outputPipe
        output = ""
        proposal = ""
        status = "Starting Goose…"
        process = task
        pipe = outputPipe
        scopedRoot = didStart ? root : nil
        isRunning = true

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let chunk = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                guard let self else { return }
                self.output.append(chunk)
                self.proposal = self.output
                self.onOutput?(chunk)
            }
        }

        task.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pipe?.fileHandleForReading.readabilityHandler = nil
                self.pipe = nil
                self.process = nil
                self.isRunning = false
                self.scopedRoot?.stopAccessingSecurityScopedResource()
                self.scopedRoot = nil
                self.status = finished.terminationStatus == 0 ? "Analysis complete" : "Goose exited · \(finished.terminationStatus)"
                self.onCompletion?(finished.terminationStatus)
            }
        }

        do {
            try task.run()
            status = "Goose is analyzing"
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            process = nil
            pipe = nil
            isRunning = false
            scopedRoot?.stopAccessingSecurityScopedResource()
            scopedRoot = nil
            status = GooseConnectionError.launchFailed(error.localizedDescription).localizedDescription
        }
    }

    func stop() {
        guard let process, process.isRunning else { return }
        status = "Stopping Goose…"
        process.terminate()
    }
}
