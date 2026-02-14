import Foundation
import Testing
@testable import GitTracker

struct PathSuggestionEngineTests {
    @Test
    func trailingSlashSuggestsChildrenOfCurrentDirectoryLevel() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let alpha = root.appendingPathComponent("alpha")
        let beta = root.appendingPathComponent("beta")
        try FileManager.default.createDirectory(at: alpha, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: beta, withIntermediateDirectories: true)

        let suggestions = PathSuggestionEngine.suggestions(for: root.path + "/", limit: 20)
        let normalizedSuggestions = Set(suggestions.map(normalizedPath))

        #expect(normalizedSuggestions.contains(normalizedPath(alpha.path)))
        #expect(normalizedSuggestions.contains(normalizedPath(beta.path)))
    }

    @Test
    func nestedTrailingSlashContinuesAutocompleteInsideSubfolder() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let parent = root.appendingPathComponent("parent")
        let child = parent.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)

        let suggestions = PathSuggestionEngine.suggestions(for: parent.path + "/", limit: 20)
        let normalizedSuggestions = Set(suggestions.map(normalizedPath))

        #expect(normalizedSuggestions.contains(normalizedPath(child.path)))
    }

    @Test
    func acceptingDirectorySuggestionWithDescendAddsTrailingSlash() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let directory = root.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let input = PathSuggestionEngine.inputAfterAcceptingSuggestion(directory.path, descendIntoDirectory: true)
        #expect(input.hasSuffix("/"))
    }

    private func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gittracker-suggest-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
