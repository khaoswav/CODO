import Foundation

struct IntelligenceFile: Identifiable, Codable {
    let path: String
    let language: String
    let lineCount: Int
    let byteCount: Int
    var id: String { path }
}

struct IntelligenceDependency: Identifiable, Codable, Hashable {
    let source: String
    let target: String
    let kind: String
    var id: String { source + "->" + target + ":" + kind }
}

struct IntelligenceGraphEdge: Identifiable, Codable, Hashable {
    let sourceFile: String
    let targetFile: String
    let importedSymbol: String
    let kind: String
    var id: String { sourceFile + "->" + targetFile + ":" + importedSymbol }
}

struct IntelligenceFinding: Identifiable, Codable {
    enum Severity: String, Codable {
        case info = "Info"
        case warning = "Warning"
        case critical = "Critical"
    }
    let id: UUID
    let severity: Severity
    let title: String
    let filePath: String
    let line: Int?
    let detail: String

    init(severity: Severity, title: String, filePath: String, line: Int? = nil, detail: String) {
        self.id = UUID()
        self.severity = severity
        self.title = title
        self.filePath = filePath
        self.line = line
        self.detail = detail
    }
}

struct DeveloperIntelligenceReport: Codable {
    let projectName: String
    let generatedAt: Date
    let files: [IntelligenceFile]
    let dependencies: [IntelligenceDependency]
    let graphEdges: [IntelligenceGraphEdge]
    let findings: [IntelligenceFinding]
    let languageCounts: [String: Int]
    let totalLines: Int
    let truncated: Bool

    var summary: String {
        "\(files.count) source/config files · \(totalLines) lines · \(dependencies.count) dependency links · \(findings.count) findings"
    }
}

enum DeveloperIntelligenceService {
    private static let ignoredDirectories: Set<String> = [
        ".git", ".build", "build", "Builds", "DerivedData", "node_modules",
        "Pods", "Carthage", ".swiftpm", "Library", "Temp", "Obj", "Bin",
        ".next", "dist", "vendor"
    ]
    private static let sourceExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "cs", "js", "jsx",
        "ts", "tsx", "py", "rb", "go", "rs", "java", "kt", "php", "vue", "svelte"
    ]
    private static let configExtensions: Set<String> = [
        "json", "yml", "yaml", "toml", "xml", "plist", "xcconfig", "gradle",
        "properties", "md", "sql"
    ]
    private static let maximumFiles = 4_000
    private static let maximumFileBytes = 256 * 1024

    static func analyze(root: URL, projectName: String) -> DeveloperIntelligenceReport {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        var files: [IntelligenceFile] = []
        var dependencies: [IntelligenceDependency] = []
        var findings: [IntelligenceFinding] = []
        var languageCounts: [String: Int] = [:]
        var totalLines = 0
        var truncated = false

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return DeveloperIntelligenceReport(projectName: projectName, generatedAt: .now,
                files: [], dependencies: [], graphEdges: [], findings: [
                    IntelligenceFinding(severity: .critical, title: "Project folder unavailable",
                        filePath: "", detail: "CODO could not enumerate the selected project folder.")
                ], languageCounts: [:], totalLines: 0, truncated: false)
        }

        while let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true {
                if values?.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            if values?.isDirectory == true {
                if ignoredDirectories.contains(url.lastPathComponent) { enumerator.skipDescendants() }
                continue
            }

            let relative = String(url.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let canonicalFile = url.resolvingSymlinksInPath().standardizedFileURL
            guard !relative.isEmpty, url.path.hasPrefix(root.path + "/"),
                  canonicalFile.path.hasPrefix(root.path + "/") else { continue }
            let ext = url.pathExtension.lowercased()
            guard sourceExtensions.contains(ext) || configExtensions.contains(ext) else { continue }
            guard files.count < maximumFiles else { truncated = true; break }

            let size = values?.fileSize ?? 0
            guard size <= maximumFileBytes,
                  let data = try? Data(contentsOf: canonicalFile),
                  let text = String(data: data, encoding: .utf8) else {
                findings.append(IntelligenceFinding(severity: .info, title: "File skipped",
                    filePath: relative, detail: "File is larger than 256 KB or is not UTF-8 text."))
                continue
            }

            let lines = text.components(separatedBy: .newlines)
            let language = languageName(for: ext)
            files.append(IntelligenceFile(path: relative, language: language, lineCount: lines.count, byteCount: size))
            languageCounts[language, default: 0] += 1
            totalLines += lines.count

            if lines.count > 500 {
                findings.append(IntelligenceFinding(severity: .warning, title: "Large source file",
                    filePath: relative, detail: "\(lines.count) lines. Consider splitting responsibilities into smaller units."))
            }

            for (offset, line) in lines.enumerated() {
                let number = offset + 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("TODO") || trimmed.contains("FIXME") || trimmed.contains("HACK") {
                    findings.append(IntelligenceFinding(severity: .info, title: "Pending code note",
                        filePath: relative, line: number, detail: String(trimmed.prefix(180))))
                }
                if ext == "swift" && trimmed.range(of: #"\w+!([\.,\)\]\?]|$)"#, options: .regularExpression) != nil {
                    findings.append(IntelligenceFinding(severity: .warning, title: "Possible force unwrap",
                        filePath: relative, line: number, detail: "Review whether this unwrap can fail at runtime."))
                }
                if ["swift", "js", "jsx", "ts", "tsx", "py"].contains(ext) &&
                    (trimmed.hasPrefix("print(") || trimmed.contains("console.log(")) {
                    findings.append(IntelligenceFinding(severity: .info, title: "Debug output",
                        filePath: relative, line: number, detail: "Check whether this diagnostic output should remain in production code."))
                }
                if trimmed.contains("DispatchQueue.main.sync") {
                    findings.append(IntelligenceFinding(severity: .critical, title: "Potential main-thread deadlock",
                        filePath: relative, line: number, detail: "Synchronous dispatch onto the main queue can deadlock when called from the main thread."))
                }
                if trimmed.contains("Data(contentsOf:") || trimmed.contains("String(contentsOf:") ||
                    trimmed.contains("contentsOfDirectory(") || trimmed.contains("readDataToEndOfFile()") {
                    findings.append(IntelligenceFinding(severity: .warning, title: "Potential synchronous I/O",
                        filePath: relative, line: number, detail: "Check whether this file or directory operation runs on the main thread or blocks an interactive path."))
                }
                if trimmed.contains("Thread.sleep") || trimmed.contains("sleep(") {
                    findings.append(IntelligenceFinding(severity: .warning, title: "Blocking sleep call",
                        filePath: relative, line: number, detail: "Sleeping a thread can stall a worker or the UI. Prefer asynchronous scheduling where appropriate."))
                }
                if looksLikeEmbeddedSecret(trimmed) {
                    findings.append(IntelligenceFinding(severity: .critical, title: "Possible embedded credential",
                        filePath: relative, line: number, detail: "A credential-like pattern was detected. The value is intentionally not displayed. Rotate it if it is real and move it to secure configuration."))
                }
            }

            dependencies.append(contentsOf: importDependencies(in: text, file: relative, extension: ext))
        }

        let uniqueFindings = Dictionary(grouping: findings, by: { $0.title + "|" + $0.filePath + "|" + String($0.line ?? 0) })
            .compactMap { $0.value.first }
            .sorted { severityRank($0.severity) > severityRank($1.severity) }

        let sortedFiles = files.sorted { $0.path < $1.path }
        let uniqueDependencies = Array(Set(dependencies)).sorted { $0.id < $1.id }
        let graphEdges = resolveGraph(files: sortedFiles, dependencies: uniqueDependencies)

        return DeveloperIntelligenceReport(
            projectName: projectName,
            generatedAt: .now,
            files: sortedFiles,
            dependencies: uniqueDependencies,
            graphEdges: graphEdges,
            findings: uniqueFindings,
            languageCounts: languageCounts,
            totalLines: totalLines,
            truncated: truncated
        )
    }

    static func resolveGraph(files: [IntelligenceFile], dependencies: [IntelligenceDependency]) -> [IntelligenceGraphEdge] {
        let paths = Set(files.map(\.path))
        let byStem = Dictionary(grouping: files, by: { URL(fileURLWithPath: $0.path).deletingPathExtension().lastPathComponent.lowercased() })
        var edges: [IntelligenceGraphEdge] = []

        for dependency in dependencies {
            let rawTarget = dependency.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawTarget.isEmpty else { continue }
            var candidates: [String] = []

            if rawTarget.hasPrefix(".") || rawTarget.hasPrefix("/") {
                let base = URL(fileURLWithPath: dependency.source).deletingLastPathComponent()
                    .appendingPathComponent(rawTarget).standardizedFileURL.path
                let normalized = base.hasPrefix("/") ? String(base.dropFirst()) : base
                let extensions = ["", ".swift", ".js", ".jsx", ".ts", ".tsx", ".m", ".mm", ".h", ".hpp", ".c", ".cc", ".cpp", ".cs", ".py", ".rs", ".go", ".java", ".kt"]
                candidates.append(contentsOf: extensions.map { normalized + $0 })
                candidates.append(contentsOf: extensions.dropFirst().map { normalized + "/index" + $0 })
            } else {
                let module = rawTarget.split(separator: ".").last.map(String.init) ?? rawTarget
                candidates.append(contentsOf: (byStem[module.lowercased()] ?? []).map(\.path))
            }

            let matches = Set(candidates.filter { paths.contains($0) && $0 != dependency.source })
            guard matches.count == 1, let target = matches.first else { continue }
            edges.append(IntelligenceGraphEdge(
                sourceFile: dependency.source,
                targetFile: target,
                importedSymbol: rawTarget,
                kind: dependency.kind
            ))
        }
        return Array(Set(edges)).sorted { $0.id < $1.id }
    }

    private static func languageName(for ext: String) -> String {
        let names = ["swift": "Swift", "js": "JavaScript", "jsx": "JavaScript", "ts": "TypeScript",
            "tsx": "TypeScript", "cs": "C#", "py": "Python", "rs": "Rust", "go": "Go",
            "java": "Java", "kt": "Kotlin", "cpp": "C++", "cc": "C++", "c": "C",
            "m": "Objective-C", "mm": "Objective-C++", "json": "JSON", "yml": "YAML",
            "yaml": "YAML", "md": "Markdown", "sql": "SQL"]
        return names[ext] ?? ext.uppercased()
    }

    private static func importDependencies(in text: String, file: String, extension ext: String) -> [IntelligenceDependency] {
        let patterns: [(String, String)] = [
            (#"(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)"#, "import"),
            (#"(?m)^\s*#include\s*[<"]([^>"]+)[>"]"#, "include"),
            (#"(?m)^\s*from\s+([A-Za-z_][A-Za-z0-9_.]*)\s+import"#, "import"),
            (#"(?m)^\s*(?:const|let|var)\s+.*?from\s+['"]([^'"]+)['"]"#, "module")
        ]
        var result: [IntelligenceDependency] = []
        for (pattern, kind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsText = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                guard match.numberOfRanges > 1 else { continue }
                let target = nsText.substring(with: match.range(at: 1))
                result.append(IntelligenceDependency(source: file, target: target, kind: kind))
            }
        }

        if file == "package.json" || file == "Packages/manifest.json" {
            if let data = text.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for key in ["dependencies", "devDependencies"] {
                    let packages = object[key] as? [String: Any] ?? [:]
                    for name in packages.keys.sorted() {
                        result.append(IntelligenceDependency(source: file, target: name, kind: "package"))
                    }
                }
            }
        }
        return result
    }

    private static func looksLikeEmbeddedSecret(_ line: String) -> Bool {
        let patterns = [
            #"(?i)(api[_-]?key|secret|access[_-]?token|private[_-]?key)\s*[:=]\s*['"][A-Za-z0-9_\-]{16,}['"]"#,
            #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#
        ]
        return patterns.contains { line.range(of: $0, options: .regularExpression) != nil }
    }

    private static func severityRank(_ severity: IntelligenceFinding.Severity) -> Int {
        switch severity { case .info: 0; case .warning: 1; case .critical: 2 }
    }
}

struct ProjectMemory: Codable {
    var projectID: UUID
    var projectName: String
    var lastArchitectureSummary: String? = nil
    var purpose: String = ""
    var architectureNotes: String = ""
    var decisions: [String] = []
    var nextSteps: [String] = []
    var updatedAt: Date = .now
}

enum ProjectMemoryStore {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CODO/ProjectMemory", isDirectory: true)
    }

    static func load(project: CODOProject) -> ProjectMemory {
        let url = directory.appendingPathComponent(project.id.uuidString + ".json")
        guard let data = try? Data(contentsOf: url),
              let memory = try? JSONDecoder().decode(ProjectMemory.self, from: data) else {
            return ProjectMemory(projectID: project.id, projectName: project.name)
        }
        return memory
    }

    static func save(_ memory: ProjectMemory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var updated = memory
        updated.updatedAt = .now
        let data = try JSONEncoder().encode(updated)
        try data.write(to: directory.appendingPathComponent(updated.projectID.uuidString + ".json"), options: .atomic)
    }
}

struct IntelligencePlanStep: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var requiresApproval: Bool
    var status: String = "Pending"
}

enum IntelligenceTaskPlanner {
    static func makePlan(for request: String) -> [IntelligencePlanStep] {
        [
            IntelligencePlanStep(title: "Understand the request", detail: "Inspect relevant files, project memory, architecture and current Git state.", requiresApproval: false),
            IntelligencePlanStep(title: "Plan the implementation", detail: "Identify affected modules, dependencies, risks and a bounded change set.", requiresApproval: false),
            IntelligencePlanStep(title: "Implement the change", detail: "Ask Goose for a unified diff proposal. No project files are changed at this stage.", requiresApproval: false),
            IntelligencePlanStep(title: "Review and approve", detail: "Present each changed file for explicit approval before applying the patch.", requiresApproval: true),
            IntelligencePlanStep(title: "Build and test", detail: "Run the project-specific build/test commands after explicit approval.", requiresApproval: true),
            IntelligencePlanStep(title: "Report and remember", detail: "Record the outcome, decisions and follow-up work in this project's local memory.", requiresApproval: false)
        ]
    }
}


