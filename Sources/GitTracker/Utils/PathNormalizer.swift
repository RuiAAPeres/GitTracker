import Foundation

enum PathNormalizer {
    static func normalize(_ rawPath: String, fileManager: FileManager = .default) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        let hasWildcardSuffix = expanded.hasSuffix("/*")
        let pathWithoutWildcard = hasWildcardSuffix ? String(expanded.dropLast(2)) : expanded

        let corrected = correctUsersDirectoryTypo(pathWithoutWildcard, fileManager: fileManager)
        return hasWildcardSuffix ? corrected + "/*" : corrected
    }

    private static func correctUsersDirectoryTypo(_ path: String, fileManager: FileManager) -> String {
        guard path.hasPrefix("/User/") else {
            return path
        }

        let candidate = "/Users/" + path.dropFirst("/User/".count)
        if fileManager.fileExists(atPath: candidate) {
            return candidate
        }
        return path
    }
}
