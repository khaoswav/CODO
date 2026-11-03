import Foundation
import SwiftUI

enum AgentWorkflowStatus: String, Codable {
    case running = "Running"
    case awaitingApproval = "Awaiting approval"
    case succeeded = "Succeeded"
    case failed = "Failed"
}

enum AgentStepStatus: String, Codable {
    case pending = "Pending"
    case running = "Running"
    case awaitingApproval = "Awaiting approval"
    case succeeded = "Succeeded"
    case failed = "Failed"
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

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("CODO", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("agent-workflows.json")
        load()
    }

    var activeWorkflow: AgentWorkflow? {
        guard let id = activeWorkflowID else { return nil }
        return workflows.first { $0.id == id }
    }

    @discardableResult
    func start(project: CODOProject, request: String, plan: [IntelligencePlanStep]) -> UUID {
        let steps = plan.map {
            AgentWorkflowStep(title: $0.title, detail: $0.detail, requiresApproval: $0.requiresApproval)
        }
        var workflow = AgentWorkflow(
            projectID: project.id,
            projectName: project.name,
            request: request,
            steps: steps,
            status: .running
        )
        if !workflow.steps.isEmpty {
            workflow.steps[0].status = .running
            workflow.steps[0].startedAt = .now
        }
        workflows.insert(workflow, at: 0)
        activeWorkflowID = workflow.id
        trimHistory()
        persist()
        return workflow.id
    }

    func prepareAgentRunForImplementation() {
        guard activeWorkflowID != nil else { return }
        completeCurrentStep("Project context and saved intelligence loaded.")
        advanceToNextStep()
        if activeStep?.requiresApproval == false {
            completeCurrentStep("Implementation plan prepared.")
            advanceToNextStep()
        }
    }

    func proposalReady() {
        guard activeWorkflowID != nil else { return }
        completeCurrentStep("Goose returned a proposal. No files were changed automatically.")
        advanceToNextStep()
    }

    func reviewCompleted(appliedCount: Int, rejectedCount: Int) {
        guard activeWorkflowID != nil else { return }
        completeCurrentStep("\(appliedCount) file(s) applied, \(rejectedCount) rejected.")
        advanceToNextStep()
    }

    func approveCurrentStep() {
        guard let index = activeStepIndex, let workflowIndex = activeWorkflowIndex else { return }
        guard workflows[workflowIndex].steps[index].status == .awaitingApproval else { return }
        workflows[workflowIndex].steps[index].status = .running
        workflows[workflowIndex].steps[index].startedAt = .now
        workflows[workflowIndex].status = .running
        touchAndPersist(workflowIndex)
    }

    func buildSucceeded() {
        guard activeWorkflowID != nil else { return }
        completeCurrentStep("Approved build/test completed successfully.")
        advanceToNextStep()
        if activeStep != nil {
            completeCurrentStep("Outcome recorded in project activity.")
        }
        finishIfComplete()
    }

    func buildFailed(_ summary: String) {
        guard let index = activeWorkflowIndex, let step = activeStepIndex else { return }
        workflows[index].steps[step].status = .failed
        workflows[index].steps[step].finishedAt = .now
        workflows[index].steps[step].resultSummary = summary
        workflows[index].lastFailure = summary
        workflows[index].status = .failed
        touchAndPersist(index)
    }

    func resumeForFix() {
        guard let workflowIndex = activeWorkflowIndex else { return }
        guard let implementationIndex = workflows[workflowIndex].steps.firstIndex(where: {
            $0.title.localizedCaseInsensitiveContains("Implement")
        }) else { return }
        for index in workflows[workflowIndex].steps.indices {
            if index >= implementationIndex {
                workflows[workflowIndex].steps[index].status = .pending
                workflows[workflowIndex].steps[index].startedAt = nil
                workflows[workflowIndex].steps[index].finishedAt = nil
                workflows[workflowIndex].steps[index].resultSummary = nil
            }
        }
        workflows[workflowIndex].steps[implementationIndex].status = .running
        workflows[workflowIndex].steps[implementationIndex].startedAt = .now
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
        guard let workflow = activeWorkflow, let index = activeStepIndex else { return nil }
        return workflow.steps[index]
    }

    private func completeCurrentStep(_ summary: String) {
        guard let workflowIndex = activeWorkflowIndex, let stepIndex = activeStepIndex else { return }
        workflows[workflowIndex].steps[stepIndex].status = .succeeded
        workflows[workflowIndex].steps[stepIndex].finishedAt = .now
        workflows[workflowIndex].steps[stepIndex].resultSummary = summary
        touchAndPersist(workflowIndex)
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
                for index in restored.steps.indices where restored.steps[index].status == .running {
                    restored.steps[index].status = .failed
                    restored.steps[index].finishedAt = .now
                    restored.steps[index].resultSummary = restored.lastFailure
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
