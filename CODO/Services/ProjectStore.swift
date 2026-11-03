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
        if projects.isEmpty {
            projects = [
                CODOProject(name: "SONARO", path: "~/Developer/SONARO", kind: .macOS),
                CODOProject(name: "Perspective", path: "~/Developer/Perspective", kind: .unity),
                CODOProject(name: "Arel", path: "~/Developer/Arel", kind: .iOS)
            ]
            save()
        }
        selectedProjectID = projects.first?.id
    }

    var selectedProject: CODOProject? {
        projects.first { $0.id == selectedProjectID }
    }

    func addSampleProject() {
        let project = CODOProject(name: "New Project", path: "~/Developer/New Project", kind: .macOS)
        projects.insert(project, at: 0)
        selectedProjectID = project.id
        save()
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
