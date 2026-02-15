import Foundation
import Testing
@testable import GitTracker

struct ProjectInsightsServiceTests {
    @Test
    func parsesCommitLogAggregates() {
        let input = """
        commit:1739491200
         2 files changed, 11 insertions(+), 3 deletions(-)
        commit:1739404800
         1 file changed, 5 deletions(-)
        """

        let parsed = ProjectInsightsService.parseGitLogShortstat(input)

        #expect(parsed.commits.count == 2)
        #expect(parsed.commits[0].deltaLines == 14)
        #expect(parsed.commits[0].filesChanged == 2)
        #expect(parsed.commits[1].deltaLines == 5)
        #expect(parsed.commits[1].filesChanged == 1)
        #expect(parsed.activeDays.count == 2)
    }
}
