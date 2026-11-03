import Foundation

struct PlannedCommand {
    let executable: URL
    let arguments: [String]
    let display: String
}

enum ProjectBuildPlanner {
    static func plan(_ command: ProjectCommand, root: URL, project: CODOProject) -> PlannedCommand? {
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
            let schemeFile = (try? FileManager.default.contentsOfDirectory(at: sharedSchemes, includingPropertiesForKeys: nil))
                ?.first(where: { $0.pathExtension == "xcscheme" })
            let scheme = schemeFile?.deletingPathExtension().lastPathComponent
                ?? containerURL.deletingPathExtension().lastPathComponent
            let configuration = command == .xcodeDebugBuild ? "Debug" : "Release"
            var args = [flag, root.appendingPathComponent(container).path, "-scheme", scheme,
                        "-configuration", configuration, "CODE_SIGNING_ALLOWED=NO", "build"]
            if project.kind == .iOS {
                args.insert(contentsOf: ["-destination", "generic/platform=iOS Simulator"], at: args.count - 1)
            }
            return PlannedCommand(
                executable: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
                arguments: args,
                display: "xcodebuild " + args.joined(separator: " ")
            )

        case .unityMacBuild:
            let hubEditors = URL(fileURLWithPath: "/Applications/Unity/Hub/Editor", isDirectory: true)
            guard let versions = try? FileManager.default.contentsOfDirectory(at: hubEditors, includingPropertiesForKeys: [.isDirectoryKey]),
                  let editor = versions.sorted(by: { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }).first(where: {
                      FileManager.default.fileExists(atPath: $0.appendingPathComponent("Unity.app/Contents/MacOS/Unity").path)
                  }) else { return nil }
            let executable = editor.appendingPathComponent("Unity.app/Contents/MacOS/Unity")
            let output = root.appendingPathComponent("Builds/CODO-macOS.app").path
            let args = ["-batchmode", "-quit", "-projectPath", root.path,
                        "-buildTarget", "StandaloneOSX", "-buildOSXPlayer", output]
            return PlannedCommand(executable: executable, arguments: args, display: executable.path + " " + args.joined(separator: " "))

        case .webBuild, .webTest:
            let packageURL = root.appendingPathComponent("package.json")
            guard let data = try? Data(contentsOf: packageURL),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let scripts = object["scripts"] as? [String: String] else { return nil }
            let script = command == .webBuild ? "build" : "test"
            guard scripts[script] != nil else { return nil }
            let args = ["npm", "run", script]
            return PlannedCommand(executable: URL(fileURLWithPath: "/usr/bin/env"), arguments: args, display: "npm run " + script)

        default:
            return nil
        }
    }
}
