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
                }
            }
        }
        .foregroundStyle(CODOTheme.primaryText)
        .environmentObject(taskQueue)
        .environmentObject(orchestrator)
        .onAppear { logoBreathing = true }
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
