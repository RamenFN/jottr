import Foundation

enum SnippetEngine {

    /// Apply snippet substitutions to `transcript`, returning the substituted string.
    ///
    /// - Parameters:
    ///   - snippets: All known snippets; disabled ones are skipped automatically.
    ///   - transcript: The raw Whisper transcript to process.
    /// - Returns: The transcript with every enabled trigger replaced by its expansion.
    ///
    /// Algorithm:
    ///   1. Filter to enabled snippets only.
    ///   2. Sort by trigger length descending (longest-match-first). Swift sort is stable,
    ///      so equal-length triggers preserve their original order ("first defined wins").
    ///   3. For each snippet, run a single-pass boundary-aware replacement over the running
    ///      result string. Expansion text is never re-scanned (no loop risk).
    static func apply(_ snippets: [Snippet], to transcript: String) -> String {
        let enabled = snippets.filter(\.isEnabled)
        guard !enabled.isEmpty else { return transcript }

        let sorted = enabled.sorted { $0.trigger.count > $1.trigger.count }

        var result = transcript
        for snippet in sorted {
            guard !snippet.trigger.isEmpty else { continue }
            result = replaceBoundaryAware(
                trigger: snippet.trigger,
                expansion: snippet.expansion,
                in: result
            )
        }
        return result
    }

    // MARK: - Private helpers

    /// Replace all boundary-valid occurrences of `trigger` (case-insensitive) with `expansion`
    /// in a single forward pass. The expansion is inserted verbatim; the pass never revisits it.
    ///
    /// Boundary rule: A match is valid only when:
    ///   - the character immediately BEFORE it is whitespace, punctuation, symbol, or string start
    ///   - the character immediately AFTER it is whitespace, punctuation, symbol, or string end
    ///
    /// String.Index safety: `lowerText` and `text` share the same index space only when
    /// `lowercased()` does not change the string's encoding length. For ASCII-dominant Whisper
    /// output this always holds. We additionally use character-offset math to derive original
    /// indices from lowercased indices, guarding against the theoretical multi-byte edge case.
    private static func replaceBoundaryAware(
        trigger: String,
        expansion: String,
        in text: String
    ) -> String {
        let lowerText = text.lowercased()
        let lowerTrigger = trigger.lowercased()
        guard !lowerTrigger.isEmpty else { return text }

        var result = ""
        var searchStart = lowerText.startIndex
        // Parallel index into the original text, kept in sync with `searchStart`.
        var originalStart = text.startIndex

        while searchStart < lowerText.endIndex {
            // Find next candidate match in the lowercased text.
            guard let matchRange = lowerText.range(of: lowerTrigger, range: searchStart..<lowerText.endIndex) else {
                // No more candidates — append the rest of the original text verbatim.
                result += text[originalStart...]
                return result
            }

            // Check leading boundary character.
            let leadOK: Bool
            if matchRange.lowerBound == lowerText.startIndex {
                leadOK = true
            } else {
                leadOK = isBoundaryChar(lowerText[lowerText.index(before: matchRange.lowerBound)])
            }

            // Check trailing boundary character.
            let trailOK: Bool
            if matchRange.upperBound == lowerText.endIndex {
                trailOK = true
            } else {
                trailOK = isBoundaryChar(lowerText[matchRange.upperBound])
            }

            if leadOK && trailOK {
                // Compute the matching range in the original text via character offsets.
                let prefixCount = lowerText.distance(from: searchStart, to: matchRange.lowerBound)
                let origMatchStart = text.index(originalStart, offsetBy: prefixCount)
                let triggerCount = lowerText.distance(from: matchRange.lowerBound, to: matchRange.upperBound)
                let origMatchEnd = text.index(origMatchStart, offsetBy: triggerCount)

                // Append text before the match, then the expansion.
                result += text[originalStart..<origMatchStart]
                result += expansion

                // Advance past the match.
                originalStart = origMatchEnd
                searchStart = matchRange.upperBound
            } else {
                // Not a boundary match — step forward one character and retry.
                let step = lowerText.index(after: searchStart)
                let origStep = text.index(after: originalStart)
                result += text[originalStart..<origStep]
                originalStart = origStep
                searchStart = step
            }
        }

        // Append any remaining text (if the loop exited without hitting `guard` above).
        result += text[originalStart...]
        return result
    }

    private static func isBoundaryChar(_ c: Character) -> Bool {
        c.isWhitespace || c.isPunctuation || c.isSymbol
    }
}
