import Foundation

struct DocumentStatistics {
    let characters: Int
    let words: Int
    let lines: Int
    let readingMinutes: Int

    init(source: String) {
        characters = source.count
        lines = max(1, source.components(separatedBy: .newlines).count)

        let latinWords = source.split { character in
            character.isWhitespace || character.isPunctuation || character.isNewline
        }.filter { token in
            token.contains { $0.isLetter && !$0.isCJK }
        }.count
        let cjkCharacters = source.filter(\.isCJK).count
        words = latinWords + cjkCharacters
        readingMinutes = max(1, Int(ceil(Double(words) / 300)))
    }
}

private extension Character {
    var isCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value) ||
            (0x3040...0x30FF).contains(scalar.value) ||
            (0xAC00...0xD7AF).contains(scalar.value)
        }
    }
}
