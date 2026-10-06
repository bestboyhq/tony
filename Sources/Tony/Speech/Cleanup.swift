import Foundation

/// Text fixes between the model and the cursor.
nonisolated enum Cleanup {
    /// Hesitations in the languages Parakeet speaks. Not "ah", "oh", or "eh": those are often meant.
    static let fillers: Set<String> = [
        "um", "umm", "uh", "uhh", "uhm", "erm", "hmm", "hm", "mm", "mmm",  // English
        "äh", "ähm", "öhm",  // German
        "euh", "heu",  // French
        "ehm",  // Italian, Spanish, Dutch
        "yyy", "yy", "eee", "eem", "yhm",  // Polish
        "э", "ээ", "эм", "ммм",  // Russian, Ukrainian
    ]

    /// Drops filler words, keeping the punctuation and capitals of the sentence around them.
    static func removeFillers(_ text: String) -> String {
        var words: [String] = []
        var capitalizeNext = false
        for word in text.split(separator: " ").map(String.init) {
            let core = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            guard fillers.contains(core) else {
                words.append(capitalizeNext ? word.prefix(1).uppercased() + word.dropFirst() : word)
                capitalizeNext = false
                continue
            }
            let startsSentence = words.last.map { $0.last.map(".!?".contains) ?? true } ?? true
            if let end = word.last, ".!?".contains(end), var previous = words.popLast() {
                // "Fine, um." -> "Fine."
                if previous.last == "," { previous.removeLast() }
                if !(previous.last.map(".!?".contains) ?? false) { previous.append(end) }
                words.append(previous)
                capitalizeNext = true
                continue
            }
            if word.last == ",", var previous = words.popLast() {
                // "I, uh, think" -> "I think"
                if previous.last == "," { previous.removeLast() }
                words.append(previous)
            }
            if startsSentence { capitalizeNext = true }  // "Um, so" -> "So"
        }
        return words.joined(separator: " ")
    }

    /// Fits text to what is before the cursor: a space after a word, none at a line start or after an
    /// opening bracket, and no capital mid-sentence, unless the text starts with one of the user's `words`.
    /// `before` nil means the app didn't say, so the text goes in as transcribed.
    static func fit(_ text: String, after before: String?, keeping words: [String] = []) -> String {
        guard let before, !text.isEmpty else { return text }
        guard let last = before.last else { return text }  // the start of the field
        var text = text
        let lastVisible = before.last { !$0.isWhitespace }
        let sentenceStart = lastVisible == nil || ".!?".contains(lastVisible!) || before.last!.isNewline
        let startsWithWord = words.contains { text.hasPrefix($0) && !(text.dropFirst($0.count).first?.isLetter ?? false) }
        if !sentenceStart, !startsWithWord, let first = text.split(separator: " ").first, looksCapitalizedOnlyForTheSentence(first) {
            // ponytail: a proper noun at the start that isn't in the user's words ("Simon") gets lowercased too.
            text = text.prefix(1).lowercased() + text.dropFirst()
        }
        if !last.isWhitespace, !"([{\"'“‘/-".contains(last) {
            text = " " + text
        }
        return text
    }

    /// "Hello" yes; "I", "I'm", "NASA", "iPhone" no.
    private static func looksCapitalizedOnlyForTheSentence(_ word: Substring) -> Bool {
        let letters = word.prefix { $0.isLetter }
        guard let first = letters.first, first.isUppercase, letters.count > 1 else { return false }
        return letters.dropFirst().allSatisfy(\.isLowercase)
    }
}
