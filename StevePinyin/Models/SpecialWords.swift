import Foundation

final class SpecialWordsManager: Sendable {
    static let shared = SpecialWordsManager()

    struct Entry: Sendable {
        let characters: [Character]
        let word: String
        let syllables: [String]
    }

    let specialWordSyllables: [String: [String]] = [
        "银行": ["yín", "háng"],
        "行长": ["háng", "zhǎng"],
        "同行": ["tóng", "háng"],
        "行业": ["háng", "yè"],
        "重庆": ["chóng", "qìng"],
        "长春": ["cháng", "chūn"],
        "厦门": ["xià", "mén"],
        "会计": ["kuài", "jì"],
        "证券": ["zhèng", "quàn"],
        "西藏": ["xī", "zàng"],
        "东莞": ["dōng", "guǎn"],
        "番禺": ["pān", "yú"],
        "六安": ["lù", "ān"],
        "蚌埠": ["bèng", "bù"],
    ]

    var specialWords: [String: String] {
        specialWordSyllables.mapValues { $0.joined().removingToneMarks() }
    }

    private let bucketsByFirstCharacter: [Character: [Entry]]

    private init() {
        var buckets: [Character: [Entry]] = [:]
        for (word, syllables) in specialWordSyllables {
            let chars = Array(word)
            guard let first = chars.first else { continue }
            buckets[first, default: []].append(Entry(characters: chars, word: word, syllables: syllables))
        }
        for key in buckets.keys {
            buckets[key]?.sort { $0.characters.count > $1.characters.count }
        }
        self.bucketsByFirstCharacter = buckets
    }

    func isSpecialWord(_ word: String) -> Bool {
        specialWordSyllables[word] != nil
    }

    func getWordReading(_ word: String) -> String? {
        specialWordSyllables[word]?.joined().removingToneMarks()
    }

    func longestMatch(in characters: [Character], startingAt startIndex: Int) -> Entry? {
        guard startIndex < characters.count,
              let candidates = bucketsByFirstCharacter[characters[startIndex]] else {
            return nil
        }

        for entry in candidates {
            let endIndex = startIndex + entry.characters.count
            guard endIndex <= characters.count else { continue }
            var matches = true
            for offset in 0 ..< entry.characters.count where characters[startIndex + offset] != entry.characters[offset] {
                matches = false
                break
            }
            if matches {
                return entry
            }
        }
        return nil
    }
}
