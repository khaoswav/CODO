import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case overview = "Home"
    case files = "Files"
    case project = "Project"
    case intelligence = "Intelligence"
    case workspace = "Agent"
    case terminal = "Terminal"
    case activity = "Activity"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .files: "folder"
        case .project: "square.stack.3d.up"
        case .intelligence: "brain"
        case .workspace: "sparkles"
        case .terminal: "terminal"
        case .activity: "clock.arrow.circlepath"
        }
    }
}

struct CODOView: View {
    @EnvironmentObject private var store: ProjectStore
    @StateObject private var taskQueue = TaskQueueStore()
    @StateObject private var orchestrator = AgentOrchestratorStore()
    @State private var tab: WorkspaceTab = .overview
    @State private var pendingAgentTask: String?
    @State private var logoBreathing = false

    private let primaryTabs: [WorkspaceTab] = [.overview, .workspace, .files, .activity]

    var body: some View {
        ZStack {
            CosmicBackdrop()
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(CODOTheme.border).frame(height: 1)
                HStack(spacing: 0) {
                    projectRail
                    Rectangle().fill(CODOTheme.border).frame(width: 1)
                    Group {
                        switch tab {
                        case .overview:
                            DashboardView(selectedTab: $tab)
                        case .files:
                            ProjectBrowserView()
                        case .project:
                            ProjectOverviewView()
                        case .intelligence:
                            DeveloperIntelligenceView(onStartTask: { task in
                                pendingAgentTask = task
                                tab = .workspace
                            })
                        case .workspace:
                            WorkspaceView(pendingPrompt: pendingAgentTask, onPromptConsumed: {
                                pendingAgentTask = nil
                            })
                        case .terminal:
                            TerminalView()
                        case .activity:
                            ActivityView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.992)))
                }
            }
        }
        .foregroundStyle(CODOTheme.primaryText)
        .environmentObject(taskQueue)
        .environmentObject(orchestrator)
        .onAppear {
            logoBreathing = true
        }
    }

    private var topBar: some View {
        HStack(spacing: 22) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CODOTheme.accentSecondary.opacity(0.20))
                        .frame(width: 36, height: 36)
                        .blur(radius: logoBreathing ? 10 : 5)
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
                Text("STUDIO")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(CODOTheme.mutedText)
                    .padding(.top, 2)
            }
            .frame(width: 208, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(primaryTabs) { item in
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            tab = item
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(tab == item ? CODOTheme.primaryText : CODOTheme.secondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background {
                            if tab == item {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.regularMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CODOTheme.border, lineWidth: 1))
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Circle().fill(CODOTheme.green).frame(width: 6, height: 6)
                    .shadow(color: CODOTheme.green.opacity(0.6), radius: 5)
                Text("Workspace ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CODOTheme.secondaryText)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: logoBreathing)
    }

    private var projectRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("YOUR PROJECTS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Button { store.importProject() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CODOTheme.accent)
                        .frame(width: 25, height: 25)
                        .background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Import project")
            }

            if store.projects.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 21, weight: .light))
                        .foregroundStyle(CODOTheme.secondaryText)
                    Text("No projects yet")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Bring a project into CODO to start building with your agent.")
                        .font(.system(size: 10))
                        .foregroundStyle(CODOTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Import project") { store.importProject() }
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(CODOTheme.accent)
                        .padding(.top, 3)
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
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(store.selectedProjectID == project.id ? CODOTheme.accentSoft : Color.primary.opacity(0.045))
                                        .frame(width: 31, height: 31)
                                    Image(systemName: project.kind.symbol)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(store.selectedProjectID == project.id ? CODOTheme.accent : CODOTheme.secondaryText)
                                }
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background {
                                if store.selectedProjectID == project.id {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(.regularMaterial)
                                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(CODOTheme.accent.opacity(0.18), lineWidth: 1))
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 10)

            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    tab = .workspace
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New agent task")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundStyle(Color.black.opacity(0.86))
                .padding(11)
                .background(LinearGradient(colors: [CODOTheme.accent, Color(hex: 0xA5C7FF)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10))
                    .foregroundStyle(CODOTheme.green)
                Text("You stay in control")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(CODOTheme.mutedText)
            }
            .padding(.horizontal, 2)
        }
        .padding(15)
        .frame(width: 224)
        .background(.ultraThinMaterial)
    }
}
