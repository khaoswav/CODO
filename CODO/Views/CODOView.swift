import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case files = "Files"
    case project = "Project"
    case intelligence = "Intelligence"
    case workspace = "AI Workspace"
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
    @State private var tab: WorkspaceTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(CODOTheme.border)
            HStack(spacing: 0) {
                projectRail
                Rectangle().fill(CODOTheme.border).frame(width: 1)
                Group {
                    switch tab {
                    case .overview: DashboardView(selectedTab: $tab)
                    case .files: ProjectBrowserView()
                    case .project: ProjectOverviewView()
                    case .intelligence: DeveloperIntelligenceView()
                    case .workspace: WorkspaceView()
                    case .terminal: TerminalView()
                    case .activity: ActivityView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(CODOTheme.background)
        .foregroundStyle(CODOTheme.primaryText)
        .environmentObject(taskQueue)
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(CODOTheme.accent).frame(width: 29, height: 29)
                    Image(systemName: "command").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                Text("CODO").font(.system(size: 16, weight: .bold, design: .rounded)).tracking(1.4)
            }
            Rectangle().fill(CODOTheme.border).frame(width: 1, height: 22)
            HStack(spacing: 5) {
                ForEach(WorkspaceTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: item.symbol).font(.system(size: 12))
                            Text(item.rawValue).font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(tab == item ? CODOTheme.primaryText : CODOTheme.secondaryText)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(tab == item ? CODOTheme.elevated : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(CODOTheme.green).frame(width: 6, height: 6)
                Text("Local environment").font(.system(size: 11, weight: .medium)).foregroundStyle(CODOTheme.secondaryText)
            }
            Button {} label: {
                Image(systemName: "gearshape").font(.system(size: 15)).foregroundStyle(CODOTheme.secondaryText)
                    .padding(8).background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 22).frame(height: 58)
        .background(CODOTheme.background)
    }

    private var projectRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("PROJECTS").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Button { store.importProject() } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold)).foregroundStyle(CODOTheme.secondaryText)
                }.buttonStyle(.plain)
            }
            VStack(spacing: 4) {
                ForEach(store.projects) { project in
                    Button {
                        store.selectedProjectID = project.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: project.kind.symbol)
                                .font(.system(size: 13))
                                .foregroundStyle(store.selectedProjectID == project.id ? CODOTheme.accent : CODOTheme.secondaryText)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(project.name).font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(CODOTheme.primaryText)
                                Text(project.kind.rawValue).font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 9)
                        .background(store.selectedProjectID == project.id ? CODOTheme.accentSoft : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("CODO STUDIO").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(CODOTheme.mutedText)
                Text("Think. Code. Create.").font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
            }
        }
        .padding(16).frame(width: 218).background(CODOTheme.background)
    }
}
