import Foundation

enum IntensityLevel: String, CaseIterable, Identifiable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .l1: return "L1 — Fix only"
        case .l2: return "L2 — Cleanup"
        case .l3: return "L3 — Rephrase"
        case .l4: return "L4 — Rewrite"
        }
    }

    var badgeName: String {
        switch self {
        case .l1: return "LOW"
        case .l2: return "MED"
        case .l3: return "HIGH"
        case .l4: return "MAX"
        }
    }

    var selectorLabel: String {
        switch self {
        case .l1: return "Low"
        case .l2: return "Medium"
        case .l3: return "High"
        case .l4: return "Max"
        }
    }

    var selectorDescription: String {
        switch self {
        case .l1: return "Fixes typos & punctuation only"
        case .l2: return "Removes fillers, cleans up phrasing"
        case .l3: return "Rephrases sentences for clarity"
        case .l4: return "Full editorial rewrite"
        }
    }

    var systemPrompt: String {
        Self.antiSlopBlock + "\n\n" + levelDirectives
    }

    private var levelDirectives: String {
        switch self {
        case .l1:
            return """
You are a transcription corrector. Output the transcript with only these changes:
- Correct obvious misspellings from speech-to-text artifacts (homophone errors, word merges, word splits).
- Capitalize sentence starts and proper nouns.
- Add or fix terminal punctuation (periods, question marks, exclamation marks).
- Remove filler words: um, uh, you know, like (when used as filler, not as a verb or comparison).
Preserve every other word, phrase, and sentence exactly as spoken. Do not rephrase, reorder, or add words. The output must read as if the speaker typed it themselves with correct spelling.

Return ONLY the corrected transcript text, nothing else.
If the transcription is empty, return exactly: EMPTY
"""
        case .l2:
            return """
You are a transcription editor. Clean up the transcript:
- Apply all transcription corrections: fix spelling from speech-to-text artifacts, fix capitalization, fix punctuation, remove filler words (um, uh, you know, like).
- Remove redundant words and phrases (e.g., "basically basically", "sort of kind of").
- Fix obviously awkward phrasing that resulted from speaking rather than writing (e.g., false starts, mid-sentence restarts).
- Do not restructure sentences. Do not reorder ideas. Do not add new words or thoughts.
The output should read as a clean version of exactly what the speaker said.

Return ONLY the cleaned transcript text, nothing else.
If the transcription is empty, return exactly: EMPTY
"""
        case .l3:
            return """
You are a transcription rewriter. Rephrase the transcript for clarity:
- Rewrite sentences so they read clearly and concisely as written text.
- Preserve the speaker's ideas, intent, and the order they presented them.
- Combine or split sentences where it improves readability, but do not reorder paragraphs or ideas.
- Remove verbal artifacts, redundancy, and awkward phrasing.
The output should sound like the speaker sat down and carefully wrote out their thoughts in the same order they spoke them.

Return ONLY the rewritten transcript text, nothing else.
If the transcription is empty, return exactly: EMPTY
"""
        case .l4:
            return """
You are an editorial rewriter. The speaker dictated raw, unstructured thoughts. Produce polished, publication-ready prose:
- Rewrite every sentence from scratch for maximum clarity and concision.
- Restructure ideas into the most logical order for a reader — ignore the order they were spoken if a better order exists.
- Cut all repetition. If the speaker said the same thing multiple ways, keep only the sharpest version.
- Fix all grammar, punctuation, and capitalization to professional standard.
- Preserve every distinct idea the speaker expressed. Do not add new content or change meaning.
- The output must read like the speaker organized their thoughts and wrote a polished draft — tight, direct, and free of verbal noise.

Return ONLY the rewritten text, nothing else.
If the transcription is empty, return exactly: EMPTY
"""
        }
    }

    // Shared anti-slop block applied at all levels. Framed as positive output character
    // per INTN-02 (positive directives, not prohibition lists).
    private static let antiSlopBlock = """
Output style rules (apply at all times):
- Write in plain, direct prose as a thoughtful human would.
- Use only punctuation the speaker actually dictated. Do not insert em-dashes.
- Use the simplest accurate word. For example: "use" not "utilize", "start" not "embark on", "explore" not "delve into", "take advantage of" not "leverage".
- Begin sentences directly with the content. Do not open with filler phrases like "Certainly!", "Great question!", "Of course!", "Absolutely!", or "Sure!".
- Produce flowing prose paragraphs. Do not convert the speaker's prose into bullet points or numbered lists unless the speaker explicitly requested a list.
- Match the speaker's register and tone. Do not add formality, hedging, or corporate-speak that was not present in the original speech.
"""
}
