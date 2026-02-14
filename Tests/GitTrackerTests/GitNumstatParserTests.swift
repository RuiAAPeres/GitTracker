import Testing
@testable import GitTracker

struct GitNumstatParserTests {
    @Test
    func parseNormalAndBinaryLines() {
        let output = "12\t3\tSources/A.swift\n-\t-\tAssets/image.png\n8\t4\tSources/B.swift\n"
        let parsed = GitMetricsService.parseNumstat(output)
        #expect(parsed.added == 20)
        #expect(parsed.removed == 7)
    }

    @Test
    func parseEmptyOutput() {
        let parsed = GitMetricsService.parseNumstat("")
        #expect(parsed.added == 0)
        #expect(parsed.removed == 0)
    }
}
