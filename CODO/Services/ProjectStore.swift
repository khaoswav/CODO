import AppKit
import Foundation
import SwiftUI

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [CODOProject] = []
    @Published var selectedProjectID: UUID?

    private let storageURL: URL
    private let maximumPreviewSize = 256 * 1024
    private let textExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "cs", "js", "jsx", "ts", "tsx",
        "json", "md", "txt", "yml", "yaml", "toml", "xml", "plist", "sh", "py", "rb",
        "html", "css", "scss", "sql", "gitignore", "entitlements", "xcconfig"
    ]

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("CODO", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("projects.json")
        load()
        selectedProjectID = projects.first?.id
    }

    var selectedProject: CODOProject? {
        projects.first { $0.id == selectedProjectID }
    }

    func importProject() {
        let panel = NSOpenPanel()
        panel.title = "Import Project"
        panel.message = "Choose a project folder to add to your CODO workspace."
        panel.prompt = "Import"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let resolvedURL = url.standardizedFileURL

        if let existing = projects.first(where: {
            URL(fileURLWithPath: $0.path).standardizedFileURL == resolvedURL
        }) {
            selectedProjectID = existing.id
            return
        }

        let bookmark = try? resolvedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let project = CODOProject(
            name: resolvedURL.lastPathComponent,
            path: resolvedURL.path,
            kind: ProjectKind.detect(at: resolvedURL),
            bookmarkData: bookmark
        )
        projects.insert(project, at: 0)
        selectedProjectID = project.id
        save()
    }

    func files(in directory: URL, for project: CODOProject) -> [CODOProjectFile] {
        withProjectAccess(project) { root in
            let target = directory.resolvingSymlinksInPath().standardizedFileURL
            let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
            guard target.path == canonicalRoot.path || target.path.hasPrefix(canonicalRoot.path + "/") else { return [] }
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: target,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isHiddenKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { return [] }

            return urls.compactMap { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isHiddenKey])
                guard values?.isHidden != true else { return nil }
                return CODOProjectFile(
                    url: url,
                    isDirectory: values?.isDirectory == true,
                    size: Int64(values?.fileSize ?? 0)
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } ?? []
    }

    func textPreview(of file: URL, in project: CODOProject) -> String? {
        withProjectAccess(project) { root in
            let target = file.resolvingSymlinksInPath().standardizedFileURL
            let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
            guard target.path.hasPrefix(canonicalRoot.path + "/"),
                  !FileManager.default.directoryExists(at: target),
                  textExtensions.contains(target.pathExtension.lowercased()),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: target.path),
                  let size = attributes[.size] as? NSNumber,
                  size.intValue <= maximumPreviewSize,
                  let data = try? Data(contentsOf: target),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return text
        } ?? nil
    }

    private func withProjectAccess<T>(_ project: CODOProject, perform: (URL) -> T) -> T? {
        guard let root = projectRootURL(for: project)?.standardizedFileURL else { return nil }
        let didStart = project.bookmarkData != nil ? root.startAccessingSecurityScopedResource() : false
        defer {
            if didStart { root.stopAccessingSecurityScopedResource() }
        }
        return perform(root)
    }

    func analyze(_ project: CODOProject) -> ProjectAnalysis? {
        withProjectAccess(project) { root in
            ProjectAnalyzer.analyze(at: root, kind: project.kind)
        } ?? nil
    }

    func developerIntelligence(_ project: CODOProject) async -> DeveloperIntelligenceReport? {
        guard let root = projectRootURL(for: project)?.standardizedFileURL else { return nil }
        let needsScope = project.bookmarkData != nil
        let projectName = project.name
        return await Task.detached(priority: .userInitiated) {
            let didStart = needsScope ? root.startAccessingSecurityScopedResource() : false
            if needsScope && !didStart { return nil as DeveloperIntelligenceReport? }
            defer { if didStart { root.stopAccessingSecurityScopedResource() } }
            return DeveloperIntelligenceService.analyze(root: root, projectName: projectName)
        }.value
    }

    func projectMemory(_ project: CODOProject) -> ProjectMemory {
        ProjectMemoryStore.load(project: project)
    }

    func saveProjectMemory(_ memory: ProjectMemory) throws {
        try ProjectMemoryStore.save(memory)
    }

    func projectRootURL(for project: CODOProject) -> URL? {
        guard let bookmarkData = project.bookmarkData else {
            return URL(fileURLWithPath: project.path)
        }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([CODOProject].self, from: data) else { return }
        projects = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
