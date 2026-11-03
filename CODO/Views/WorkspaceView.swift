import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var prompt = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Workspace").font(.system(size: 19, weight: .semibold))
                    Text(store.selectedProject?.name ?? "No project selected")
                        .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
                }
                Spacer()
                Label("Agent not connected", systemImage: "circle.dashed")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(CODOTheme.orange)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(CODOTheme.orange.opacity(0.1), in: Capsule())
            }.padding(22)
            Divider().overlay(CODOTheme.border)
            Spacer()
            VStack(spacing: 15) {
                Image(systemName: "sparkles").font(.system(size: 30, weight: .light)).foregroundStyle(CODOTheme.accent)
                    .frame(width: 66, height: 66).background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 19))
                Text("What are we building today?").font(.system(size: 21, weight: .semibold))
                Text("Describe a task. CODO will turn it into a development workflow.")
                    .font(.system(size: 12)).foregroundStyle(CODOTheme.secondaryText)
                Text("Task execution will be enabled when the local agent integration is connected.")
                    .font(.system(size: 11)).foregroundStyle(CODOTheme.mutedText)
                    .multilineTextAlignment(.center).frame(maxWidth: 420)
            }
            Spacer()
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 12) {
                    TextEditor(text: $prompt)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 72, maxHeight: 120)
                        .padding(10)
                        .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CODOTheme.border, lineWidth: 1))
                    Button {} label: {
                        Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white).frame(width: 40, height: 40)
                            .background(CODOTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).opacity(prompt.isEmpty ? 0.45 : 1)
                }
                HStack {
                    Label("Project-scoped", systemImage: "folder").font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                    Spacer()
                    Text("⌘ ↵ to run").font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                }
            }.padding(20)
        }
        .background(CODOTheme.background)
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
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Commands and future AI tasks will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(taskQueue.tasks) { task in
                            taskCard(task)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(CODOTheme.background)
    }

    private func taskCard(_ task: CODOExecutionTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol(task.status))
                    .foregroundStyle(statusColor(task.status))
                    .frame(width: 28, height: 28)
                    .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.commandName).font(.system(size: 12, weight: .semibold))
                    Text(task.projectName + " · " + task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
                }
                Spacer()
                Text(task.status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor(task.status))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(statusColor(task.status).opacity(0.1), in: Capsule())
            }

            Text(task.commandLine)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(CODOTheme.secondaryText)

            if !task.output.isEmpty {
                DisclosureGroup("Execution log") {
                    ScrollView {
                        Text(task.output)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 220)
                    .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                }
                .font(.system(size: 10, weight: .medium))
            }
        }
        .padding(14)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 11))
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
