import SwiftUI

struct ProjectBrowserView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var currentDirectory: URL?
    @State private var selectedFile: URL?
    @State private var previewText: String?
    @State private var isEditing = false
    @State private var draftText = ""
    @State private var pendingChange: ProjectFileChange?
    @State private var reviewError: String?

    private var project: CODOProject? { store.selectedProject }
    private var entries: [CODOProjectFile] {
        guard let project, let currentDirectory else { return [] }
        return store.files(in: currentDirectory, for: project)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if let project {
                HStack(spacing: 0) {
                    fileList(project)
                        .frame(minWidth: 270, idealWidth: 320, maxWidth: 390)
                    Rectangle().fill(CODOTheme.border).frame(width: 1)
                    previewPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder",
                    description: Text("Import a project folder to browse its files.")
                )
            }
        }
        .onChange(of: store.selectedProjectID) { _, _ in resetBrowser() }
        .onAppear { resetBrowser() }
        .background(CODOTheme.background)
        .sheet(item: $pendingChange) { change in
            if let project, let root = store.projectRootURL(for: project) {
                FileChangeReviewSheet(change: change, project: project, root: root) {
                    previewText = change.proposedText
                    isEditing = false
                }
            }
        }
        .alert("Could not prepare changes", isPresented: Binding(
            get: { reviewError != nil },
            set: { if !$0 { reviewError = nil } }
        )) {
            Button("OK", role: .cancel) { reviewError = nil }
        } message: {
            Text(reviewError ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project Files").font(.system(size: 19, weight: .semibold))
                Text(project?.path ?? "Select a project from the project list")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CODOTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button { store.importProject() } label: {
                Label("Import", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
    }

    private func fileList(_ project: CODOProject) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { navigateToParent(project) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(currentDirectory?.resolvingSymlinksInPath().standardizedFileURL == (store.projectRootURL(for: project) ?? URL(fileURLWithPath: project.path)).resolvingSymlinksInPath().standardizedFileURL)

                Image(systemName: "folder").foregroundStyle(CODOTheme.accent)
                Text(relativePath(for: project))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(CODOTheme.secondaryText)
                Spacer()
                Button {
                    selectedFile = nil
                    previewText = nil
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Clear file selection")
            }
            .padding(12)

            Divider().overlay(CODOTheme.border)

            if entries.isEmpty {
                ContentUnavailableView(
                    "Folder is Empty",
                    systemImage: "folder",
                    description: Text("There are no visible files in this folder.")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        Button {
                            if entry.isDirectory {
                                currentDirectory = entry.url
                                selectedFile = nil
                                previewText = nil
                                isEditing = false
                            } else {
                                selectedFile = entry.url
                                previewText = store.textPreview(of: entry.url, in: project)
                                isEditing = false
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: entry.isDirectory ? "folder.fill" : fileSymbol(for: entry))
                                    .foregroundStyle(entry.isDirectory ? CODOTheme.accent : CODOTheme.secondaryText)
                                    .frame(width: 18)
                                Text(entry.name)
                                    .lineLimit(1)
                                    .foregroundStyle(CODOTheme.primaryText)
                                Spacer(minLength: 4)
                                if !entry.isDirectory {
                                    Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(CODOTheme.mutedText)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedFile == entry.url ? CODOTheme.accentSoft : Color.clear)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .background(CODOTheme.surface)
    }

    private var previewPane: some View {
        Group {
            if let selectedFile {
                if let previewText {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Label(selectedFile.lastPathComponent, systemImage: "doc.text")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            if isEditing {
                                Button("Cancel") {
                                    draftText = previewText
                                    isEditing = false
                                }
                                .buttonStyle(.borderless)
                                Button("Review changes") { prepareChange() }
                                    .buttonStyle(AccentButtonStyle())
                            } else {
                                Text("Read-only preview")
                                    .font(.system(size: 10))
                                    .foregroundStyle(CODOTheme.mutedText)
                                Button("Edit") {
                                    draftText = previewText
                                    isEditing = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(14)
                        Divider().overlay(CODOTheme.border)
                        if isEditing {
                            TextEditor(text: $draftText)
                                .font(.system(size: 12, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(10)
                        } else {
                            ScrollView([.horizontal, .vertical]) {
                                Text(previewText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Preview Unavailable",
                        systemImage: "doc.questionmark",
                        description: Text("This file is unsupported or larger than 256 KB.")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Choose a file to preview or edit safely.")
                )
            }
        }
        .background(CODOTheme.background)
    }

    private func prepareChange() {
        guard let project, let selectedFile,
              let root = store.projectRootURL(for: project) else { return }
        do {
            pendingChange = try ProjectFileChangeService.prepare(
                file: selectedFile,
                project: project,
                root: root,
                proposedText: draftText
            )
        } catch {
            reviewError = error.localizedDescription
        }
    }

    private func resetBrowser() {
        guard let project else {
            currentDirectory = nil
            selectedFile = nil
            previewText = nil
            isEditing = false
            return
        }
        currentDirectory = store.projectRootURL(for: project)?.standardizedFileURL
        selectedFile = nil
        previewText = nil
        isEditing = false
    }

    private func navigateToParent(_ project: CODOProject) {
        guard let currentDirectory else { return }
        let root = (store.projectRootURL(for: project) ?? URL(fileURLWithPath: project.path)).resolvingSymlinksInPath().standardizedFileURL
        let parent = currentDirectory.deletingLastPathComponent().standardizedFileURL
        guard parent.path == root.path || parent.path.hasPrefix(root.path + "/") else { return }
        self.currentDirectory = parent
    }

    private func relativePath(for project: CODOProject) -> String {
        guard let currentDirectory else { return project.name }
        let root = URL(fileURLWithPath: project.path).standardizedFileURL.path
        let current = currentDirectory.standardizedFileURL.path
        if current == root { return project.name }
        return String(current.dropFirst(root.count + 1))
    }

    private func fileSymbol(for entry: CODOProjectFile) -> String {
        switch entry.url.pathExtension.lowercased() {
        case "swift": "swift"
        case "png", "jpg", "jpeg", "heic", "pdf": "doc.richtext"
        case "json", "plist", "yml", "yaml": "curlybraces"
        case "md", "txt": "doc.text"
        default: "doc"
        }
    }
}


private struct FileChangeReviewSheet: View {
    let change: ProjectFileChange
    let project: CODOProject
    let root: URL
    let onApplied: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review file changes").font(.system(size: 18, weight: .semibold))
                    Text(change.relativePath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CODOTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22))
                    .foregroundStyle(CODOTheme.accent)
            }

            Text("Compare the original and proposed content. Applying creates a backup first. CODO will refuse to overwrite the file if it changed since this review was prepared.")
                .font(.system(size: 11))
                .foregroundStyle(CODOTheme.secondaryText)

            HStack(spacing: 10) {
                reviewColumn(title: "ORIGINAL", content: change.originalText)
                reviewColumn(title: "PROPOSED", content: change.proposedText)
            }
            .frame(maxHeight: .infinity)

            if let errorMessage {
                Text(errorMessage).font(.system(size: 11)).foregroundStyle(CODOTheme.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Approve and apply") { apply() }
                    .buttonStyle(AccentButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .background(CODOTheme.background)
    }

    private func reviewColumn(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(1)
                .foregroundStyle(CODOTheme.mutedText)
            ScrollView([.horizontal, .vertical]) {
                Text(content)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func apply() {
        do {
            try ProjectFileChangeService.apply(change, project: project, root: root, approved: true)
            onApplied()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
