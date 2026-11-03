import Foundation

struct PlannedCommand {
    let executable: URL
    let arguments: [String]
    let display: String
}

enum ProjectBuildPlanner {
    private enum WebPackageManager: String {
        case npm
        case yarn
        case pnpm

        var executable: String { rawValue }
    }

    static func plan(_ command: ProjectCommand, root: URL, project: CODOProject,
                     unityEditorRoots: [URL]? = nil) -> PlannedCommand? {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        switch command {
        case .xcodeDebugBuild, .xcodeReleaseBuild:
            let workspace = files.first { $0.hasSuffix(".xcworkspace") }
            let projectFile = files.first { $0.hasSuffix(".xcodeproj") }
            guard let container = workspace ?? projectFile else { return nil }
            let isWorkspace = container.hasSuffix(".xcworkspace")
            let flag = isWorkspace ? "-workspace" : "-project"
            let containerURL = root.appendingPathComponent(container)
            let sharedSchemes = containerURL
                .appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
            let schemeFiles = try? FileManager.default.contentsOfDirectory(at: sharedSchemes, includingPropertiesForKeys: nil)
            let schemeFile = schemeFiles?.filter { $0.pathExtension == "xcscheme" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .first
            let scheme = schemeFile?.deletingPathExtension().lastPathComponent
                ?? containerURL.deletingPathExtension().lastPathComponent
            let configuration = command == .xcodeDebugBuild ? "Debug" : "Release"
            var args = [flag, root.appendingPathComponent(container).path, "-scheme", scheme,
                        "-configuration", configuration, "CODE_SIGNING_ALLOWED=NO", "build"]
            if project.kind == .macOS {
                args.insert(contentsOf: ["-sdk", "macosx", "-destination", "platform=macOS,arch=arm64"],
                            at: args.count - 2)
            } else if project.kind == .iOS {
                args.insert(contentsOf: ["-destination", "generic/platform=iOS Simulator"], at: args.count - 1)
            }
            return PlannedCommand(
                executable: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
                arguments: args,
                display: "xcodebuild " + args.joined(separator: " ")
            )

        case .unityMacBuild:
            let editorRoots = unityEditorRoots ?? [
                URL(fileURLWithPath: "/Applications/Unity/Hub/Editor", isDirectory: true),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications/Unity/Hub/Editor", isDirectory: true)
            ]
            let editors = editorRoots.flatMap { directory -> [URL] in
                (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )) ?? []
            }
            guard let editor = editors.sorted(by: {
                $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending
            }).first(where: {
                FileManager.default.fileExists(
                    atPath: $0.appendingPathComponent("Unity.app/Contents/MacOS/Unity").path
                )
            }) else { return nil }
            let executable = editor.appendingPathComponent("Unity.app/Contents/MacOS/Unity")
            let output = root.appendingPathComponent("Builds/CODO-macOS.app").path
            let args = ["-batchmode", "-quit", "-projectPath", root.path,
                        "-buildTarget", "StandaloneOSX", "-buildOSXPlayer", output]
            return PlannedCommand(
                executable: executable,
                arguments: args,
                display: executable.path + " " + args.joined(separator: " ")
            )

        case .webBuild, .webTest:
            let packageURL = root.appendingPathComponent("package.json")
            guard let data = try? Data(contentsOf: packageURL),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let scripts = object["scripts"] as? [String: String] else { return nil }
            let script = command == .webBuild ? "build" : "test"
            guard scripts[script] != nil else { return nil }
            let manager = detectPackageManager(files: files, packageJSON: object)
            let args = [manager.executable, "run", script]
            return PlannedCommand(
                executable: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: args,
                display: args.joined(separator: " ")
            )

        default:
            return nil
        }
    }

    private static func detectPackageManager(files: [String], packageJSON: [String: Any]) -> WebPackageManager {
        if let declared = packageJSON["packageManager"] as? String {
            let name = declared.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
            if let manager = WebPackageManager(rawValue: name) { return manager }
        }
        if files.contains("pnpm-lock.yaml") { return .pnpm }
        if files.contains("yarn.lock") { return .yarn }
        return .npm
    }
}
