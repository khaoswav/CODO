import SwiftUI

struct TerminalView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var taskQueue: TaskQueueStore
    @State private var selectedCommand: ProjectCommand = .location
    @State private var showApproval = false

    private var project: CODOProject? { store.selectedProject }
    private var availableCommands: [ProjectCommand] {
        ProjectCommand.available(for: project?.kind ?? .other) + ProjectCommand.buildCommands(for: project?.kind ?? .other)
    }
    private var selectedCommandPreview: String {
        guard let project, let root = store.projectRootURL(for: project) else { return selectedCommand.displayCommand }
        return ProjectBuildPlanner.plan(selectedCommand, root: root, project: project)?.display ?? selectedCommand.displayCommand
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if let project {
                commandBar(for: project)
                Divider().overlay(CODOTheme.border)
                queueSummary
                outputPanel
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "terminal",
                    description: Text("Import a project before running project diagnostics.")
                )
            }
        }
        .background(CODOTheme.background)
        .onChange(of: project?.kind) { _, _ in
            selectedCommand = availableCommands.first ?? .location
        }
        .alert("Approve project build?", isPresented: $showApproval) {
            Button("Cancel", role: .cancel) { }
            Button("Approve and run") { enqueueSelectedCommand(approved: true) }
        } message: {
            Text(approvalDescription)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Terminal").font(.system(size: 19, weight: .semibold))
                Text(project?.path ?? "Project command runner")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CODOTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(taskQueue.isRunning ? CODOTheme.orange : CODOTheme.green)
                    .frame(width: 7, height: 7)
                Text(taskQueue.processStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CODOTheme.secondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(CODOTheme.elevated, in: Capsule())
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
    }

    private func commandBar(for project: CODOProject) -> some View {
        HStack(spacing: 12) {
            Picker("Diagnostic command", selection: $selectedCommand) {
                ForEach(availableCommands) { command in
                    Text(command.rawValue).tag(command)
                }
            }
            .frame(maxWidth: 230)

            Text(selectedCommandPreview)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CODOTheme.secondaryText)
                .lineLimit(1)

            Spacer()

            Button {
                if selectedCommand.requiresApproval {
                    showApproval = true
                } else {
                    enqueueSelectedCommand(approved: false)
                }
            } label: {
                Label(selectedCommand.requiresApproval ? "Review & run" : "Queue task", systemImage: selectedCommand.requiresApproval ? "shield.checkered" : "plus")
            }
            .buttonStyle(AccentButtonStyle())

            Button {
                taskQueue.stopCurrent()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!taskQueue.isRunning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }


    private var approvalDescription: String {
        "Command: \\(selectedCommandPreview)\\n\\nCODO will run this build or test inside the imported project folder. It may create or modify build output and generated files. No arbitrary shell command is accepted."
    }

    private func enqueueSelectedCommand(approved: Bool) {
        guard let project, let root = store.projectRootURL(for: project) else { return }
        taskQueue.enqueue(selectedCommand, project: project, root: root, approvalGranted: approved)
    }

    private var queueSummary: some View {
        HStack(spacing: 14) {
            Label("\(taskQueue.runningCount) running", systemImage: "arrow.trianglehead.2.clockwise")
            Label("\(taskQueue.queuedCount) queued", systemImage: "clock")
            Spacer()
            Text("History saved locally")
                .foregroundStyle(CODOTheme.mutedText)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(CODOTheme.secondaryText)
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("LIVE OUTPUT", systemImage: "terminal")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Button("Clear") { taskQueue.clearLiveOutput() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(CODOTheme.secondaryText)
                    .disabled(taskQueue.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(CODOTheme.border)

            ScrollView {
                Text(taskQueue.liveOutput.isEmpty ? "Command output will appear here.\n\nQueued commands run one at a time. Only built-in diagnostic commands are available in this first version." : taskQueue.liveOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(CODOTheme.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(CODOTheme.elevated.opacity(0.45))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
