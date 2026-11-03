import SwiftUI

struct ProjectOverviewView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var analysis: ProjectAnalysis?
    @State private var isAnalyzing = false

    private var project: CODOProject? { store.selectedProject }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        projectIdentity(project)
                        if isAnalyzing {
                            ProgressView("Inspecting project…")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                                .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        } else if let analysis {
                            metadataPanel(analysis)
                            if !analysis.targets.isEmpty {
                                targetsPanel(analysis.targets)
                            }
                            if !analysis.warnings.isEmpty {
                                warningsPanel(analysis.warnings)
                            }
                        } else {
                            ContentUnavailableView(
                                "Analysis Unavailable",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text("CODO could not inspect this project folder.")
                            )
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "square.stack.3d.up",
                    description: Text("Import or select a project to inspect its structure.")
                )
            }
        }
        .background(CODOTheme.background)
        .onChange(of: store.selectedProjectID) { _, _ in inspectSelectedProject() }
        .onAppear { inspectSelectedProject() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project Overview")
                    .font(.system(size: 19, weight: .semibold))
                Text("Detected project structure and build information")
                    .font(.system(size: 11))
                    .foregroundStyle(CODOTheme.secondaryText)
            }
            Spacer()
            Button {
                inspectSelectedProject()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isAnalyzing || project == nil)
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
    }

    private func projectIdentity(_ project: CODOProject) -> some View {
        HStack(spacing: 14) {
            Image(systemName: project.kind.symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(CODOTheme.accent)
                .frame(width: 52, height: 52)
                .background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name).font(.system(size: 20, weight: .semibold))
                Text(project.kind.rawValue + " project")
                    .font(.system(size: 12))
                    .foregroundStyle(CODOTheme.secondaryText)
                Text(project.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CODOTheme.mutedText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func metadataPanel(_ analysis: ProjectAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Project details", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
            ForEach(analysis.metadata) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text(item.label)
                        .foregroundStyle(CODOTheme.secondaryText)
                    Spacer(minLength: 12)
                    Text(item.value)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                .font(.system(size: 12))
                if item.id != analysis.metadata.last?.id {
                    Divider().overlay(CODOTheme.border)
                }
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func targetsPanel(_ targets: [ProjectTarget]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Build targets", systemImage: "shippingbox")
                .font(.system(size: 13, weight: .semibold))
            ForEach(targets) { target in
                HStack(spacing: 10) {
                    Image(systemName: "app.dashed")
                        .foregroundStyle(CODOTheme.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name).font(.system(size: 12, weight: .medium))
                        Text(target.productType)
                            .font(.system(size: 10))
                            .foregroundStyle(CODOTheme.secondaryText)
                    }
                    Spacer()
                    Text(target.platform)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CODOTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CODOTheme.elevated, in: Capsule())
                }
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func warningsPanel(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes", systemImage: "exclamationmark.circle")
                .font(.system(size: 13, weight: .semibold))
            ForEach(warnings, id: \.self) { warning in
                Label(warning, systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(CODOTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func inspectSelectedProject() {
        guard let project else {
            analysis = nil
            return
        }
        isAnalyzing = true
        analysis = store.analyze(project)
        isAnalyzing = false
    }
}
