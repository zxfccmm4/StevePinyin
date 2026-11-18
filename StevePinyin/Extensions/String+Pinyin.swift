import Foundation

extension String {
    func removingToneMarks() -> String {
        folding(options: .diacriticInsensitive, locale: .current)
    }

    func containsChineseCharacters() -> Bool {
        unicodeScalars.contains {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||
            ($0.value >= 0x20000 && $0.value <= 0x2A6DF) ||
            ($0.value >= 0x2A700 && $0.value <= 0x2B73F) ||
            ($0.value >= 0x2B740 && $0.value <= 0x2B81F) ||
            ($0.value >= 0x2B820 && $0.value <= 0x2CEAF) ||
            ($0.value >= 0x2CEB0 && $0.value <= 0x2EBEF) ||
            ($0.value >= 0xF900 && $0.value <= 0xFAFF)
        }
    }

    func safePrefix(_ count: Int) -> String {
        isEmpty ? "" : String(prefix(count))
    }

    func safeDropFirst(_ count: Int = 1) -> String {
        self.count <= count ? "" : String(dropFirst(count))
    }

    func formatPinyin(for format: PinyinFormat) -> String {
        guard !isEmpty else { return "" }

        switch format {
        case .withTone:
            return safePrefix(1).uppercased() + safeDropFirst()
        case .plainLetter, .plainNoSpace:
            let noTone = removingToneMarks()
            return noTone.safePrefix(1).uppercased() + noTone.safeDropFirst()
        case .firstLetter, .firstNoSpace, .nickname:
            return removingToneMarks().safePrefix(1).uppercased()
        }
    }
}
