import Foundation

struct PathSuggestionEngine {
    static func suggestions(for rawInput: String, limit: Int = 8) -> [String] {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let hasWildcardSuffix = trimmed.hasSuffix("/*")
        let searchInput = hasWildcardSuffix ? String(trimmed.dropLast(2)) : trimmed
        guard !searchInput.isEmpty else {
            return []
        }

        let expandedInput = normalizedInputPreservingDirectoryIntent(searchInput)
        let (baseDirectory, query) = splitBaseAndQuery(from: expandedInput, originalInput: searchInput)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: baseDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let baseURL = URL(fileURLWithPath: baseDirectory)
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        let normalizedQuery = query.lowercased()

        let scored: [(path: String, score: Int, name: String)] = children.compactMap { child in
            let name = child.lastPathComponent
            let lowerName = name.lowercased()

            if !normalizedQuery.isEmpty {
                guard let score = fuzzyScore(candidate: lowerName, query: normalizedQuery) else {
                    return nil
                }

                let suggestionPath = hasWildcardSuffix ? child.path + "/*" : child.path
                return (path: suggestionPath, score: score, name: name)
            }

            let suggestionPath = hasWildcardSuffix ? child.path + "/*" : child.path
            return (path: suggestionPath, score: 0, name: name)
        }

        return scored
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(limit)
            .map(\.path)
    }

    static func resolvedInputForAdd(rawInput: String, suggestions: [String]) -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return trimmed
        }

        if pathExists(for: trimmed) {
            return normalizeFilePathToDirectory(trimmed)
        }

        if let first = suggestions.first {
            return normalizeFilePathToDirectory(first)
        }

        return trimmed
    }

    static func inputAfterAcceptingSuggestion(_ suggestion: String, descendIntoDirectory: Bool) -> String {
        guard descendIntoDirectory else {
            return suggestion
        }
        if suggestion.hasSuffix("/*") {
            return suggestion
        }

        let normalized = PathNormalizer.normalize(suggestion)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized, isDirectory: &isDirectory), isDirectory.boolValue else {
            return suggestion
        }
        return normalized.hasSuffix("/") ? normalized : normalized + "/"
    }

    private static func splitBaseAndQuery(from expandedInput: String, originalInput: String) -> (baseDirectory: String, query: String) {
        if expandedInput.hasSuffix("/") {
            return (expandedInput, "")
        }

        if expandedInput.contains("/") {
            let base = (expandedInput as NSString).deletingLastPathComponent
            let query = (expandedInput as NSString).lastPathComponent
            return (base.isEmpty ? "/" : base, query)
        }

        if originalInput.hasPrefix("~") {
            let home = NSHomeDirectory()
            return (home, (expandedInput as NSString).lastPathComponent)
        }

        let cwd = FileManager.default.currentDirectoryPath
        return (cwd, expandedInput)
    }

    private static func pathExists(for input: String) -> Bool {
        let path = PathNormalizer.normalize(input)
        let nonWildcardPath: String
        if path.hasSuffix("/*") {
            nonWildcardPath = String(path.dropLast(2))
        } else {
            nonWildcardPath = path
        }
        return FileManager.default.fileExists(atPath: nonWildcardPath)
    }

    private static func normalizeFilePathToDirectory(_ input: String) -> String {
        let hasWildcardSuffix = input.hasSuffix("/*")
        let pathWithoutWildcard = hasWildcardSuffix ? String(input.dropLast(2)) : input
        let expanded = PathNormalizer.normalize(pathWithoutWildcard)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory) else {
            return input
        }

        if isDirectory.boolValue {
            return hasWildcardSuffix ? expanded + "/*" : expanded
        }

        let parent = URL(fileURLWithPath: expanded).deletingLastPathComponent().path
        return parent
    }

    private static func normalizedInputPreservingDirectoryIntent(_ input: String) -> String {
        let normalized = PathNormalizer.normalize(input)
        let hadTrailingSlash = input.hasSuffix("/")
        if hadTrailingSlash, !normalized.hasSuffix("/"), normalized != "/" {
            return normalized + "/"
        }
        return normalized
    }

    private static func fuzzyScore(candidate: String, query: String) -> Int? {
        if candidate.hasPrefix(query) {
            return 10_000 - candidate.count
        }

        var score = 0
        var candidateIndex = candidate.startIndex

        for queryChar in query {
            guard let found = candidate[candidateIndex...].firstIndex(of: queryChar) else {
                return nil
            }

            let distance = candidate.distance(from: candidateIndex, to: found)
            score += max(0, 100 - distance)
            candidate.formIndex(after: &candidateIndex)
        }

        return score
    }
}
