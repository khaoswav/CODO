import Foundation

struct ProjectTarget: Identifiable, Hashable {
    let name: String
    let productType: String
    let platform: String
    var id: String { name + productType }
}

struct ProjectAnalysis {
    let projectName: String
    let projectKind: ProjectKind
    let rootPath: String
    let targets: [ProjectTarget]
    let metadata: [(String, String)]
    let warnings: [String]
}

enum ProjectAnalyzer {
    static func analyze(at root: URL, kind: ProjectKind) -> ProjectAnalysis {
        switch kind {
        case .macOS, .iOS:
            return analyzeXcode(at: root, kind: kind)
        case .unity:
            return analyzeUnity(at: root)
        case .web:
            return analyzeWeb(at: root)
        case .other:
            return ProjectAnalysis(
                projectName: root.lastPathComponent,
                projectKind: kind,
                rootPath: root.path,
                targets: [],
                metadata: [("Folder", root.lastPathComponent)],
                warnings: ["No supported project manifest was found at the selected folder root."]
            )
        }
    }

    private static func analyzeXcode(at root: URL, kind: ProjectKind) -> ProjectAnalysis {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let projectBundles = entries.filter {
            $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace"
        }
        let projectBundle = projectBundles.first { $0.pathExtension == "xcodeproj" }
        let pbxproj = projectBundle?.appendingPathComponent("project.pbxproj")
        let source = pbxproj.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

        let targets = nativeTargets(in: source, kind: kind)
        let platform: String
        if source.contains("SDKROOT = macosx") || source.contains("SUPPORTED_PLATFORMS = macosx") {
            platform = "macOS"
        } else if source.contains("SDKROOT = iphoneos") || source.contains("SUPPORTED_PLATFORMS = \"iphoneos") {
            platform = "iOS"
        } else {
            platform = kind.rawValue
        }

        var metadata: [(String, String)] = [
            ("Project container", projectBundle?.lastPathComponent ?? "Not found"),
            ("Platform hint", platform),
            ("Xcode targets", String(targets.count))
        ]
        if let bundleID = firstMatch(in: source, pattern: "PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);") {
            metadata.append(("Bundle identifier", bundleID.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        var warnings: [String] = []
        if projectBundle == nil {
            warnings.append("No .xcodeproj or .xcworkspace container was found at the project root.")
        }
        if targets.isEmpty && projectBundle != nil {
            warnings.append("Target details could not be read from the project file. Build-time inspection will be available when the Xcode command adapter is added.")
        }
        if projectBundle?.pathExtension == "xcworkspace" && projectBundle == nil {
            warnings.append("This workspace may reference projects outside the imported folder.")
        }

        return ProjectAnalysis(
            projectName: root.lastPathComponent,
            projectKind: kind,
            rootPath: root.path,
            targets: targets,
            metadata: metadata,
            warnings: warnings
        )
    }

    private static func nativeTargets(in source: String, kind: ProjectKind) -> [ProjectTarget] {
        guard !source.isEmpty,
              let regex = try? NSRegularExpression(pattern: "(?s)[A-F0-9]{24} = \\{(.*?)\\n\\s*\\};") else { return [] }
        let nsSource = source as NSString
        return regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length)).compactMap { match in
            let body = nsSource.substring(with: match.range(at: 1))
            guard body.contains("isa = PBXNativeTarget;"),
                  let name = firstMatch(in: body, pattern: "name = ([^;]+);") else { return nil }
            let productType = firstMatch(in: body, pattern: "productType = \"([^\"]+)\";") ?? "Unknown product"
            let displayType = productType
                .replacingOccurrences(of: "com.apple.product-type.", with: "")
                .replacingOccurrences(of: ".", with: " ")
            return ProjectTarget(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                 productType: displayType,
                                 platform: kind.rawValue)
        }
    }

    private static func analyzeUnity(at root: URL) -> ProjectAnalysis {
        let versionURL = root.appendingPathComponent("ProjectSettings/ProjectVersion.txt")
        let version = (try? String(contentsOf: versionURL, encoding: .utf8))?
            .components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix("m_EditorVersion:") })?
            .replacingOccurrences(of: "m_EditorVersion:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let assetURL = root.appendingPathComponent("Assets", isDirectory: true)
        let assetCount = (try? FileManager.default.contentsOfDirectory(atPath: assetURL.path).count) ?? 0
        let manifest = root.appendingPathComponent("Packages/manifest.json")
        let hasManifest = FileManager.default.fileExists(atPath: manifest.path)
        return ProjectAnalysis(
            projectName: root.lastPathComponent,
            projectKind: .unity,
            rootPath: root.path,
            targets: [],
            metadata: [
                ("Unity Editor", version),
                ("Top-level Assets", String(assetCount)),
                ("Package manifest", hasManifest ? "Found" : "Not found")
            ],
            warnings: hasManifest ? [] : ["Unity package manifest was not found."]
        )
    }

    private static func analyzeWeb(at root: URL) -> ProjectAnalysis {
        let packageURL = root.appendingPathComponent("package.json")
        let data = try? Data(contentsOf: packageURL)
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let scripts = json["scripts"] as? [String: Any] ?? [:]
        let dependencies = json["dependencies"] as? [String: Any] ?? [:]
        let devDependencies = json["devDependencies"] as? [String: Any] ?? [:]
        let metadata: [(String, String)] = [
            ("Package name", json["name"] as? String ?? root.lastPathComponent),
            ("Version", json["version"] as? String ?? "Not specified"),
            ("Scripts", scripts.keys.sorted().joined(separator: ", ").isEmpty ? "None detected" : scripts.keys.sorted().joined(separator: ", ")),
            ("Dependencies", String(dependencies.count + devDependencies.count))
        ]
        let warnings = data == nil ? ["package.json could not be read from the project root."] : []
        return ProjectAnalysis(
            projectName: root.lastPathComponent,
            projectKind: .web,
            rootPath: root.path,
            targets: [],
            metadata: metadata,
            warnings: warnings
        )
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
