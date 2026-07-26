import SwiftUI
import Testing
@testable import CoreDesign

@Suite("TagInput")
struct TagInputTests {

    // MARK: - Construction

    @MainActor
    @Test("tag input constructs with default parameters")
    func tagInputConstructsWithDefaults() {
        let input = TagInput(tags: .constant(["bug"]))
        #expect(type(of: input) == TagInput.self)
    }

    @MainActor
    @Test("tag input constructs with all parameters")
    func tagInputConstructsWithAllParameters() {
        let input = TagInput(
            tags: .constant([]),
            placeholder: "Add label",
            tagColor: .blue,
            allowDuplicates: true,
            onCommit: { _ in }
        )
        #expect(type(of: input) == TagInput.self)
    }

    // MARK: - normalizedTag

    @Test("normalizedTag trims surrounding whitespace")
    func normalizedTagTrimsWhitespace() {
        #expect(TagInput.normalizedTag("  bug  ") == "bug")
    }

    @Test("normalizedTag trims surrounding newlines")
    func normalizedTagTrimsNewlines() {
        #expect(TagInput.normalizedTag("\nbug\n") == "bug")
    }

    @Test("normalizedTag returns nil for empty string")
    func normalizedTagReturnsNilForEmpty() {
        #expect(TagInput.normalizedTag("") == nil)
    }

    @Test("normalizedTag returns nil for whitespace-only string")
    func normalizedTagReturnsNilForWhitespaceOnly() {
        #expect(TagInput.normalizedTag("   ") == nil)
    }

    @Test("normalizedTag preserves internal whitespace")
    func normalizedTagPreservesInternalWhitespace() {
        #expect(TagInput.normalizedTag("  good first issue  ") == "good first issue")
    }

    @Test("normalizedTag is case sensitive (no normalization)")
    func normalizedTagIsCaseSensitive() {
        #expect(TagInput.normalizedTag("Bug") == "Bug")
        #expect(TagInput.normalizedTag("Bug") != TagInput.normalizedTag("bug"))
    }

    // MARK: - tagToCommit (dedupe policy)

    @Test("tagToCommit returns normalized tag when not a duplicate")
    func tagToCommitReturnsNormalizedTag() {
        let result = TagInput.tagToCommit("  enhancement  ", into: ["bug"], allowDuplicates: false)
        #expect(result == "enhancement")
    }

    @Test("tagToCommit returns nil for blank input regardless of dedupe policy")
    func tagToCommitReturnsNilForBlank() {
        #expect(TagInput.tagToCommit("   ", into: ["bug"], allowDuplicates: false) == nil)
        #expect(TagInput.tagToCommit("   ", into: ["bug"], allowDuplicates: true) == nil)
    }

    @Test("tagToCommit rejects duplicate when allowDuplicates is false")
    func tagToCommitRejectsDuplicateWhenDisallowed() {
        let result = TagInput.tagToCommit("bug", into: ["bug"], allowDuplicates: false)
        #expect(result == nil)
    }

    @Test("tagToCommit allows duplicate when allowDuplicates is true")
    func tagToCommitAllowsDuplicateWhenEnabled() {
        let result = TagInput.tagToCommit("bug", into: ["bug"], allowDuplicates: true)
        #expect(result == "bug")
    }

    @Test("tagToCommit dedupe check is case sensitive")
    func tagToCommitDedupeIsCaseSensitive() {
        // "Bug" (capitalized) is not considered a duplicate of existing "bug".
        let result = TagInput.tagToCommit("Bug", into: ["bug"], allowDuplicates: false)
        #expect(result == "Bug")
    }

    // MARK: - splitDraftOnSeparator (comma-delimited quick entry)

    @Test("splitDraftOnSeparator returns no segments when draft has no comma")
    func splitDraftOnSeparatorNoComma() {
        let result = TagInput.splitDraftOnSeparator("bug")
        #expect(result.segments.isEmpty)
        #expect(result.remainder == "bug")
    }

    @Test("splitDraftOnSeparator splits multiple comma-separated segments")
    func splitDraftOnSeparatorSplitsSegments() {
        let result = TagInput.splitDraftOnSeparator("bug, enhancement,")
        #expect(result.segments == ["bug", " enhancement"])
        #expect(result.remainder == "")
    }

    @Test("splitDraftOnSeparator keeps the trailing partial segment as remainder")
    func splitDraftOnSeparatorKeepsRemainder() {
        let result = TagInput.splitDraftOnSeparator("bug,enh")
        #expect(result.segments == ["bug"])
        #expect(result.remainder == "enh")
    }

    // MARK: - removingTag(at:from:) — offset-based identity, duplicate-safe

    @Test("removingTag deletes the correct element among duplicates by offset")
    func removingTagHandlesDuplicatesByOffset() {
        let result = TagInput.removingTag(at: 0, from: ["bug", "bug", "enhancement"])
        #expect(result == ["bug", "enhancement"])
    }

    @Test("removingTag at the second duplicate leaves the first untouched")
    func removingSecondDuplicateLeavesFirst() {
        let result = TagInput.removingTag(at: 1, from: ["bug", "bug", "enhancement"])
        #expect(result == ["bug", "enhancement"])
    }

    @Test("removingTag with an out-of-range index is a no-op")
    func removingTagOutOfRangeIsNoOp() {
        let result = TagInput.removingTag(at: 5, from: ["bug"])
        #expect(result == ["bug"])
    }

    @Test("removingTag with a negative index is a no-op")
    func removingTagNegativeIndexIsNoOp() {
        let result = TagInput.removingTag(at: -1, from: ["bug"])
        #expect(result == ["bug"])
    }
}
