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
        let manager = FileManager.default
        let contents = (try? manager.contentsOfDirectory(atPath: url.path)) ?? []
        let names = Set(contents.map { $0.lowercased() })

        if names.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            return .iOS
        }
        if names.contains("assets") && names.contains("projectsettings") {
            return .unity
        }
        if names.contains("package.json") || names.contains("vite.config.js") || names.contains("vite.config.ts") {
            return .web
        }
        if names.contains("contents.xcworkspacedata") {
            return .iOS
        }
        return .other
    }
}

enum ProjectStatus: String, Codable {
    case ready = "Ready"
    case building = "Building"
    case attention = "Needs attention"
}
