import AppKit
import Foundation
import SwiftUI

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [CODOProject] = []
    @Published var selectedProjectID: UUID?

    private let storageURL: URL

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
        guard !projects.contains(where: { URL(fileURLWithPath: $0.path).standardizedFileURL == resolvedURL }) else {
            selectedProjectID = projects.first(where: {
                URL(fileURLWithPath: $0.path).standardizedFileURL == resolvedURL
            })?.id
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

    func resolvedURL(for project: CODOProject) -> URL? {
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
