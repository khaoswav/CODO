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

struct IntelligenceGraphNode: Identifiable, Hashable {
    let path: String
    let layer: Int
    let x: Double
    let y: Double
    var id: String { path }
}

enum IntelligenceGraphLayout {
    static func layout(
        files: [IntelligenceFile],
        edges: [IntelligenceGraphEdge],
        limit: Int = 32
    ) -> [IntelligenceGraphNode] {
        guard limit > 0, !files.isEmpty, !edges.isEmpty else { return [] }
        let available = Set(files.map(\.path))
        let validEdges = edges.filter {
            available.contains($0.sourceFile) && available.contains($0.targetFile) &&
            $0.sourceFile != $0.targetFile
        }
        guard !validEdges.isEmpty else { return [] }

        var degree: [String: Int] = [:]
        for edge in validEdges {
            degree[edge.sourceFile, default: 0] += 1
            degree[edge.targetFile, default: 0] += 1
        }
        let selected = Array(available.sorted {
            let left = degree[$0, default: 0]
            let right = degree[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }.prefix(limit))
        let selectedSet = Set(selected)
        let selectedEdges = validEdges.filter {
            selectedSet.contains($0.sourceFile) && selectedSet.contains($0.targetFile)
        }

        var outgoing: [String: [String]] = [:]
        var indegree = Dictionary(uniqueKeysWithValues: selected.map { ($0, 0) })
        for edge in selectedEdges {
            outgoing[edge.sourceFile, default: []].append(edge.targetFile)
            indegree[edge.targetFile, default: 0] += 1
        }

        var layers = Dictionary(uniqueKeysWithValues: selected.map { ($0, 0) })
        var ready = selected.filter { indegree[$0, default: 0] == 0 }.sorted()
        var visited = Set<String>()
        while !ready.isEmpty {
            let current = ready.removeFirst()
            visited.insert(current)
            for target in (outgoing[current] ?? []).sorted() {
                layers[target] = max(layers[target, default: 0], layers[current, default: 0] + 1)
                indegree[target, default: 0] -= 1
                if indegree[target] == 0 {
                    ready.append(target)
                    ready.sort()
                }
            }
        }

        let cycleLayer = (layers.values.max() ?? 0) + 1
        for path in selected where !visited.contains(path) {
            layers[path] = cycleLayer
        }

        let grouped = Dictionary(grouping: selected, by: { layers[$0, default: 0] })
        let maximumLayer = max(0, grouped.keys.max() ?? 0)
        return selected.sorted {
            let left = layers[$0, default: 0]
            let right = layers[$1, default: 0]
            return left == right ? $0 < $1 : left < right
        }.map { path in
            let layer = layers[path, default: 0]
            let siblings = (grouped[layer] ?? []).sorted()
            let row = siblings.firstIndex(of: path) ?? 0
            let x = maximumLayer == 0 ? 0.5 : 0.10 + (Double(layer) / Double(maximumLayer)) * 0.80
            let y = Double(row + 1) / Double(siblings.count + 1)
            return IntelligenceGraphNode(path: path, layer: layer, x: x, y: y)
        }
    }
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
        var rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        if rootPath.count > 1 && rootPath.hasSuffix("/") { rootPath.removeLast() }
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        let rootPrefix = rootPath == "/" ? "/" : rootPath + "/"
        var files: [IntelligenceFile] = []
        var dependencies: [IntelligenceDependency] = []
        var findings: [IntelligenceFinding] = []
        var languageCounts: [String: Int] = [:]
        var totalLines = 0
        var truncated = false

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
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

            let canonicalFile = url.resolvingSymlinksInPath().standardizedFileURL
            guard canonicalFile.path.hasPrefix(rootPrefix) else { continue }
            let relative = String(canonicalFile.path.dropFirst(rootPath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relative.isEmpty else { continue }
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

    private static func normalizeRelativePath(_ path: String) -> String {
        var components: [String] = []
        for component in path.split(separator: "/").map(String.init) {
            if component.isEmpty || component == "." { continue }
            if component == ".." {
                if !components.isEmpty { components.removeLast() }
            } else {
                components.append(component)
            }
        }
        return components.joined(separator: "/")
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
                let sourceDirectory = (dependency.source as NSString).deletingLastPathComponent
                let combined = (sourceDirectory as NSString).appendingPathComponent(rawTarget)
                let normalized = normalizeRelativePath(combined)
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
            (#"(?m)^\s*import\s+(?:[^;\n]*?\s+from\s+)?['"]([^'"]+)['"]"#, "module"),
            (#"(?m)\b(?:require|import)\s*\(\s*['"]([^'"]+)['"]\s*\)"#, "module"),
            (#"(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)"#, "import"),
            (#"(?m)^\s*#include\s*[<"]([^>"]+)[>"]"#, "include"),
            (#"(?m)^\s*from\s+([A-Za-z_][A-Za-z0-9_.]*)\s+import"#, "import")
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

struct BuildDiagnostic: Identifiable, Codable, Hashable {
    let signature: String
    let message: String
    let category: String
    let suggestedAction: String
    var id: String { signature }

    init(signature: String, message: String) {
        self.signature = signature
        self.message = message
        let guidance = BuildFailureAnalyzer.guidance(for: message)
        category = guidance.category
        suggestedAction = guidance.action
    }
}

struct BuildFailurePattern: Identifiable, Codable {
    let signature: String
    var summary: String
    var occurrenceCount: Int
    var lastSeen: Date
    var recentExamples: [String]
    var category: String? = nil
    var suggestedAction: String? = nil
    var id: String { signature }
}

enum BuildFailureAnalyzer {
    static func guidance(for message: String) -> (category: String, action: String) {
        let value = message.lowercased()
        if value.contains("no such module") || value.contains("module not found") {
            return ("Missing module", "Check package resolution, target membership and the selected build configuration.")
        }
        if value.contains("cannot find") || value.contains("not in scope") || value.contains("cs0246") {
            return ("Missing symbol or type", "Check imports, target membership, module dependencies and the symbol's access level.")
        }
        if value.contains("undefined symbols") || value.contains("linker command failed") {
            return ("Linker failure", "Check linked frameworks, library search paths and target link phases.")
        }
        if value.contains("signing") || value.contains("provisioning profile") || value.contains("code sign") {
            return ("Code signing", "Check the selected team, signing identity, provisioning profile and build destination.")
        }
        if value.contains("package.resolution") || value.contains("failed to resolve dependencies") || value.contains("could not resolve package") {
            return ("Package resolution", "Check package URLs and versions, then resolve dependencies again.")
        }
        if value.contains("unable to type-check") || value.contains("type-check this expression") {
            return ("Swift type-check complexity", "Split the expression into smaller typed intermediate values.")
        }
        if value.contains("error cs") {
            return ("C# compilation", "Inspect the Unity compiler diagnostic and verify assembly definitions and package versions.")
        }
        if value.contains("module build failed") || value.contains("typescript") {
            return ("Web compilation", "Check the reported module path, TypeScript types and package versions.")
        }
        return ("Compiler or build error", "Inspect the first compiler error and fix the earliest root cause before downstream errors.")
    }

    static func extractDiagnostics(from log: String, limit: Int = 8) -> [BuildDiagnostic] {
        let lines = log.components(separatedBy: .newlines)
        var results: [BuildDiagnostic] = []
        var seen = Set<String>()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            let isDiagnostic = lower.contains("error:") || lower.contains("fatal error:") ||
                lower.range(of: #"\berror\s+cs[0-9]+\b"#, options: .regularExpression) != nil ||
                lower.range(of: #"\bmsb[0-9]+\b"#, options: .regularExpression) != nil
            guard isDiagnostic else { continue }
            var normalized = redactSecrets(in: trimmed)
            normalized = normalized.replacingOccurrences(of: #":\d+:\d+:"#,
                with: ":<line>:<column>:", options: .regularExpression)
            normalized = normalized.replacingOccurrences(of: #"0x[0-9a-fA-F]+"#,
                with: "<address>", options: .regularExpression)
            let signature = normalized.lowercased()
            guard seen.insert(signature).inserted else { continue }
            results.append(BuildDiagnostic(signature: signature, message: String(normalized.prefix(500))))
            if results.count >= limit { break }
        }
        return results
    }

    static func sanitizeLog(_ log: String) -> String {
        log.components(separatedBy: .newlines)
            .map { redactSecrets(in: $0) }
            .joined(separator: "\n")
    }

    private static func redactSecrets(in line: String) -> String {
        var value = line
        let patterns = [
            #"(?i)(api[_-]?key|secret|access[_-]?token|password)\s*[:=]\s*["']?[^ "';,]+"#,
            #"(?i)bearer\s+[A-Za-z0-9._~+/-]+"#
        ]
        for pattern in patterns {
            value = value.replacingOccurrences(of: pattern, with: "<redacted>", options: .regularExpression)
        }
        return value
    }

    static func merge(_ diagnostics: [BuildDiagnostic], into existing: [BuildFailurePattern], now: Date = .now) -> [BuildFailurePattern] {
        var patterns = existing
        for diagnostic in diagnostics {
            if let index = patterns.firstIndex(where: { $0.signature == diagnostic.signature }) {
                patterns[index].occurrenceCount += 1
                patterns[index].lastSeen = now
                patterns[index].category = diagnostic.category
                patterns[index].suggestedAction = diagnostic.suggestedAction
                patterns[index].recentExamples.insert(diagnostic.message, at: 0)
                patterns[index].recentExamples = Array(patterns[index].recentExamples.prefix(3))
            } else {
                patterns.append(BuildFailurePattern(
                    signature: diagnostic.signature,
                    summary: diagnostic.message,
                    occurrenceCount: 1,
                    lastSeen: now,
                    recentExamples: [diagnostic.message],
                    category: diagnostic.category,
                    suggestedAction: diagnostic.suggestedAction
                ))
            }
        }
        return patterns.sorted {
            if $0.occurrenceCount != $1.occurrenceCount { return $0.occurrenceCount > $1.occurrenceCount }
            return $0.lastSeen > $1.lastSeen
        }
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
    var buildFailurePatterns: [BuildFailurePattern]? = []
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
            IntelligencePlanStep(title: "Implement the change", detail: "The Implementer Agent prepares a unified diff proposal. No project files are changed at this stage.", requiresApproval: false),
            IntelligencePlanStep(title: "Review the proposal", detail: "A separate Reviewer Agent checks the proposed diff for correctness, scope, security and regressions.", requiresApproval: false),
            IntelligencePlanStep(title: "Review and approve", detail: "Present each changed file for explicit human approval before applying the patch.", requiresApproval: true),
            IntelligencePlanStep(title: "Build and test", detail: "Run the project-specific build/test commands after explicit approval.", requiresApproval: true),
            IntelligencePlanStep(title: "Report and remember", detail: "Record the outcome, decisions and follow-up work in this project's local memory.", requiresApproval: false)
        ]
    }
}


