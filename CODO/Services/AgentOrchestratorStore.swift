import Foundation
import SwiftUI

enum AgentWorkflowStatus: String, Codable {
    case running = "Running"
    case awaitingApproval = "Awaiting approval"
    case succeeded = "Succeeded"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

enum AgentStepStatus: String, Codable {
    case pending = "Pending"
    case running = "Running"
    case awaitingApproval = "Awaiting approval"
    case succeeded = "Succeeded"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

struct AgentWorkflowStep: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var requiresApproval: Bool
    var status: AgentStepStatus = .pending
    var startedAt: Date?
    var finishedAt: Date?
    var resultSummary: String?
    var attemptCount: Int? = 0
    var outputExcerpt: String? = nil
    var errorMessage: String? = nil
}

struct AgentWorkflow: Identifiable, Codable {
    var id: UUID = UUID()
    var projectID: UUID
    var projectName: String
    var request: String
    var steps: [AgentWorkflowStep]
    var status: AgentWorkflowStatus
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var lastFailure: String?
}

@MainActor
final class AgentOrchestratorStore: ObservableObject {
    @Published private(set) var workflows: [AgentWorkflow] = []
    @Published private(set) var activeWorkflowID: UUID?

    private let storageURL: URL

    init(storageURL overrideURL: URL? = nil) {
        if let overrideURL {
            storageURL = overrideURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = support.appendingPathComponent("CODO", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storageURL = directory.appendingPathComponent("agent-workflows.json")
        }
        load()
    }

    var activeWorkflow: AgentWorkflow? {
        guard let id = activeWorkflowID else { return nil }
        return workflows.first { $0.id == id }
    }

    private var isWorkflowActive: Bool {
        guard let status = activeWorkflow?.status else { return false }
        return status == .running || status == .awaitingApproval
    }

    @discardableResult
    func start(project: CODOProject, request: String, plan: [IntelligencePlanStep]) -> UUID {
        if let previous = activeWorkflowIndex, isWorkflowActive {
            workflows[previous].status = .cancelled
            workflows[previous].lastFailure = "Superseded by a newer workflow."
            if let running = workflows[previous].steps.firstIndex(where: {
                $0.status == .running || $0.status == .awaitingApproval
            }) {
                workflows[previous].steps[running].status = .cancelled
                workflows[previous].steps[running].finishedAt = .now
                workflows[previous].steps[running].resultSummary = "Superseded by a newer workflow."
            }
            for index in workflows[previous].steps.indices where workflows[previous].steps[index].status == .pending {
                workflows[previous].steps[index].status = .cancelled
                workflows[previous].steps[index].finishedAt = .now
                workflows[previous].steps[index].resultSummary = "Cancelled because a newer workflow replaced this one."
            }
            touchAndPersist(previous)
        }
        let steps = plan.map {
            AgentWorkflowStep(title: $0.title, detail: $0.detail, requiresApproval: $0.requiresApproval)
        }
        var workflow = AgentWorkflow(
            projectID: project.id,
            projectName: project.name,
            request: request,
            steps: steps,
            status: .awaitingApproval
        )
        if !workflow.steps.isEmpty {
            workflow.steps[0].status = .awaitingApproval
        }
        workflows.insert(workflow, at: 0)
        activeWorkflowID = workflow.id
        trimHistory()
        persist()
        return workflow.id
    }

    var currentStepTitle: String? { activeStep?.title }

    var completedStageContext: String {
        guard let workflow = activeWorkflow else { return "" }
        return workflow.steps
            .filter { $0.status == .succeeded && !($0.outputExcerpt ?? "").isEmpty }
            .map { "STAGE: " + $0.title + "\n" + ($0.outputExcerpt ?? "") }
            .joined(separator: "\n\n")
    }

    func completeCurrentAndAdvance(_ summary: String, output: String? = nil) {
        guard isWorkflowActive else { return }
        completeCurrentStep(summary, output: output)
        advanceToNextStep()
    }

    func proposalReady(output: String? = nil) {
        guard isWorkflowActive else { return }
        completeCurrentStep("Goose returned a proposal. No files were changed automatically.", output: output)
        advanceToNextStep()
    }

    func reviewCompleted(appliedCount: Int, rejectedCount: Int) {
        guard isWorkflowActive, let workflowIndex = activeWorkflowIndex else { return }
        completeCurrentStep("\(appliedCount) file(s) applied, \(rejectedCount) rejected.")
        if appliedCount == 0 {
            for index in workflows[workflowIndex].steps.indices where workflows[workflowIndex].steps[index].status == .pending {
                workflows[workflowIndex].steps[index].status = .cancelled
                workflows[workflowIndex].steps[index].finishedAt = .now
                workflows[workflowIndex].steps[index].resultSummary = "Skipped because no approved changes were applied."
            }
            workflows[workflowIndex].status = .cancelled
            activeWorkflowID = nil
            touchAndPersist(workflowIndex)
        } else {
            advanceToNextStep()
        }
    }

    func failCurrentStep(_ summary: String, output: String? = nil) {
        buildFailed(summary, output: output)
    }

    func cancelCurrentStep(_ summary: String, output: String? = nil) {
        guard isWorkflowActive, let workflowIndex = activeWorkflowIndex, let stepIndex = activeStepIndex else { return }
        workflows[workflowIndex].steps[stepIndex].status = .cancelled
        workflows[workflowIndex].steps[stepIndex].finishedAt = .now
        workflows[workflowIndex].steps[stepIndex].resultSummary = summary
        workflows[workflowIndex].steps[stepIndex].outputExcerpt = sanitizedExcerpt(output)
        for index in workflows[workflowIndex].steps.indices where index > stepIndex &&
            workflows[workflowIndex].steps[index].status == .pending {
            workflows[workflowIndex].steps[index].status = .cancelled
            workflows[workflowIndex].steps[index].finishedAt = .now
            workflows[workflowIndex].steps[index].resultSummary = "Cancelled because the workflow was stopped."
        }
        workflows[workflowIndex].lastFailure = summary
        workflows[workflowIndex].status = .cancelled
        activeWorkflowID = nil
        touchAndPersist(workflowIndex)
    }

    func approveCurrentStep() {
        guard let index = activeStepIndex, let workflowIndex = activeWorkflowIndex else { return }
        guard workflows[workflowIndex].steps[index].status == .awaitingApproval else { return }
        workflows[workflowIndex].steps[index].status = .running
        workflows[workflowIndex].steps[index].startedAt = .now
        workflows[workflowIndex].steps[index].attemptCount = (workflows[workflowIndex].steps[index].attemptCount ?? 0) + 1
        workflows[workflowIndex].status = .running
        touchAndPersist(workflowIndex)
    }

    func buildSucceeded(output: String? = nil) {
        guard isWorkflowActive else { return }
        completeCurrentStep("Approved build/test completed successfully.", output: output)
        advanceToNextStep()
        if activeStep != nil {
            completeCurrentStep("Outcome recorded in project activity.")
        }
        finishIfComplete()
    }

    func buildFailed(_ summary: String, output: String? = nil) {
        guard isWorkflowActive, let index = activeWorkflowIndex, let step = activeStepIndex else { return }
        workflows[index].steps[step].status = .failed
        workflows[index].steps[step].finishedAt = .now
        workflows[index].steps[step].resultSummary = summary
        workflows[index].steps[step].errorMessage = summary
        workflows[index].steps[step].outputExcerpt = sanitizedExcerpt(output)
        workflows[index].lastFailure = summary
        workflows[index].status = .failed
        touchAndPersist(index)
    }

    func resumeForFix() {
        // A failed workflow is kept as history after relaunch, so it may no longer
        // have an activeWorkflowID. Re-select the newest failed workflow when needed.
        guard let workflowIndex = activeWorkflowIndex ?? workflows.firstIndex(where: {
            $0.status == .failed && $0.steps.contains(where: {
                $0.title.localizedCaseInsensitiveContains("Implement the change")
            })
        }) else { return }
        activeWorkflowID = workflows[workflowIndex].id
        guard let implementationIndex = workflows[workflowIndex].steps.firstIndex(where: {
            $0.title.localizedCaseInsensitiveContains("Implement the change")
        }) else { return }
        for index in workflows[workflowIndex].steps.indices {
            if index >= implementationIndex {
                workflows[workflowIndex].steps[index].status = .pending
                workflows[workflowIndex].steps[index].startedAt = nil
                workflows[workflowIndex].steps[index].finishedAt = nil
                workflows[workflowIndex].steps[index].resultSummary = nil
                workflows[workflowIndex].steps[index].outputExcerpt = nil
                workflows[workflowIndex].steps[index].errorMessage = nil
            }
        }
        workflows[workflowIndex].steps[implementationIndex].status = .running
        workflows[workflowIndex].steps[implementationIndex].startedAt = .now
        workflows[workflowIndex].steps[implementationIndex].attemptCount = (workflows[workflowIndex].steps[implementationIndex].attemptCount ?? 0) + 1
        workflows[workflowIndex].lastFailure = nil
        workflows[workflowIndex].status = .running
        touchAndPersist(workflowIndex)
    }

    private var activeWorkflowIndex: Int? {
        guard let id = activeWorkflowID else { return nil }
        return workflows.firstIndex { $0.id == id }
    }

    private var activeStepIndex: Int? {
        guard let workflow = activeWorkflow else { return nil }
        return workflow.steps.firstIndex { $0.status == .running || $0.status == .awaitingApproval }
    }

    private var activeStep: AgentWorkflowStep? {
        guard isWorkflowActive, let workflow = activeWorkflow, let index = activeStepIndex else { return nil }
        return workflow.steps[index]
    }

    private func completeCurrentStep(_ summary: String, output: String? = nil) {
        guard let workflowIndex = activeWorkflowIndex, let stepIndex = activeStepIndex else { return }
        workflows[workflowIndex].steps[stepIndex].status = .succeeded
        workflows[workflowIndex].steps[stepIndex].finishedAt = .now
        workflows[workflowIndex].steps[stepIndex].resultSummary = summary
        workflows[workflowIndex].steps[stepIndex].outputExcerpt = sanitizedExcerpt(output)
        workflows[workflowIndex].steps[stepIndex].errorMessage = nil
        touchAndPersist(workflowIndex)
    }

    private func sanitizedExcerpt(_ output: String?) -> String? {
        guard let output, !output.isEmpty else { return nil }
        return BuildFailureAnalyzer.sanitizeLog(String(output.suffix(5_000)))
    }

    private func advanceToNextStep() {
        guard let workflowIndex = activeWorkflowIndex else { return }
        guard let next = workflows[workflowIndex].steps.firstIndex(where: { $0.status == .pending }) else {
            finishIfComplete()
            return
        }
        if workflows[workflowIndex].steps[next].requiresApproval {
            workflows[workflowIndex].steps[next].status = .awaitingApproval
            workflows[workflowIndex].status = .awaitingApproval
        } else {
            workflows[workflowIndex].steps[next].status = .running
            workflows[workflowIndex].steps[next].startedAt = .now
            workflows[workflowIndex].steps[next].attemptCount = (workflows[workflowIndex].steps[next].attemptCount ?? 0) + 1
            workflows[workflowIndex].status = .running
        }
        touchAndPersist(workflowIndex)
    }

    private func finishIfComplete() {
        guard let index = activeWorkflowIndex else { return }
        let allFinished = workflows[index].steps.allSatisfy { $0.status == .succeeded }
        if allFinished {
            workflows[index].status = .succeeded
            activeWorkflowID = nil
            touchAndPersist(index)
        }
    }

    private func touchAndPersist(_ index: Int) {
        workflows[index].updatedAt = .now
        persist()
    }

    private func trimHistory() {
        if workflows.count > 20 { workflows = Array(workflows.prefix(20)) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([AgentWorkflow].self, from: data) else { return }
        workflows = saved.map { item in
            var restored = item
            if restored.status == .running || restored.status == .awaitingApproval {
                restored.status = .failed
                restored.lastFailure = "CODO closed before this workflow completed."
                for index in restored.steps.indices where restored.steps[index].status == .running || restored.steps[index].status == .awaitingApproval {
                    restored.steps[index].status = .failed
                    restored.steps[index].finishedAt = .now
                    restored.steps[index].resultSummary = restored.lastFailure
                    restored.steps[index].errorMessage = restored.lastFailure
                }
            }
            return restored
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(workflows) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
