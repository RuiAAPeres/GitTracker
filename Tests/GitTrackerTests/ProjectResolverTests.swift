import Foundation
import Testing
@testable import GitTracker

struct ProjectResolverTests {
    @Test
    func childrenOfIncludesOnlyImmediateGitRepos() throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let repoA = tempRoot.appendingPathComponent("repoA")
        let normal = tempRoot.appendingPathComponent("normal")
        let nested = normal.appendingPathComponent("nestedRepo")

        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: normal, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoA.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested.appendingPathComponent(".git"), withIntermediateDirectories: true)

        let specs = [ProjectSpec(input: .childrenOf(path: tempRoot.path))]
        let resolved = ProjectResolver().resolve(specs: specs)

        #expect(resolved.count == 1)
        #expect(resolved.first?.path == repoA.path)
    }

    @Test
    func exactAlwaysIncludedEvenWhenNotRepo() throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let folder = tempRoot.appendingPathComponent("plain")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let spec = ProjectSpec(input: .exact(path: folder.path))
        let resolved = ProjectResolver().resolve(specs: [spec])

        #expect(resolved.count == 1)
        #expect(resolved[0].path == folder.path)
        #expect(resolved[0].isGitRepo == false)
    }

    private func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("gittracker-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
