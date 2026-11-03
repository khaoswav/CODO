import Foundation
import SwiftUI

enum ProjectCommand: String, CaseIterable, Identifiable {
    case location = "Working directory"
    case listFiles = "List files"
    case gitStatus = "Git status"
    case xcodeTargets = "Xcode targets"
    case swiftVersion = "Swift version"
    case nodeVersion = "Node.js version"
    case npmVersion = "npm version"
    case xcodeDebugBuild = "Xcode Debug build"
    case xcodeReleaseBuild = "Xcode Release build"
    case unityMacBuild = "Unity macOS build"
    case webBuild = "Web build"
    case webTest = "Web test"

    var id: String { rawValue }

    var executable: URL {
        switch self {
        case .location: URL(fileURLWithPath: "/bin/pwd")
        case .listFiles: URL(fileURLWithPath: "/bin/ls")
        case .gitStatus: URL(fileURLWithPath: "/usr/bin/git")
        case .xcodeTargets: URL(fileURLWithPath: "/usr/bin/xcodebuild")
        case .swiftVersion: URL(fileURLWithPath: "/usr/bin/swift")
        case .nodeVersion, .npmVersion: URL(fileURLWithPath: "/usr/bin/env")
        case .xcodeDebugBuild, .xcodeReleaseBuild: URL(fileURLWithPath: "/usr/bin/xcodebuild")
        case .unityMacBuild: URL(fileURLWithPath: "/Applications/Unity/Hub/Editor/Unity.app/Contents/MacOS/Unity")
        case .webBuild, .webTest: URL(fileURLWithPath: "/usr/bin/env")
        }
    }

    var arguments: [String] {
        switch self {
        case .location: []
        case .listFiles: ["-la"]
        case .gitStatus: ["status", "--short", "--branch"]
        case .xcodeTargets: ["-list"]
        case .swiftVersion: ["--version"]
        case .nodeVersion: ["node", "--version"]
        case .npmVersion: ["npm", "--version"]
        case .xcodeDebugBuild, .xcodeReleaseBuild, .unityMacBuild, .webBuild, .webTest: []
        }
    }

    var displayCommand: String {
        ([executable.lastPathComponent] + arguments).joined(separator: " ")
    }

    static func available(for kind: ProjectKind) -> [ProjectCommand] {
        switch kind {
        case .macOS, .iOS:
            [.location, .listFiles, .gitStatus, .xcodeTargets, .swiftVersion, .xcodeDebugBuild, .xcodeReleaseBuild]
        case .web:
            [.location, .listFiles, .gitStatus, .nodeVersion, .npmVersion]
        case .unity:
            [.location, .listFiles, .gitStatus, .unityMacBuild]
        case .other:
            [.location, .listFiles, .gitStatus]
        }
    }

    var requiresApproval: Bool {
        switch self {
        case .xcodeDebugBuild, .xcodeReleaseBuild, .unityMacBuild, .webBuild, .webTest: true
        default: false
        }
    }

    static func buildCommands(for kind: ProjectKind) -> [ProjectCommand] {
        switch kind {
        case .macOS, .iOS: [.xcodeDebugBuild, .xcodeReleaseBuild]
        case .unity: [.unityMacBuild]
        case .web: [.webBuild, .webTest]
        case .other: []
        }
    }
}

@MainActor
final class ProjectProcessRunner: ObservableObject {
    @Published private(set) var output = ""
    @Published private(set) var status = "Ready"
    @Published private(set) var isRunning = false
    private(set) var wasStopped = false

    var onOutput: ((String) -> Void)?
    var onCompletion: ((Int32) -> Void)?

    private var process: Process?
    private var outputPipe: Pipe?
    private var scopedRoot: URL?

    func run(_ command: ProjectCommand, for project: CODOProject, root: URL) {
        guard !isRunning else { return }

        wasStopped = false
        let workingDirectory = root.standardizedFileURL
        guard FileManager.default.fileExists(atPath: workingDirectory.path) else {
            fail("Project folder is no longer available. Re-import the project.")
            return
        }

        let needsScope = project.bookmarkData != nil
        if needsScope && !workingDirectory.startAccessingSecurityScopedResource() {
            fail("CODO could not obtain access to this project folder. Re-import it and grant folder access again.")
            return
        }

        let task = Process()
        let pipe = Pipe()
        let planned = ProjectBuildPlanner.plan(command, root: workingDirectory, project: project)
        if command.requiresApproval && planned == nil {
            fail("Build configuration could not be prepared. Check the project structure and installed tools.")
            return
        }
        task.executableURL = planned?.executable ?? command.executable
        task.arguments = planned?.arguments ?? command.arguments
        task.currentDirectoryURL = workingDirectory
        task.standardOutput = pipe
        task.standardError = pipe

        output = "$ \(command.displayCommand)\n\n"
        onOutput?(output)
        status = "Starting…"
        scopedRoot = needsScope ? workingDirectory : nil
        outputPipe = pipe
        process = task

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let chunk = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                guard let self else { return }
                self.output.append(chunk)
                self.onOutput?(chunk)
            }
        }

        task.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                self?.finish(exitCode: finished.terminationStatus)
            }
        }

        do {
            try task.run()
            isRunning = true
            status = "Running"
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            process = nil
            outputPipe = nil
            scopedRoot?.stopAccessingSecurityScopedResource()
            scopedRoot = nil
            fail("Failed to start process: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let process, process.isRunning else { return }
        status = "Stopping…"
        process.terminate()
    }

    func clear() {
        guard !isRunning else { return }
        output = ""
        status = "Ready"
    }

    private func fail(_ message: String) {
        output = message + "\n"
        status = "Failed"
        onOutput?(output)
        onCompletion?(-1)
    }

    private func finish(exitCode: Int32) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        process = nil
        isRunning = false
        scopedRoot?.stopAccessingSecurityScopedResource()
        scopedRoot = nil
        status = exitCode == 0 ? "Completed · exit 0" : "Finished · exit \(exitCode)"
        if !output.hasSuffix("\n") { output.append("\n") }
        onCompletion?(exitCode)
    }
}
