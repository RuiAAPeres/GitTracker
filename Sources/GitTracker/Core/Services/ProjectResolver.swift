import Foundation

protocol ProjectResolving {
    func resolve(specs: [ProjectSpec]) -> [ResolvedProject]
}

struct ProjectResolver: ProjectResolving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolve(specs: [ProjectSpec]) -> [ResolvedProject] {
        var results: [ResolvedProject] = []

        for spec in specs where spec.enabled {
            switch spec.input {
            case .exact(let rawPath):
                let expandedPath = expandPath(rawPath)
                let name = spec.nameOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = (name?.isEmpty == false) ? name! : URL(fileURLWithPath: expandedPath).lastPathComponent
                results.append(
                    ResolvedProject(
                        sourceSpecID: spec.id,
                        name: displayName,
                        path: expandedPath,
                        isGitRepo: hasGitMarker(at: expandedPath)
                    )
                )

            case .childrenOf(let rawRoot):
                let rootPath = expandPath(rawRoot)
                guard let childPaths = immediateChildDirectories(at: rootPath) else {
                    continue
                }
                for childPath in childPaths where hasGitMarker(at: childPath) {
                    results.append(
                        ResolvedProject(
                            sourceSpecID: spec.id,
                            name: URL(fileURLWithPath: childPath).lastPathComponent,
                            path: childPath,
                            isGitRepo: true
                        )
                    )
                }
            }
        }

        return Array(Set(results)).sorted {
            if $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedSame {
                return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func immediateChildDirectories(at rootPath: String) -> [String]? {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: rootPath) else {
            return nil
        }
        return entries.compactMap { entry in
            let childPath = URL(fileURLWithPath: rootPath).appendingPathComponent(entry).path
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: childPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            return childPath
        }
    }

    private func hasGitMarker(at path: String) -> Bool {
        let gitPath = URL(fileURLWithPath: path).appendingPathComponent(".git").path
        return fileManager.fileExists(atPath: gitPath)
    }
}
