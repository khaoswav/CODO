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

struct ActivityPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity").font(.system(size: 20, weight: .semibold))
            Text("Task history and execution logs will appear here.")
                .font(.system(size: 12)).foregroundStyle(CODOTheme.secondaryText)
            Spacer()
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
