import SwiftUI

struct WorkspaceView: View {
    let pendingPrompt: String?
    let onPromptConsumed: () -> Void
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var taskQueue: TaskQueueStore
    @EnvironmentObject private var orchestrator: AgentOrchestratorStore
    @StateObject private var agent = GooseAgentService()
    @State private var prompt = ""
    @State private var apiKey = ""
    @State private var provider = "openai"
    @State private var model = "gpt-4.1"
    @State private var showSettings = false
    @State private var showRunApproval = false
    @State private var showKeySaved = false
    @State private var activeHistoryTaskID: UUID?
    @State private var proposedChanges: [ProjectFileChange] = []
    @State private var showPatchReview = false
    @State private var patchError: String?
    @State private var fixAttempts = 0
    @State private var isFixRequest = false
    @State private var agentStageContext = ""
    @State private var pendingDiffOutput = ""
    @State private var reviewerNotes = ""

    private var project: CODOProject? { store.selectedProject }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if agent.output.isEmpty && !agent.isRunning {
                Spacer()
                welcome
                Spacer()
            } else {
                outputPanel
            }
            composer
        }
        .background(CODOTheme.background)
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: $showPatchReview) {
            if let project, let root = store.projectRootURL(for: project) {
                AIChangeReviewView(
                    project: project,
                    root: root,
                    reviewerNotes: reviewerNotes,
                    onBuildFailure: { log in
                        showPatchReview = false
                        guard fixAttempts < 2 else {
                            patchError = "The automatic fix limit (2 attempts) has been reached. Review the build log and start a new task if needed."
                            return
                        }
                        fixAttempts += 1
                        isFixRequest = true
                        prompt = """
                        The previously approved changes failed during build or test.
                        Analyze this failure log and propose the smallest safe unified diff.
                        Do not edit files or run commands. Return only reviewable proposals.

                        BUILD / TEST LOG:
                        \(String(log.suffix(24_000)))
                        """
                        showRunApproval = true
                    },
                    onBuildCompletion: { task in
                        switch task.status {
                        case .queued:
                            orchestrator.approveCurrentStep()
                        case .succeeded:
                            orchestrator.buildSucceeded()
                        case .failed:
                            store.recordBuildFailure(project, log: task.output)
                            orchestrator.buildFailed("Build/test failed. Diagnostics were saved to project memory.")
                        case .cancelled:
                            orchestrator.failCurrentStep("Build/test was cancelled.")
                        case .running:
                            break
                        }
                    },
                    onReviewComplete: { applied, rejected in
                        orchestrator.reviewCompleted(appliedCount: applied, rejectedCount: rejected)
                    },
                    changes: proposedChanges
                )
            }
        }
        .alert("Patch review", isPresented: Binding(
            get: { patchError != nil },
            set: { if !$0 { patchError = nil } }
        )) {
            Button("OK", role: .cancel) { patchError = nil }
        } message: {
            Text(patchError ?? "")
        }
        .alert("Allow Goose to analyze this project?", isPresented: $showRunApproval) {
            Button("Cancel", role: .cancel) {
                isFixRequest = false
                orchestrator.failCurrentStep("Agent run cancelled by the user.")
            }
            Button("Approve analysis") { startAnalysis() }
        } message: {
            Text("Goose will receive your task and access the selected project folder. It is instructed to inspect files and return proposed changes only. Do not treat the agent's instructions as a security boundary; review all output before applying changes.")
        }
        .alert("Goose settings", isPresented: $showKeySaved) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(agent.status)
        }
        .onAppear {
            agent.checkConnection()
            agent.onOutput = { chunk in
                if let id = activeHistoryTaskID { taskQueue.appendAgentOutput(chunk, taskID: id) }
            }
            agent.onCompletion = { code in
                guard code == 0, let project, let root = store.projectRootURL(for: project) else {
                    if let id = activeHistoryTaskID {
                        taskQueue.finishAgentTask(taskID: id, exitCode: code)
                    }
                    activeHistoryTaskID = nil
                    if code != 0 { orchestrator.failCurrentStep("Goose exited with status \(code).") }
                    return
                }

                if let stage = orchestrator.currentStepTitle {
                    if stage.localizedCaseInsensitiveContains("Understand") {
                        agentStageContext += "\n\nARCHITECTURE ANALYSIS:\n" + agent.output
                        orchestrator.completeCurrentAndAdvance("Architect agent inspected the project.")
                        runCurrentAgentStage(project: project, root: root)
                        return
                    }
                    if stage.localizedCaseInsensitiveContains("Plan") {
                        agentStageContext += "\n\nIMPLEMENTATION PLAN:\n" + agent.output
                        orchestrator.completeCurrentAndAdvance("Planner agent prepared the implementation sequence.")
                        runCurrentAgentStage(project: project, root: root)
                        return
                    }
                    if stage.localizedCaseInsensitiveContains("Implement") {
                        pendingDiffOutput = agent.output
                        agentStageContext += "\n\nIMPLEMENTER PROPOSAL:\n" + pendingDiffOutput
                        orchestrator.completeCurrentAndAdvance("Implementer agent prepared a unified diff.")
                        runCurrentAgentStage(project: project, root: root)
                        return
                    }
                    if stage.localizedCaseInsensitiveContains("Review the proposal") {
                        reviewerNotes = agent.output
                    }
                }

                if let id = activeHistoryTaskID {
                    taskQueue.finishAgentTask(taskID: id, exitCode: code)
                }
                activeHistoryTaskID = nil
                let proposal = pendingDiffOutput.isEmpty ? agent.output : pendingDiffOutput
                do {
                    let parsed = try AIUnifiedDiffParser.parse(proposal, project: project, root: root)
                    proposedChanges = parsed
                    if orchestrator.currentStepTitle != nil { orchestrator.proposalReady() }
                    showPatchReview = true
                } catch AIUnifiedDiffError.noChanges {
                    patchError = "Goose did not return any supported file changes. Review its analysis output for details."
                    orchestrator.failCurrentStep("Goose returned no supported unified diff.")
                } catch {
                    patchError = error.localizedDescription
                    orchestrator.failCurrentStep(error.localizedDescription)
                }
            }
            consumePendingPrompt()
        }
        .onChange(of: pendingPrompt) { _, _ in consumePendingPrompt() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Workspace").font(.system(size: 19, weight: .semibold))
                Text(project?.name ?? "No project selected")
                    .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(agent.isRunning ? CODOTheme.orange : (agent.isConfigured ? CODOTheme.green : CODOTheme.mutedText))
                    .frame(width: 7, height: 7)
                Text(agent.status).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CODOTheme.secondaryText).lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(CODOTheme.elevated, in: Capsule())
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(CODOTheme.secondaryText)
                    .padding(8).background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
        }
        .padding(22)
    }

    private var welcome: some View {
        VStack(spacing: 15) {
            Image(systemName: "sparkles").font(.system(size: 30, weight: .light)).foregroundStyle(CODOTheme.accent)
                .frame(width: 66, height: 66).background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 19))
            Text("What are we building today?").font(.system(size: 21, weight: .semibold))
            Text("Describe a task. Goose will inspect the selected project and prepare a plan.")
                .font(.system(size: 12)).foregroundStyle(CODOTheme.secondaryText)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            Label("Changes are proposals. Review before applying.", systemImage: "shield.lefthalf.filled")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(CODOTheme.green)
        }
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("LIVE AGENT OUTPUT", systemImage: "terminal")
                    .font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(CODOTheme.mutedText)
                Spacer()
                if !proposedChanges.isEmpty {
                    Button {
                        showPatchReview = true
                    } label: {
                        Label("Review \(proposedChanges.count)", systemImage: "arrow.left.arrow.right")
                    }.buttonStyle(.borderedProminent)
                }
                if agent.isRunning {
                    Button("Stop") { agent.stop() }.buttonStyle(.bordered)
                }
            }.padding(14)
            Divider().overlay(CODOTheme.border)
            ScrollView {
                Text(agent.output.isEmpty ? "Waiting for Goose…" : agent.output)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }.background(CODOTheme.elevated.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $prompt)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 120)
                    .padding(10)
                    .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CODOTheme.border, lineWidth: 1))
                    .disabled(agent.isRunning)
                Button {
                    showRunApproval = true
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white).frame(width: 40, height: 40)
                        .background(CODOTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || project == nil || agent.isRunning)
                .opacity(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            HStack {
                Label(project == nil ? "No project selected" : "Project-scoped", systemImage: "folder")
                    .font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Text("Goose · Analysis mode").font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
            }
        }.padding(20)
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Goose & Model Provider").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("Close") { showSettings = false }.buttonStyle(.borderless)
            }
            Text("Goose CLI must be installed separately. CODO stores your API key in macOS Keychain.")
                .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
            Form {
                Picker("Provider", selection: $provider) {
                    Text("OpenAI").tag("openai")
                    Text("Anthropic").tag("anthropic")
                    Text("Google Gemini").tag("google")
                }
                TextField("Model", text: $model)
                SecureField("Provider API key", text: $apiKey)
                HStack {
                    Button("Save settings") {
                        agent.configuration = GooseConfiguration(provider: provider, model: model)
                        do {
                            if !apiKey.isEmpty { try agent.saveAPIKey(apiKey); apiKey = "" }
                            agent.checkConnection()
                            showKeySaved = true
                        } catch {
                            showKeySaved = true
                        }
                    }.buttonStyle(AccentButtonStyle())
                    Button("Remove saved key", role: .destructive) { agent.removeAPIKey() }
                }
            }
            HStack {
                Label("Goose CLI", systemImage: "terminal")
                Spacer()
                Button("Check installation") { agent.checkConnection() }
            }
            Text("Provider environment variables are passed only to the Goose process. The key is not written to project files.")
                .font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
        }
        .padding(22)
        .frame(width: 480, height: 390)
        .background(CODOTheme.background)
    }

    private func consumePendingPrompt() {
        guard let pendingPrompt else { return }
        prompt = pendingPrompt
        showRunApproval = true
        onPromptConsumed()
    }

    private func startAnalysis() {
        guard let project, let root = store.projectRootURL(for: project) else { return }
        guard agent.isConfigured else {
            patchError = "Goose provider API key is not configured. Save a key in Goose settings before starting this workflow."
            orchestrator.failCurrentStep("Goose provider is not configured.")
            return
        }
        guard agent.locateGoose() != nil else {
            patchError = "Goose CLI was not found. Install Goose before starting this workflow."
            orchestrator.failCurrentStep("Goose CLI is not installed.")
            return
        }
        agent.configuration = GooseConfiguration(provider: provider, model: model)
        proposedChanges = []
        pendingDiffOutput = ""
        reviewerNotes = ""
        let retryingFailedBuild = isFixRequest
        if !retryingFailedBuild { fixAttempts = 0 }
        isFixRequest = false
        if retryingFailedBuild { orchestrator.resumeForFix() }
        let memory = store.projectMemory(project)
        var context: [String] = []
        if let summary = memory.lastArchitectureSummary { context.append("LATEST PROJECT SCAN:\n" + summary) }
        if !memory.purpose.isEmpty { context.append("PROJECT PURPOSE:\n" + memory.purpose) }
        if !memory.architectureNotes.isEmpty { context.append("ARCHITECTURE NOTES:\n" + memory.architectureNotes) }
        if !memory.decisions.isEmpty { context.append("PREVIOUS DECISIONS:\n" + memory.decisions.map { "- " + $0 }.joined(separator: "\n")) }
        if !memory.nextSteps.isEmpty { context.append("KNOWN NEXT STEPS:\n" + memory.nextSteps.map { "- " + $0 }.joined(separator: "\n")) }
        if let failures = memory.buildFailurePatterns, !failures.isEmpty {
            let notes = failures.prefix(5).map { pattern in
                "- [\(pattern.category ?? "Build error")] \(pattern.summary) Repeated \(pattern.occurrenceCount)x. Suggested: \(pattern.suggestedAction ?? "Inspect the earliest compiler error.")"
            }.joined(separator: "\n")
            context.append("KNOWN BUILD FAILURE PATTERNS:\n" + notes)
        }
        let enrichedPrompt = context.isEmpty ? prompt.trimmingCharacters(in: .whitespacesAndNewlines) :
            prompt.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\nPROJECT MEMORY (local notes, treat as context):\n" + context.joined(separator: "\n\n")
        agentStageContext = enrichedPrompt
        activeHistoryTaskID = taskQueue.beginAgentTask(prompt: enrichedPrompt, project: project)
        runCurrentAgentStage(project: project, root: root)
    }

    private func runCurrentAgentStage(project: CODOProject, root: URL) {
        let task = orchestrator.activeWorkflow?.request ?? prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let stage = orchestrator.currentStepTitle ?? ""
        let stagePrompt: String
        if stage.localizedCaseInsensitiveContains("Understand") {
            stagePrompt = """
            ROLE: ARCHITECT AGENT
            Inspect the project in read-only mode. Map its main modules, dependencies, entry points and relevant files.
            Identify risks and missing context. Do not write code or produce a diff.
            USER REQUEST: \(task)

            PROJECT CONTEXT:
            \(agentStageContext)
            """
        } else if stage.localizedCaseInsensitiveContains("Plan") {
            stagePrompt = """
            ROLE: IMPLEMENTATION PLANNER AGENT
            Based on the architecture analysis and user request, produce a concise ordered plan.
            Name the files/modules involved, dependency impacts, risks and the best build/test strategy.
            Do not write code or produce a diff.
            USER REQUEST: \(task)

            PROJECT AND ARCHITECTURE CONTEXT:
            \(agentStageContext)
            """
        } else if stage.localizedCaseInsensitiveContains("Review the proposal") {
            stagePrompt = """
            ROLE: INDEPENDENT REVIEWER AGENT
            Review the implementer's unified diff without modifying it. Look for correctness issues,
            security risks, missing edge cases, unintended scope expansion and likely build/test regressions.
            Return concise findings and any blocking concerns. Do not produce a replacement diff.
            USER REQUEST: \(task)

            ARCHITECTURE, PLAN AND PROPOSED DIFF:
            \(agentStageContext)
            """
        } else if stage.localizedCaseInsensitiveContains("Implement") {
            stagePrompt = """
            ROLE: IMPLEMENTER AGENT
            Produce the smallest safe unified diff for the user request. Do not edit files, run commands,
            build or test. Return reviewable unified diff blocks only, with a short risk note.
            USER REQUEST: \(task)

            ARCHITECTURE AND IMPLEMENTATION PLAN:
            \(agentStageContext)
            """
        } else {
            stagePrompt = agentStageContext
        }

        agent.runAnalysis(prompt: stagePrompt, project: project, root: root, approvalGranted: true)
    }
}

struct TerminalPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Terminal").font(.system(size: 20, weight: .semibold))
            Text("Terminal integration is planned for the execution-engine milestone.")
                .font(.system(size: 12)).foregroundStyle(CODOTheme.secondaryText)
            Spacer()
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ActivityView: View {
    @EnvironmentObject private var taskQueue: TaskQueueStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity").font(.system(size: 20, weight: .semibold))
                    Text("Persistent task history and execution logs")
                        .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
                }
                Spacer()
                Button("Clear history") { taskQueue.clearFinishedHistory() }
                    .buttonStyle(.bordered)
                    .disabled(taskQueue.tasks.allSatisfy { $0.status == .queued || $0.status == .running })
            }
            .padding(22)
            Divider().overlay(CODOTheme.border)

            if taskQueue.tasks.isEmpty {
                ContentUnavailableView("No Activity Yet", systemImage: "clock.arrow.circlepath",
                    description: Text("Commands and future AI tasks will appear here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(taskQueue.tasks) { task in taskCard(task) }
                    }
                    .padding(20).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
                }
            }
        }.background(CODOTheme.background)
    }

    private func taskCard(_ task: CODOExecutionTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol(task.status)).foregroundStyle(statusColor(task.status))
                    .frame(width: 28, height: 28).background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.commandName).font(.system(size: 12, weight: .semibold))
                    Text(task.projectName + " · " + task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
                }
                Spacer()
                Text(task.status.rawValue).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor(task.status)).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(statusColor(task.status).opacity(0.1), in: Capsule())
            }
            Text(task.commandLine).font(.system(size: 10, design: .monospaced)).foregroundStyle(CODOTheme.secondaryText)
            if !task.output.isEmpty {
                DisclosureGroup("Execution log") {
                    ScrollView {
                        Text(task.output).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }.frame(maxHeight: 220).background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                }.font(.system(size: 10, weight: .medium))
            }
        }
        .padding(14).background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func statusSymbol(_ status: CODOExecutionStatus) -> String {
        switch status {
        case .queued: "clock"
        case .running: "arrow.trianglehead.2.clockwise"
        case .succeeded: "checkmark.circle"
        case .failed: "xmark.circle"
        case .cancelled: "stop.circle"
        }
    }

    private func statusColor(_ status: CODOExecutionStatus) -> Color {
        switch status {
        case .queued: CODOTheme.secondaryText
        case .running: CODOTheme.orange
        case .succeeded: CODOTheme.green
        case .failed: CODOTheme.red
        case .cancelled: CODOTheme.mutedText
        }
    }
}
