import SwiftUI

struct TerminalView: View {
    @EnvironmentObject private var store: ProjectStore
    @StateObject private var runner = ProjectProcessRunner()
    @State private var selectedCommand: ProjectCommand = .location

    private var project: CODOProject? { store.selectedProject }
    private var availableCommands: [ProjectCommand] {
        ProjectCommand.available(for: project?.kind ?? .other)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if let project {
                commandBar(for: project)
                Divider().overlay(CODOTheme.border)
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
                    .fill(runner.isRunning ? CODOTheme.orange : CODOTheme.green)
                    .frame(width: 7, height: 7)
                Text(runner.status)
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
            .disabled(runner.isRunning)

            Text(selectedCommand.displayCommand)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CODOTheme.secondaryText)
                .lineLimit(1)

            Spacer()

            Button {
                guard let root = store.projectRootURL(for: project) else { return }
                runner.run(selectedCommand, for: project, root: root)
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(runner.isRunning)

            Button {
                runner.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!runner.isRunning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("OUTPUT", systemImage: "terminal")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Button("Clear") { runner.clear() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(CODOTheme.secondaryText)
                    .disabled(runner.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(CODOTheme.border)

            ScrollView {
                Text(runner.output.isEmpty ? "Command output will appear here.\n\nOnly built-in diagnostic commands are available in this first version." : runner.output)
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
