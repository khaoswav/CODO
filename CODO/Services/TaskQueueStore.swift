import Foundation
import SwiftUI

enum CODOExecutionStatus: String, Codable {
    case queued = "Queued"
    case running = "Running"
    case succeeded = "Succeeded"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

struct CODOExecutionTask: Identifiable, Codable {
    var id: UUID = UUID()
    var projectID: UUID
    var projectName: String
    var commandName: String
    var commandLine: String
    var status: CODOExecutionStatus
    var createdAt: Date = .now
    var startedAt: Date?
    var finishedAt: Date?
    var exitCode: Int32?
    var output: String = ""
}

@MainActor
final class TaskQueueStore: ObservableObject {
    @Published private(set) var tasks: [CODOExecutionTask] = []
    @Published private(set) var activeTaskID: UUID?
    @Published private(set) var liveOutput = ""
    @Published private(set) var processStatus = "Ready"
    @Published private(set) var isRunning = false

    let runner = ProjectProcessRunner()
    private var pending: [PendingCommand] = []
    private let maximumHistory = 50
    private let maximumStoredOutput = 200_000
    private let storageURL: URL

    private struct PendingCommand {
        let taskID: UUID
        let command: ProjectCommand
        let project: CODOProject
        let root: URL
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("CODO", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("execution-history.json")
        load()

        runner.onOutput = { [weak self] chunk in
            guard let self else { return }
            self.liveOutput = self.runner.output
            guard let id = self.activeTaskID,
                  let index = self.tasks.firstIndex(where: { $0.id == id }) else { return }
            self.tasks[index].output.append(chunk)
            if self.tasks[index].output.count > self.maximumStoredOutput {
                self.tasks[index].output = String(self.tasks[index].output.suffix(self.maximumStoredOutput))
            }
            self.persist()
        }

        runner.onCompletion = { [weak self] exitCode in
            guard let self, let id = self.activeTaskID,
                  let index = self.tasks.firstIndex(where: { $0.id == id }) else { return }
            self.isRunning = false
            self.processStatus = self.runner.status
            self.liveOutput = self.runner.output
            self.tasks[index].exitCode = exitCode
            self.tasks[index].finishedAt = .now
            if self.runner.wasStopped {
                self.tasks[index].status = .cancelled
            } else {
                self.tasks[index].status = exitCode == 0 ? .succeeded : .failed
            }
            self.activeTaskID = nil
            self.persist()
            self.runNext()
        }
    }

    var queuedCount: Int { tasks.filter { $0.status == .queued }.count }
    var runningCount: Int { tasks.filter { $0.status == .running }.count }

    func enqueue(_ command: ProjectCommand, project: CODOProject, root: URL, approvalGranted: Bool = false) {
        guard !command.requiresApproval || approvalGranted else { return }
        let task = CODOExecutionTask(
            projectID: project.id,
            projectName: project.name,
            commandName: command.rawValue,
            commandLine: command.displayCommand,
            status: .queued
        )
        tasks.insert(task, at: 0)
        pending.append(PendingCommand(taskID: task.id, command: command, project: project, root: root))
        trimHistory()
        persist()
        runNext()
    }

    func stopCurrent() {
        processStatus = "Stopping…"
        runner.stop()
    }

    func clearLiveOutput() {
        guard !isRunning else { return }
        runner.clear()
        liveOutput = ""
        processStatus = "Ready"
    }

    func clearFinishedHistory() {
        tasks.removeAll { $0.status != .queued && $0.status != .running }
        persist()
    }

    private func runNext() {
        guard activeTaskID == nil, !runner.isRunning, !pending.isEmpty else { return }
        let next = pending.removeFirst()
        guard let index = tasks.firstIndex(where: { $0.id == next.taskID }) else {
            runNext()
            return
        }

        activeTaskID = next.taskID
        isRunning = true
        liveOutput = ""
        processStatus = "Starting…"
        tasks[index].status = .running
        tasks[index].startedAt = .now
        persist()
        runner.run(next.command, for: next.project, root: next.root)
        processStatus = runner.status
    }

    private func trimHistory() {
        guard tasks.count > maximumHistory else { return }
        let removable = tasks.filter { $0.status != .queued && $0.status != .running }
            .sorted { $0.createdAt < $1.createdAt }
        let excess = tasks.count - maximumHistory
        let ids = Set(removable.prefix(excess).map(\.id))
        tasks.removeAll { ids.contains($0.id) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([CODOExecutionTask].self, from: data) else { return }
        tasks = saved.map { task in
            var restored = task
            if restored.status == .running || restored.status == .queued {
                restored.status = .failed
                restored.finishedAt = .now
                restored.output += "\nCODO closed before this task completed.\n"
            }
            return restored
        }
        persist()
    }

    private func persist() {
        let data = try? JSONEncoder().encode(tasks)
        try? data?.write(to: storageURL, options: .atomic)
    }
}
