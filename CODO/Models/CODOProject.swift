import Foundation

struct CODOProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var kind: ProjectKind
    var bookmarkData: Data? = nil
    var updatedAt: Date = .now
    var status: ProjectStatus = .ready

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

struct CODOProjectFile: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

enum ProjectKind: String, Codable, CaseIterable, Identifiable {
    case macOS = "macOS"
    case iOS = "iOS"
    case unity = "Unity"
    case web = "Web"
    case other = "Other"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .macOS: "macwindow"
        case .iOS: "iphone"
        case .unity: "cube.transparent"
        case .web: "globe"
        case .other: "folder"
        }
    }

    static func detect(at url: URL) -> ProjectKind {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        let names = Set(contents.map { $0.lowercased() })
        if let projectBundle = contents.first(where: { $0.lowercased().hasSuffix(".xcodeproj") }),
           let projectData = try? String(contentsOf: url.appendingPathComponent(projectBundle).appendingPathComponent("project.pbxproj"), encoding: .utf8) {
            if projectData.contains("SDKROOT = macosx") || projectData.contains("SUPPORTED_PLATFORMS = macosx") { return .macOS }
            if projectData.contains("SDKROOT = iphoneos") || projectData.contains("SUPPORTED_PLATFORMS = \\"iphoneos") { return .iOS }
            return .other
        }
        if names.contains(where: { $0.hasSuffix(".xcworkspace") }) { return .other }
        if names.contains("assets") && names.contains("projectsettings") { return .unity }
        if names.contains("package.json") || names.contains("vite.config.js") || names.contains("vite.config.ts") { return .web }
        return .other
    }
}

enum ProjectStatus: String, Codable {
    case ready = "Ready"
    case building = "Building"
    case attention = "Needs attention"
}
