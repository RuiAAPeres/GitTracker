import Foundation
import Testing
@testable import GitTracker

struct PathNormalizerTests {
    @Test
    func preservesNormalAbsolutePath() {
        let path = "/tmp/gittracker"
        #expect(PathNormalizer.normalize(path) == path)
    }

    @Test
    func expandsTildePath() {
        let normalized = PathNormalizer.normalize("~/Code")
        #expect(normalized.hasPrefix(NSHomeDirectory()))
    }

    @Test
    func correctsUserToUsersWhenHomePathMatches() {
        let home = NSHomeDirectory()
        guard home.hasPrefix("/Users/") else {
            return
        }

        let typo = home.replacingOccurrences(of: "/Users/", with: "/User/")
        let normalized = PathNormalizer.normalize(typo)
        #expect(normalized == home)
    }
}
