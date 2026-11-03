import Foundation

enum AIUnifiedDiffError: LocalizedError {
    case noChanges
    case malformedPatch(String)
    case unsafePath(String)
    case unsupportedChange(String)
    case contextMismatch(String)

    var errorDescription: String? {
        switch self {
        case .noChanges: "Goose did not return a supported unified diff."
        case .malformedPatch(let path): "The diff for \(path) is malformed."
        case .unsafePath(let path): "The diff contains an unsafe project path: \(path)"
        case .unsupportedChange(let path): "New, deleted, renamed and binary files are not supported yet: \(path)"
        case .contextMismatch(let path): "The original file no longer matches the diff context: \(path)"
        }
    }
}

enum AIUnifiedDiffParser {
    private static let maximumDiffSize = 512 * 1024

    static func parse(_ output: String, project: CODOProject, root: URL) throws -> [ProjectFileChange] {
        guard output.utf8.count <= maximumDiffSize else {
            throw ProjectFileChangeError.fileTooLarge
        }
        let didStart = project.bookmarkData != nil ? root.startAccessingSecurityScopedResource() : false
        if project.bookmarkData != nil && !didStart { throw ProjectFileChangeError.accessDenied }
        defer { if didStart { root.stopAccessingSecurityScopedResource() } }

        let lines = output.components(separatedBy: .newlines)
        var changes: [ProjectFileChange] = []
        var index = 0

        while index < lines.count {
            guard lines[index].hasPrefix("--- ") else { index += 1; continue }
            let oldHeader = String(lines[index].dropFirst(4)).split(separator: "\t", maxSplits: 1).first.map(String.init) ?? ""
            index += 1
            guard index < lines.count, lines[index].hasPrefix("+++ ") else { continue }
            let newHeader = String(lines[index].dropFirst(4)).split(separator: "\t", maxSplits: 1).first.map(String.init) ?? ""
            index += 1

            guard oldHeader != "/dev/null", newHeader != "/dev/null" else {
                throw AIUnifiedDiffError.unsupportedChange(newHeader)
            }
            let oldPath = normalizedPath(oldHeader)
            let newPath = normalizedPath(newHeader)
            guard oldPath == newPath, let relativePath = newPath else {
                throw AIUnifiedDiffError.unsafePath(newHeader)
            }
            guard isSafeRelativePath(relativePath) else { throw AIUnifiedDiffError.unsafePath(relativePath) }

            let fileURL = root.appendingPathComponent(relativePath).standardizedFileURL
            let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
            let canonicalFile = fileURL.resolvingSymlinksInPath().standardizedFileURL
            guard canonicalFile.path.hasPrefix(canonicalRoot.path + "/") else {
                throw AIUnifiedDiffError.unsafePath(relativePath)
            }
            guard let originalData = try? Data(contentsOf: canonicalFile),
                  let original = String(data: originalData, encoding: .utf8) else {
                throw AIUnifiedDiffError.unsupportedChange(relativePath)
            }

            let lineEnding = original.contains("\r\n") ? "\r\n" : "\n"
            var sourceLines = original.components(separatedBy: .newlines)
            let hadTrailingNewline = original.hasSuffix("\n")
            if hadTrailingNewline && sourceLines.last == "" { sourceLines.removeLast() }
            var outputLines: [String] = []
            var sourceCursor = 0
            var foundHunk = false

            while index < lines.count && !isFileHeader(lines, at: index) {
                guard lines[index].hasPrefix("@@ ") else { index += 1; continue }
                let headerParts = lines[index].split(separator: " ")
                guard headerParts.count >= 3 else { throw AIUnifiedDiffError.malformedPatch(relativePath) }
                let oldRange = headerParts[1].dropFirst()
                guard let oldStart = Int(oldRange.split(separator: ",").first ?? "") else {
                    throw AIUnifiedDiffError.malformedPatch(relativePath)
                }
                let targetCursor = oldStart == 0 ? 0 : oldStart - 1
                guard targetCursor >= sourceCursor && targetCursor <= sourceLines.count else {
                    throw AIUnifiedDiffError.contextMismatch(relativePath)
                }
                outputLines.append(contentsOf: sourceLines[sourceCursor..<targetCursor])
                sourceCursor = targetCursor
                foundHunk = true
                index += 1

                while index < lines.count &&
                        !lines[index].hasPrefix("@@ ") &&
                        !isFileHeader(lines, at: index) {
                    let line = lines[index]
                    if line.hasPrefix("\\ No newline at end of file") {
                        index += 1
                        continue
                    }
                    guard let marker = line.first else { index += 1; continue }
                    let value = String(line.dropFirst())
                    switch marker {
                    case " ":
                        guard sourceCursor < sourceLines.count, sourceLines[sourceCursor] == value else {
                            throw AIUnifiedDiffError.contextMismatch(relativePath)
                        }
                        outputLines.append(value)
                        sourceCursor += 1
                    case "-":
                        guard sourceCursor < sourceLines.count, sourceLines[sourceCursor] == value else {
                            throw AIUnifiedDiffError.contextMismatch(relativePath)
                        }
                        sourceCursor += 1
                    case "+":
                        outputLines.append(value)
                    default:
                        index += 1
                        continue
                    }
                    index += 1
                }
            }

            guard foundHunk else { throw AIUnifiedDiffError.malformedPatch(relativePath) }
            outputLines.append(contentsOf: sourceLines.dropFirst(sourceCursor))
            var proposed = outputLines.joined(separator: lineEnding)
            if hadTrailingNewline { proposed += lineEnding }
            let change = try ProjectFileChangeService.prepare(
                file: canonicalFile,
                project: project,
                root: root,
                proposedText: proposed
            )
            changes.append(change)
        }

        guard !changes.isEmpty else { throw AIUnifiedDiffError.noChanges }
        return changes
    }

    private static func isFileHeader(_ lines: [String], at index: Int) -> Bool {
        index + 1 < lines.count && lines[index].hasPrefix("--- ") && lines[index + 1].hasPrefix("+++ ")
    }

    private static func normalizedPath(_ header: String) -> String? {
        var path = header
        if path.hasPrefix("a/") || path.hasPrefix("b/") { path = String(path.dropFirst(2)) }
        return path
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}
