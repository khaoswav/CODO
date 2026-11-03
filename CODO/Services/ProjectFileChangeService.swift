import Foundation

struct ProjectFileChange: Identifiable {
    let id = UUID()
    let projectID: UUID
    let fileURL: URL
    let relativePath: String
    let originalText: String
    let proposedText: String
}

enum ProjectFileChangeError: LocalizedError {
    case outsideProject
    case unsupportedFile
    case fileTooLarge
    case fileChanged
    case accessDenied
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .outsideProject: "The selected file is outside the imported project."
        case .unsupportedFile: "Only supported text/source files can be edited."
        case .fileTooLarge: "The file exceeds the 256 KB editing limit."
        case .fileChanged: "The file changed after the review was prepared. Reload it before applying."
        case .accessDenied: "CODO could not access the project folder. Re-import the project if needed."
        case .writeFailed: "CODO could not write the approved file change."
        }
    }
}

enum ProjectFileChangeService {
    private static let maximumSize = 256 * 1024
    private static let allowedExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "cs", "js", "jsx", "ts", "tsx",
        "json", "md", "txt", "yml", "yaml", "toml", "xml", "plist", "sh", "py", "rb",
        "html", "css", "scss", "sql", "gitignore", "entitlements", "xcconfig"
    ]

    static func prepare(file: URL, project: CODOProject, root: URL, proposedText: String) throws -> ProjectFileChange {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let canonicalFile = file.resolvingSymlinksInPath().standardizedFileURL
        guard canonicalFile.path.hasPrefix(canonicalRoot.path + "/") else { throw ProjectFileChangeError.outsideProject }
        guard allowedExtensions.contains(canonicalFile.pathExtension.lowercased()) else { throw ProjectFileChangeError.unsupportedFile }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: canonicalFile.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue <= maximumSize,
              let originalData = try? Data(contentsOf: canonicalFile),
              let original = String(data: originalData, encoding: .utf8) else {
            throw ProjectFileChangeError.fileTooLarge
        }
        let relative = String(canonicalFile.path.dropFirst(canonicalRoot.path.count + 1))
        return ProjectFileChange(
            projectID: project.id,
            fileURL: canonicalFile,
            relativePath: relative,
            originalText: original,
            proposedText: proposedText
        )
    }

    static func apply(_ change: ProjectFileChange, project: CODOProject, root: URL, approved: Bool) throws {
        guard approved, change.projectID == project.id else { return }
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let canonicalFile = change.fileURL.resolvingSymlinksInPath().standardizedFileURL
        guard canonicalFile.path.hasPrefix(canonicalRoot.path + "/") else { throw ProjectFileChangeError.outsideProject }

        let didStart = project.bookmarkData != nil ? root.startAccessingSecurityScopedResource() : false
        if project.bookmarkData != nil && !didStart { throw ProjectFileChangeError.accessDenied }
        defer { if didStart { root.stopAccessingSecurityScopedResource() } }

        guard let currentData = try? Data(contentsOf: canonicalFile),
              let currentText = String(data: currentData, encoding: .utf8),
              currentText == change.originalText else {
            throw ProjectFileChangeError.fileChanged
        }

        let backupRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CODO/Backups/\(project.id.uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
            let backupName = "\(Int(Date().timeIntervalSince1970))-\(canonicalFile.lastPathComponent).bak"
            try currentData.write(to: backupRoot.appendingPathComponent(backupName), options: .atomic)
            try Data(change.proposedText.utf8).write(to: canonicalFile, options: .atomic)
        } catch {
            throw ProjectFileChangeError.writeFailed
        }
    }
}
