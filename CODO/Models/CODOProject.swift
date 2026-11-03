import Foundation

struct CODOProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var kind: ProjectKind
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
}

enum ProjectStatus: String, Codable {
    case ready = "Ready"
    case building = "Building"
    case attention = "Needs attention"
}
