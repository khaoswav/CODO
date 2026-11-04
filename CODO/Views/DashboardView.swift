import SwiftUI

// Kept only while the legacy dashboard source remains in the Xcode target.
// The main CODO window no longer exposes dashboard navigation.
enum WorkspaceTab: String {
    case workspace
    case files
    case activity
}

struct DashboardView: View {
    @EnvironmentObject private var store: ProjectStore
    @Binding var selectedTab: WorkspaceTab
    @State private var orbMotion = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                hero

                HStack(spacing: 12) {
                    OverviewStat(value: "\(store.projects.count)", title: "Projects connected", symbol: "square.stack.3d.up")
                    OverviewStat(value: "Local", title: "Workspace", symbol: "macwindow")
                    OverviewStat(value: "Ready", title: "Agent environment", symbol: "sparkles")
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your workspace")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Pick up where you left off.")
                            .font(.system(size: 11))
                            .foregroundStyle(CODOTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        store.importProject()
                    } label: {
                        Label("Add project", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if store.projects.isEmpty {
                    emptyProjects
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 13)], spacing: 13) {
                        ForEach(store.projects) { project in
                            ProjectLaunchCard(project: project, isSelected: store.selectedProjectID == project.id) {
                                store.selectedProjectID = project.id
                                selectedTab = .workspace
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 13) {
                    HomeActionCard(
                        title: "Talk to your agent",
                        subtitle: "Describe a task in plain language.",
                        symbol: "sparkles",
                        tint: CODOTheme.accent
                    ) { selectedTab = .workspace }

                    HomeActionCard(
                        title: "Browse project files",
                        subtitle: "Explore the codebase and structure.",
                        symbol: "folder",
                        tint: CODOTheme.accentSecondary
                    ) { selectedTab = .files }

                    HomeActionCard(
                        title: "Recent activity",
                        subtitle: "See what has run and what changed.",
                        symbol: "clock.arrow.circlepath",
                        tint: CODOTheme.green
                    ) { selectedTab = .activity }
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { orbMotion = true }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x17243D), Color(hex: 0x202044), Color(hex: 0x152638)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(CODOTheme.accent.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 42)
                .offset(x: 560, y: -65)
            Circle()
                .stroke(CODOTheme.accent.opacity(0.16), lineWidth: 1)
                .frame(width: 230, height: 230)
                .overlay {
                    Circle().stroke(CODOTheme.accentSecondary.opacity(0.20), lineWidth: 1)
                        .padding(20)
                }
                .rotationEffect(.degrees(orbMotion ? 30 : -30))
                .offset(x: 610, y: 5)
            Circle()
                .fill(LinearGradient(colors: [CODOTheme.accent, CODOTheme.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 78, height: 78)
                .overlay {
                    Image(systemName: "asterisk")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .rotationEffect(.degrees(orbMotion ? 90 : 0))
                }
                .shadow(color: CODOTheme.accent.opacity(0.38), radius: 28)
                .offset(x: 686, y: 5)
                .scaleEffect(orbMotion ? 1.06 : 0.94)
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 7) {
                    Circle().fill(CODOTheme.accent).frame(width: 6, height: 6)
                    Text("YOUR AI DEVELOPMENT SPACE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(CODOTheme.accent)
                }
                Text("Build something\nextraordinary.")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One agent. Your projects. Your control.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.68))
                Button {
                    selectedTab = .workspace
                } label: {
                    HStack(spacing: 9) {
                        Text("Start a task")
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .padding(.top, 2)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
        .shadow(color: CODOTheme.accentSecondary.opacity(0.10), radius: 25, y: 12)
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: orbMotion)
    }

    private var emptyProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(CODOTheme.accent)
            Text("Your first project starts here")
                .font(.system(size: 15, weight: .semibold))
            Text("Import an Xcode, Unity, or web project. CODO will use it as the context for your agent tasks.")
                .font(.system(size: 11))
                .foregroundStyle(CODOTheme.secondaryText)
                .frame(maxWidth: 430, alignment: .leading)
            Button {
                store.importProject()
            } label: {
                Label("Choose a project", systemImage: "folder.badge.plus")
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(23)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CODOTheme.border, lineWidth: 1))
    }
}

private struct OverviewStat: View {
    let value: String
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CODOTheme.accent)
                .frame(width: 34, height: 34)
                .background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(title).font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CODOTheme.border, lineWidth: 1))
    }
}

private struct ProjectLaunchCard: View {
    let project: CODOProject
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: project.kind.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CODOTheme.accent)
                        .frame(width: 39, height: 39)
                        .background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                    Spacer()
                    if isSelected {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(CODOTheme.green)
                    }
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CODOTheme.mutedText)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CODOTheme.primaryText)
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(CODOTheme.mutedText)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Circle().fill(CODOTheme.green).frame(width: 5, height: 5)
                    Text(project.kind.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CODOTheme.secondaryText)
                    Spacer()
                    Text("Open agent")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(CODOTheme.accent)
                }
            }
            .padding(15)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(isSelected ? CODOTheme.accent.opacity(0.32) : CODOTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeActionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(CODOTheme.primaryText)
                    Text(subtitle).font(.system(size: 9)).foregroundStyle(CODOTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(CODOTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
