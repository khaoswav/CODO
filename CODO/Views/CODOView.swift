import SwiftUI

struct CODOView: View {
    @EnvironmentObject private var store: ProjectStore
    @StateObject private var taskQueue = TaskQueueStore()
    @StateObject private var orchestrator = AgentOrchestratorStore()
    @State private var logoBreathing = false

    var body: some View {
        ZStack {
            CosmicBackdrop()
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(CODOTheme.border).frame(height: 1)
                HStack(spacing: 0) {
                    projectSidebar
                    Rectangle().fill(CODOTheme.border).frame(width: 1)
                    WorkspaceView(pendingPrompt: nil, onPromptConsumed: {})
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Rectangle().fill(CODOTheme.border).frame(width: 1)
                    agentActivityPanel
                }
            }
        }
        .foregroundStyle(CODOTheme.primaryText)
        .environmentObject(taskQueue)
        .environmentObject(orchestrator)
        .onAppear { logoBreathing = true }
        .preferredColorScheme(.dark)
    }


    private var agentActivityPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGENT CONTROL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(CODOTheme.mutedText)
                    Text(orchestrator.activeWorkflow == nil ? "Standing by" : "Live execution")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(CODOTheme.primaryText)
                }
                Spacer()
                Circle()
                    .fill(orchestrator.activeWorkflow == nil ? CODOTheme.accentSecondary : CODOTheme.glow)
                    .frame(width: 8, height: 8)
                    .shadow(color: CODOTheme.glow.opacity(0.8), radius: 8)
            }

            if let workflow = orchestrator.activeWorkflow {
                Text(workflow.request)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CODOTheme.secondaryText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(workflow.steps) { step in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: stepSymbol(for: step.status))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(stepColor(for: step.status))
                                .frame(width: 18, height: 18)
                                .background(stepColor(for: step.status).opacity(0.13), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(CODOTheme.primaryText)
                                Text(step.status.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(stepColor(for: step.status))
                                if let error = step.errorMessage, !error.isEmpty {
                                    Text(error)
                                        .font(.system(size: 9))
                                        .foregroundStyle(CODOTheme.red)
                                        .lineLimit(3)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(CODOTheme.accent.opacity(0.18))
                            .frame(width: 92, height: 92)
                            .blur(radius: 22)
                        Circle()
                            .stroke(CODOTheme.accent.opacity(0.35), lineWidth: 1)
                            .frame(width: 66, height: 66)
                        Circle()
                            .stroke(CODOTheme.glow.opacity(0.28), lineWidth: 1)
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(CODOTheme.highlight)
                            .shadow(color: CODOTheme.glow.opacity(0.7), radius: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    Text("Your agent is ready")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CODOTheme.primaryText)
                    Text("A task plan and its live steps will appear here when you start working.")
                        .font(.system(size: 10))
                        .foregroundStyle(CODOTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(CODOTheme.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(CODOTheme.border, lineWidth: 1))
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Label("Plan before changes", systemImage: "list.number")
                Label("Review before applying", systemImage: "checkmark.shield")
                Label("Verify with build and tests", systemImage: "checkmark.seal")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(CODOTheme.secondaryText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .padding(15)
        .frame(minWidth: 236, idealWidth: 236, maxWidth: 236, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func stepColor(for status: AgentStepStatus) -> Color {
        switch status {
        case .pending: CODOTheme.mutedText
        case .running: CODOTheme.highlight
        case .awaitingApproval: CODOTheme.orange
        case .succeeded: CODOTheme.green
        case .failed: CODOTheme.red
        case .cancelled: CODOTheme.mutedText
        }
    }

    private func stepSymbol(for status: AgentStepStatus) -> String {
        switch status {
        case .pending: "circle"
        case .running: "waveform"
        case .awaitingApproval: "hand.raised.fill"
        case .succeeded: "checkmark"
        case .failed: "exclamationmark"
        case .cancelled: "xmark"
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(CODOTheme.accentSecondary.opacity(0.22))
                    .frame(width: 38, height: 38)
                    .blur(radius: logoBreathing ? 11 : 5)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: [CODOTheme.accent, CODOTheme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 31, height: 31)
                    .overlay {
                        Image(systemName: "asterisk")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .rotationEffect(.degrees(logoBreathing ? 45 : 0))
                    }
                    .shadow(color: CODOTheme.accent.opacity(0.24), radius: 12, y: 3)
            }

            Text("CODO")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(2.2)

            Spacer()

            if let project = store.selectedProject {
                Label(project.name, systemImage: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CODOTheme.secondaryText)
                    .lineLimit(1)
            } else {
                Text("No project selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CODOTheme.mutedText)
            }

            Circle()
                .fill(CODOTheme.green)
                .frame(width: 6, height: 6)
                .shadow(color: CODOTheme.green.opacity(0.6), radius: 5)
            Text("Ready")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CODOTheme.secondaryText)
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: logoBreathing)
    }

    private var projectSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PROJECT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Button { store.importProject() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CODOTheme.accent)
                        .frame(width: 26, height: 26)
                        .background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Open project")
            }

            if store.projects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(CODOTheme.accent)
                    Text("Open a code project")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Choose a local project folder. Your agent will work inside that project.")
                        .font(.system(size: 10))
                        .foregroundStyle(CODOTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Choose project") { store.importProject() }
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(CODOTheme.accent)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13))
            } else {
                VStack(spacing: 5) {
                    ForEach(store.projects) { project in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.selectedProjectID = project.id
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: project.kind.symbol)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(store.selectedProjectID == project.id ? CODOTheme.accent : CODOTheme.secondaryText)
                                    .frame(width: 29, height: 29)
                                    .background(
                                        store.selectedProjectID == project.id ? CODOTheme.accentSoft : Color.primary.opacity(0.045),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(project.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(CODOTheme.primaryText)
                                        .lineLimit(1)
                                    Text(project.kind.rawValue)
                                        .font(.system(size: 9))
                                        .foregroundStyle(CODOTheme.mutedText)
                                }
                                Spacer(minLength: 0)
                                if store.selectedProjectID == project.id {
                                    Circle().fill(CODOTheme.accent).frame(width: 5, height: 5)
                                }
                            }
                            .padding(8)
                            .background {
                                if store.selectedProjectID == project.id {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(.regularMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .stroke(CODOTheme.accent.opacity(0.2), lineWidth: 1)
                                        }
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Label("Changes need your approval", systemImage: "lock.shield")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(CODOTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 218)
        .background(.ultraThinMaterial)
    }
}
