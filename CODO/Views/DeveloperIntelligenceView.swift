import SwiftUI

private struct LanguageCountRow: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct DeveloperIntelligenceView: View {
    let onStartTask: (String) -> Void
    private enum GitAction: String, Identifiable {
        case createBranch = "Create branch"
        case commit = "Commit staged changes"
        case push = "Push branch"
        case pullRequest = "Create pull request"
        var id: String { rawValue }
    }
    @EnvironmentObject private var store: ProjectStore
    @State private var report: DeveloperIntelligenceReport?
    @State private var memory = ProjectMemory(projectID: UUID(), projectName: "")
    @State private var request = ""
    @State private var plan: [IntelligencePlanStep] = []
    @State private var isAnalyzing = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    @StateObject private var git = GitWorkflowService()
    @State private var branchName = "feature/"
    @State private var commitMessage = ""
    @State private var pendingGitAction: GitAction?

    private var project: CODOProject? { store.selectedProject }
    private var languageRows: [LanguageCountRow] {
        (report?.languageCounts ?? [:]).map { LanguageCountRow(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isAnalyzing {
                            ProgressView("Mapping source files and dependencies…")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                                .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                        if let report {
                            summaryPanel(report)
                            architecturePanel(report)
                            findingsPanel(report)
                        } else {
                            ContentUnavailableView(
                                "No intelligence report yet",
                                systemImage: "brain",
                                description: Text("Analyze the selected project to map its source structure, dependencies and code-quality signals.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                        }
                        buildFailurePanel
                        taskPlannerPanel
                        gitWorkflowPanel
                        projectMemoryPanel
                    }
                    .padding(22)
                    .frame(maxWidth: 1000, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("No Project Selected", systemImage: "folder",
                    description: Text("Import a project to start Developer Intelligence."))
            }
        }
        .background(CODOTheme.background)
        .onAppear(perform: loadProject)
        .onChange(of: store.selectedProjectID) { _, _ in loadProject() }
        .confirmationDialog(
            "Approve Git operation?",
            isPresented: Binding(
                get: { pendingGitAction != nil },
                set: { if !$0 { pendingGitAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Approve and run", role: .destructive) {
                guard let action = pendingGitAction, let project,
                      let root = store.projectRootURL(for: project) else { return }
                switch action {
                case .createBranch:
                    git.createBranch(branchName, project: project, root: root, approvalGranted: true)
                case .commit:
                    git.commitStagedChanges(commitMessage, project: project, root: root, approvalGranted: true)
                case .push:
                    git.push(project: project, root: root, approvalGranted: true)
                case .pullRequest:
                    git.createPullRequest(project: project, root: root, approvalGranted: true)
                }
                pendingGitAction = nil
            }
            Button("Cancel", role: .cancel) { pendingGitAction = nil }
        } message: {
            Text("This operation changes Git history or publishes code to the remote repository. Review the action before approving.")
        }
        .alert("Project memory", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Developer Intelligence").font(.system(size: 19, weight: .semibold))
                Text("Architecture · Dependencies · Quality · Project memory")
                    .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
            }
            Spacer()
            Button {
                analyze()
            } label: {
                Label(isAnalyzing ? "Analyzing…" : "Analyze project", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(project == nil || isAnalyzing)
        }
        .padding(.horizontal, 22)
        .frame(height: 66)
    }

    private func summaryPanel(_ report: DeveloperIntelligenceReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Project map", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(report.generatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
            }
            Text(report.summary).font(.system(size: 12)).foregroundStyle(CODOTheme.secondaryText)
            HStack(spacing: 10) {
                metric(String(report.files.count), label: "FILES")
                metric(String(report.totalLines), label: "LINES")
                metric(String(report.graphEdges.count), label: "LOCAL EDGES")
                metric(String(report.findings.count), label: "FINDINGS")
            }
            if report.truncated {
                Label("Scan limit reached. This report covers the first 4,000 supported source/config files.",
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10)).foregroundStyle(CODOTheme.orange)
            }
            if !languageRows.isEmpty {
                Divider().overlay(CODOTheme.border)
                Text("LANGUAGES & FILE TYPES").font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(CODOTheme.mutedText)
                ForEach(languageRows) { row in
                    HStack {
                        Text(row.name).font(.system(size: 11))
                        Spacer()
                        Text("\(row.count) files").font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(CODOTheme.secondaryText)
                    }
                }
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 19, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 8, weight: .bold)).tracking(0.8)
                .foregroundStyle(CODOTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
    }

    private func architecturePanel(_ report: DeveloperIntelligenceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Resolved source graph", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 13, weight: .semibold))
            Text("\(report.files.count) file nodes · \(report.graphEdges.count) resolved local edges · \(max(0, report.dependencies.count - report.graphEdges.count)) external or unresolved imports")
                .font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
            if report.graphEdges.isEmpty {
                Text("No unambiguous local file-to-file dependencies were resolved. External imports are intentionally excluded from the local graph.")
                    .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
            } else {
                ForEach(report.graphEdges.prefix(100)) { edge in
                    HStack(alignment: .top, spacing: 8) {
                        Text(edge.sourceFile).lineLimit(1)
                        Image(systemName: "arrow.right").foregroundStyle(CODOTheme.accent)
                        Text(edge.targetFile).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(edge.kind.uppercased()).font(.system(size: 8, weight: .bold))
                            .foregroundStyle(CODOTheme.mutedText)
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
                if report.graphEdges.count > 100 {
                    Text("Showing first 100 of \(report.graphEdges.count) resolved edges.")
                        .font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                }
            }
            Divider().overlay(CODOTheme.border)
            Text("SOURCE FILE INDEX").font(.system(size: 9, weight: .bold)).tracking(0.8)
                .foregroundStyle(CODOTheme.mutedText)
            ForEach(report.files.prefix(100)) { file in
                HStack(spacing: 8) {
                    Image(systemName: "doc.text").foregroundStyle(CODOTheme.accent)
                    Text(file.path).lineLimit(1)
                    Spacer()
                    Text("\(file.lineCount) lines")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(CODOTheme.mutedText)
                }
                .font(.system(size: 10, design: .monospaced))
            }
            if report.files.count > 100 {
                Text("Showing first 100 of \(report.files.count) files.")
                    .font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func findingsPanel(_ report: DeveloperIntelligenceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Code quality signals", systemImage: "checkmark.shield")
                .font(.system(size: 13, weight: .semibold))
            if report.findings.isEmpty {
                Label("No heuristic findings in the scanned files.", systemImage: "checkmark.circle")
                    .font(.system(size: 11)).foregroundStyle(CODOTheme.green)
            } else {
                ForEach(report.findings.prefix(120)) { finding in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: finding.severity == .critical ? "exclamationmark.octagon.fill" :
                                finding.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(finding.severity == .critical ? CODOTheme.red :
                                finding.severity == .warning ? CODOTheme.orange : CODOTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(finding.title).font(.system(size: 11, weight: .semibold))
                                Spacer()
                                Text(finding.severity.rawValue.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(CODOTheme.secondaryText)
                            }
                            Text(finding.filePath + (finding.line.map { ":\($0)" } ?? ""))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(CODOTheme.mutedText)
                            Text(finding.detail).font(.system(size: 10))
                                .foregroundStyle(CODOTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 5)
                }
                if report.findings.count > 120 {
                    Text("Showing first 120 of \(report.findings.count) findings.")
                        .font(.system(size: 10)).foregroundStyle(CODOTheme.mutedText)
                }
            }
            Text("These are static heuristics, not a compiler, profiler or security audit. Confirm findings before changing code.")
                .font(.system(size: 9)).foregroundStyle(CODOTheme.mutedText)
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private var buildFailurePanel: some View {
        let patterns = memory.buildFailurePatterns ?? []
        return VStack(alignment: .leading, spacing: 10) {
            Label("Build failure memory", systemImage: "waveform.path.ecg")
                .font(.system(size: 13, weight: .semibold))
            if patterns.isEmpty {
                Text("No recurring build errors have been recorded for this project yet. Failed Xcode, Unity and web builds will add diagnostic fingerprints here.")
                    .font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
            } else {
                ForEach(patterns.prefix(8)) { pattern in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(pattern.occurrenceCount) occurrence\(pattern.occurrenceCount == 1 ? "" : "s")")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(CODOTheme.orange)
                            Spacer()
                            Text(pattern.lastSeen.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 9)).foregroundStyle(CODOTheme.mutedText)
                        }
                        Text(pattern.summary).font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                        if let example = pattern.recentExamples.first, example != pattern.summary {
                            Text("Latest: " + example).font(.system(size: 9))
                                .foregroundStyle(CODOTheme.secondaryText)
                        }
                    }
                    .padding(9)
                    .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("Compiler diagnostics are fingerprinted and stored locally. CODO does not upload these logs to a server.")
                .font(.system(size: 9)).foregroundStyle(CODOTheme.mutedText)
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private var taskPlannerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Multi-step task planner", systemImage: "list.number")
                .font(.system(size: 13, weight: .semibold))
            TextField("Describe the feature or fix you want…", text: $request, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                Text("CODO prepares a staged workflow. File edits and build/test actions remain approval-gated.")
                    .font(.system(size: 9)).foregroundStyle(CODOTheme.secondaryText)
                Spacer()
                Button("Create plan") {
                    plan = IntelligenceTaskPlanner.makePlan(for: request)
                }
                .buttonStyle(.bordered)
                .disabled(request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !plan.isEmpty {
                HStack {
                    Text("\(plan.count) connected stages").font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
                    Spacer()
                    Button {
                        let steps = plan.enumerated().map { index, step in
                            String(index + 1) + ". " + step.title + ": " + step.detail
                        }.joined(separator: "\n")
                        let task = "User request: " + request + "\n\nFollow this staged workflow and report progress at each stage. Do not bypass file review or command approval:\n" + steps
                        onStartTask(task)
                    } label: {
                        Label("Continue in AI Workspace", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
                ForEach(plan.indices, id: \.self) { index in
                    let step = plan[index]
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(index + 1))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(CODOTheme.accent)
                            .frame(width: 23, height: 23)
                            .background(CODOTheme.accentSoft, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(step.title).font(.system(size: 11, weight: .semibold))
                                if step.requiresApproval {
                                    Text("APPROVAL").font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(CODOTheme.orange)
                                }
                            }
                            Text(step.detail).font(.system(size: 10))
                                .foregroundStyle(CODOTheme.secondaryText)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private var gitWorkflowPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Git workflow", systemImage: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Refresh") {
                    if let project, let root = store.projectRootURL(for: project) {
                        git.refresh(project: project, root: root)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(git.isRunning)
            }
            HStack {
                Text("CURRENT BRANCH").font(.system(size: 9, weight: .bold)).tracking(0.7)
                    .foregroundStyle(CODOTheme.mutedText)
                Spacer()
                Text(git.snapshot.branch).font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)
            }
            Text(git.statusMessage).font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
            TextField("New branch name", text: $branchName).textFieldStyle(.roundedBorder)
            HStack {
                Button("Create branch") { pendingGitAction = .createBranch }.buttonStyle(.bordered)
                Spacer()
                Button("Push") { pendingGitAction = .push }.buttonStyle(.bordered)
                Button("Create PR") { pendingGitAction = .pullRequest }.buttonStyle(.borderedProminent)
            }
            TextField("Commit message for staged files", text: $commitMessage)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Commit includes staged changes only. CODO will not stage every project file automatically.")
                    .font(.system(size: 9)).foregroundStyle(CODOTheme.secondaryText)
                Spacer()
                Button("Commit staged") { pendingGitAction = .commit }
                    .buttonStyle(.bordered)
                    .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !git.snapshot.status.isEmpty {
                Text(git.snapshot.status)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
            }
            if !git.output.isEmpty {
                Text(String(git.output.suffix(4_000)))
                    .font(.system(size: 9, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
            }
            if git.isRunning { ProgressView().controlSize(.small) }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private var projectMemoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Project memory", systemImage: "brain")
                .font(.system(size: 13, weight: .semibold))
            Text("Stored locally for this project in Application Support/CODO. Do not store API keys or passwords here.")
                .font(.system(size: 9)).foregroundStyle(CODOTheme.secondaryText)
            if let summary = memory.lastArchitectureSummary {
                Text("LAST SCAN: " + summary).font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
            }
            memoryField("Project purpose", text: $memory.purpose)
            memoryField("Architecture notes", text: $memory.architectureNotes)
            memoryListEditor(title: "Important decisions", items: $memory.decisions)
            memoryListEditor(title: "Next steps", items: $memory.nextSteps)
            HStack {
                Spacer()
                Button {
                    do {
                        try store.saveProjectMemory(memory)
                        saveMessage = "Project memory saved locally."
                    } catch {
                        saveMessage = error.localizedDescription
                    }
                    showSaveAlert = true
                } label: {
                    Label("Save project memory", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func memoryField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.7)
                .foregroundStyle(CODOTheme.mutedText)
            TextEditor(text: text)
                .font(.system(size: 11))
                .frame(minHeight: 58, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(5)
                .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func memoryListEditor(title: String, items: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.7)
                .foregroundStyle(CODOTheme.mutedText)
            ForEach(items.wrappedValue.indices, id: \.self) { index in
                HStack {
                    TextField(title, text: items[index])
                        .textFieldStyle(.roundedBorder)
                    Button {
                        items.wrappedValue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(CODOTheme.red)
                    }.buttonStyle(.plain)
                }
            }
            Button {
                items.wrappedValue.append("")
            } label: {
                Label("Add note", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private func loadProject() {
        guard let project else {
            report = nil
            plan = []
            return
        }
        memory = store.projectMemory(project)
        report = nil
        if let root = store.projectRootURL(for: project) {
            git.refresh(project: project, root: root)
        }
        analyze()
    }

    private func analyze() {
        guard let project else { return }
        isAnalyzing = true
        Task {
            let result = await store.developerIntelligence(project)
            guard store.selectedProjectID == project.id else { return }
            report = result
            if let result {
                memory.lastArchitectureSummary = result.summary
                try? store.saveProjectMemory(memory)
            }
            isAnalyzing = false
        }
    }
}
