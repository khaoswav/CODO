import Foundation
import SwiftUI

struct GitRepositorySnapshot {
    let branch: String
    let status: String
    let isRepository: Bool
}

@MainActor
final class GitWorkflowService: ObservableObject {
    @Published private(set) var snapshot = GitRepositorySnapshot(branch: "Unknown", status: "", isRepository: false)
    @Published private(set) var output = ""
    @Published private(set) var statusMessage = "Not checked"
    @Published private(set) var isRunning = false

    private var activeProcess: Process?
    private var scopedRoot: URL?

    func refresh(project: CODOProject, root: URL) {
        run(executable: URL(fileURLWithPath: "/usr/bin/git"),
            arguments: ["rev-parse", "--show-toplevel"], project: project, root: root,
            approvalGranted: true, updateSnapshot: false) { [weak self] result, code in
                guard let self else { return }
                guard code == 0 else {
                    self.snapshot = GitRepositorySnapshot(branch: "Not a Git repository", status: "", isRepository: false)
                    self.statusMessage = "Git repository not detected"
                    return
                }
                self.readBranchAndStatus(project: project, root: root)
            }
    }

    func createBranch(_ name: String, project: CODOProject, root: URL, approvalGranted: Bool) {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-")
        guard !name.isEmpty, name.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !name.hasPrefix("-"), !name.contains(".."), !name.hasSuffix("/") else {
            statusMessage = "Invalid branch name."
            return
        }
        runGit(["switch", "-c", name], project: project, root: root, approvalGranted: approvalGranted)
    }

    func commitStagedChanges(_ message: String, project: CODOProject, root: URL, approvalGranted: Bool) {
        let clean = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { statusMessage = "Commit message is required."; return }
        runGit(["commit", "-m", clean], project: project, root: root, approvalGranted: approvalGranted)
    }

    func push(project: CODOProject, root: URL, approvalGranted: Bool) {
        runGit(["push", "-u", "origin", "HEAD"], project: project, root: root, approvalGranted: approvalGranted)
    }

    func createPullRequest(project: CODOProject, root: URL, base: String = "main", approvalGranted: Bool) {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-")
        guard !base.isEmpty, base.unicodeScalars.allSatisfy({ allowed.contains($0) }), !base.hasPrefix("-") else {
            statusMessage = "Invalid base branch."
            return
        }
        let ghCandidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let ghPath = ghCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            statusMessage = "GitHub CLI (gh) is not installed. Install it and authenticate with gh auth login."
            return
        }
        run(executable: URL(fileURLWithPath: ghPath),
            arguments: ["pr", "create", "--fill", "--base", base],
            project: project, root: root, approvalGranted: approvalGranted, updateSnapshot: false) { [weak self] _, code in
                self?.statusMessage = code == 0 ? "Pull request created." : "Pull request creation failed. Check GitHub CLI authentication and output."
            }
    }

    private func readBranchAndStatus(project: CODOProject, root: URL) {
        run(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: ["branch", "--show-current"],
            project: project, root: root, approvalGranted: true, updateSnapshot: false) { [weak self] branch, code in
            guard let self, code == 0 else { return }
            self.run(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: ["status", "--short", "--branch"],
                project: project, root: root, approvalGranted: true, updateSnapshot: false) { status, statusCode in
                guard statusCode == 0 else { return }
                self.snapshot = GitRepositorySnapshot(branch: branch.trimmingCharacters(in: .whitespacesAndNewlines),
                    status: status, isRepository: true)
                self.statusMessage = "Git status refreshed"
            }
        }
    }

    private func runGit(_ arguments: [String], project: CODOProject, root: URL,
                        approvalGranted: Bool, completion: ((String, Int32) -> Void)? = nil) {
        run(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: arguments,
            project: project, root: root, approvalGranted: approvalGranted,
            updateSnapshot: true, completion: completion)
    }

    private func run(executable: URL, arguments: [String], project: CODOProject, root: URL,
                     approvalGranted: Bool, updateSnapshot: Bool,
                     completion: ((String, Int32) -> Void)? = nil) {
        guard !isRunning else { statusMessage = "A Git operation is already running."; return }
        guard approvalGranted else { statusMessage = "This Git operation requires explicit approval."; return }
        let directory = root.standardizedFileURL
        let needsScope = project.bookmarkData != nil
        if needsScope && !directory.startAccessingSecurityScopedResource() {
            statusMessage = "Project folder access was denied."
            return
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = pipe
        process.standardError = pipe
        isRunning = true
        statusMessage = "Running: " + ([executable.lastPathComponent] + arguments).joined(separator: " ")
        output = ""
        scopedRoot = needsScope ? directory : nil
        activeProcess = process

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let result = String(decoding: data, as: UTF8.self)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRunning = false
                    self.activeProcess = nil
                    self.scopedRoot?.stopAccessingSecurityScopedResource()
                    self.scopedRoot = nil
                    self.output = result
                    self.statusMessage = process.terminationStatus == 0 ? "Completed" : "Failed · exit \(process.terminationStatus)"
                    completion?(result, process.terminationStatus)
                    if updateSnapshot && process.terminationStatus == 0 {
                        self.readBranchAndStatus(project: project, root: root)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRunning = false
                    self.scopedRoot?.stopAccessingSecurityScopedResource()
                    self.scopedRoot = nil
                    self.statusMessage = error.localizedDescription
                    self.output = error.localizedDescription
                    completion?(error.localizedDescription, -1)
                }
            }
        }
    }
}
