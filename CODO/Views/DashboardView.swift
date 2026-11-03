import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ProjectStore
    @Binding var selectedTab: WorkspaceTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Development overview").font(.system(size: 25, weight: .semibold))
                        Text("Your projects, tools, and work in one place.")
                            .font(.system(size: 13)).foregroundStyle(CODOTheme.secondaryText)
                    }
                    Spacer()
                    Button { selectedTab = .workspace } label: {
                        Label("New task", systemImage: "plus").labelStyle(.titleAndIcon)
                    }.buttonStyle(AccentButtonStyle())
                }
                HStack(spacing: 12) {
                    MetricTile(title: "PROJECTS", value: "\(store.projects.count)", detail: "In your workspace", symbol: "square.stack.3d.up")
                    MetricTile(title: "RUNNING TASKS", value: "0", detail: "Nothing running", symbol: "arrow.trianglehead.2.clockwise")
                    MetricTile(title: "ENVIRONMENT", value: "Ready", detail: "Local workspace", symbol: "checkmark.circle")
                }
                Panel("Recent projects", accessory: "VIEW ALL") {
                    VStack(spacing: 0) {
                        ForEach(Array(store.projects.prefix(4))) { project in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 9).fill(CODOTheme.elevated)
                                    .frame(width: 38, height: 38)
                                    .overlay(Image(systemName: project.kind.symbol).foregroundStyle(CODOTheme.accent))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name).font(.system(size: 13, weight: .semibold))
                                    Text(project.path).font(.system(size: 11, design: .monospaced)).foregroundStyle(CODOTheme.mutedText)
                                }
                                Spacer()
                                Text(project.status.rawValue).font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CODOTheme.green)
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(CODOTheme.green.opacity(0.1), in: Capsule())
                                Button { store.selectedProjectID = project.id; selectedTab = .workspace } label: {
                                    Image(systemName: "arrow.up.right").foregroundStyle(CODOTheme.secondaryText)
                                }.buttonStyle(.plain)
                            }.padding(.vertical, 11)
                            if project.id != store.projects.prefix(4).last?.id {
                                Divider().overlay(CODOTheme.border)
                            }
                        }
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    Panel("Quick actions") {
                        VStack(spacing: 10) {
                            QuickAction(title: "Start an AI task", subtitle: "Describe what you want to build", symbol: "sparkles") { selectedTab = .workspace }
                            QuickAction(title: "Open terminal", subtitle: "Run commands in your project", symbol: "terminal") { selectedTab = .terminal }
                            QuickAction(title: "View activity", subtitle: "Review recent work and output", symbol: "clock.arrow.circlepath") { selectedTab = .activity }
                        }
                    }
                    Panel("Your workspace") {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Native macOS experience", systemImage: "macwindow").foregroundStyle(CODOTheme.primaryText)
                            Label("Local-first project data", systemImage: "externaldrive").foregroundStyle(CODOTheme.primaryText)
                            Label("Integration-ready architecture", systemImage: "puzzlepiece.extension").foregroundStyle(CODOTheme.primaryText)
                            Text("Connect execution tools in a later setup step.")
                                .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText).padding(.top, 4)
                        }.font(.system(size: 12))
                    }
                }
            }
            .padding(28).frame(maxWidth: 1120, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(title).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(CODOTheme.secondaryText)
                Spacer()
                Image(systemName: symbol).foregroundStyle(CODOTheme.accent).font(.system(size: 14))
            }
            Text(value).font(.system(size: 25, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(CODOTheme.mutedText)
        }
        .padding(17).frame(maxWidth: .infinity, alignment: .leading)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CODOTheme.border, lineWidth: 1))
    }
}

private struct QuickAction: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol).foregroundStyle(CODOTheme.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(CODOTheme.primaryText)
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
            }.padding(9).background(CODOTheme.elevated.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}
