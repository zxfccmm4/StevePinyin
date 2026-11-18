import Foundation
@preconcurrency import Contacts

struct ContactPinyinTransformer {
    static let shared = ContactPinyinTransformer()

    struct ConvertedContact {
        let familyNamePinyin: String
        let givenNamePinyin: String
        let companyPinyin: String
        let displayPinyin: String
    }

    func shouldSkipEnglishOnlyContact(_ contact: CNContact) -> Bool {
        let fullName = "\(contact.familyName)\(contact.givenName)"
        let companyName = contact.organizationName

        return (!fullName.isEmpty && !fullName.containsChineseCharacters()) &&
            (companyName.isEmpty || !companyName.containsChineseCharacters())
    }

    func convert(_ contact: CNContact, format: PinyinFormat) -> ConvertedContact {
        let familyNamePinyin = processFamilyName(contact.familyName, format: format)
        let givenNamePinyin = processGivenName(contact.givenName, format: format)
        let companyPinyin = processCompanyName(contact.organizationName, format: format)
        var displayPinyin = familyNamePinyin

        if !givenNamePinyin.isEmpty {
            let needsSpace = format != .plainNoSpace && format != .firstNoSpace
            displayPinyin += needsSpace && !displayPinyin.isEmpty ? " \(givenNamePinyin)" : givenNamePinyin
        }

        return ConvertedContact(
            familyNamePinyin: familyNamePinyin,
            givenNamePinyin: givenNamePinyin,
            companyPinyin: companyPinyin,
            displayPinyin: displayPinyin.trimmingCharacters(in: .whitespaces)
        )
    }

    func buildNickname(for contact: CNContact, format: PinyinFormat) -> String {
        var nickname = ""

        if !contact.familyName.isEmpty {
            for (index, char) in contact.familyName.enumerated() {
                let charString = String(char)

                if index == 0,
                   SpecialSurnameManager.shared.isSpecialSurname(charString),
                   let specialReading = SpecialSurnameManager.shared.getSurnameReading(charString)
                {
                    nickname += nicknamePiece(from: specialReading, format: format)
                } else {
                    let pinyin = charString.applyingTransform(.mandarinToLatin, reverse: false) ?? ""
                    nickname += nicknamePiece(from: pinyin, format: format)
                }
            }
        }

        if !contact.givenName.isEmpty {
            nickname += nicknameFromText(contact.givenName, format: format)
        }

        if !contact.organizationName.isEmpty {
            nickname += companyNickname(from: contact.organizationName, format: format)
        }

        return nickname
    }

    private func processFamilyName(_ familyName: String, format: PinyinFormat) -> String {
        guard !familyName.isEmpty else { return "" }

        var processedFamilyName = ""

        for (index, char) in familyName.enumerated() {
            let charString = String(char)

            if index == 0,
               SpecialSurnameManager.shared.isSpecialSurname(charString),
               let specialReading = SpecialSurnameManager.shared.getSurnameReading(charString)
            {
                processedFamilyName += specialReading.formatPinyin(for: format)
            } else {
                let pinyin = charString.applyingTransform(.mandarinToLatin, reverse: false) ?? ""
                let reading = pinyin.formatPinyin(for: format)
                let needsSpace = index > 0 && format != .plainNoSpace && format != .firstNoSpace
                processedFamilyName += needsSpace ? " \(reading)" : reading
            }
        }

        return processedFamilyName
    }

    private func processGivenName(_ givenName: String, format: PinyinFormat) -> String {
        guard !givenName.isEmpty else { return "" }

        var processedPinyin = ""

        for (index, char) in givenName.enumerated() {
            let charString = String(char)
            let reading: String

            if let normalReading = SpecialSurnameManager.shared.getNormalReading(charString) {
                reading = normalReading.formatPinyin(for: format)
            } else {
                let pinyin = charString.applyingTransform(.mandarinToLatin, reverse: false) ?? ""
                reading = pinyin.formatPinyin(for: format)
            }

            let needsSpace = index > 0 && format != .plainNoSpace && format != .firstNoSpace
            processedPinyin += needsSpace ? " \(reading)" : reading
        }

        return processedPinyin
    }

    private func processCompanyName(_ companyName: String, format: PinyinFormat) -> String {
        guard !companyName.isEmpty else { return "" }

        let characters = Array(companyName)
        let needsSpaceBetweenSyllables = format != .plainNoSpace && format != .firstNoSpace
        var pieces: [String] = []
        pieces.reserveCapacity(characters.count)
        var currentIndex = 0

        while currentIndex < characters.count {
            if let match = SpecialWordsManager.shared.longestMatch(in: characters, startingAt: currentIndex) {
                for syllable in match.syllables {
                    let formatted = syllable.formatPinyin(for: format)
                    if !formatted.isEmpty {
                        pieces.append(formatted)
                    }
                }
                currentIndex += match.characters.count
            } else {
                let pinyin = String(characters[currentIndex]).applyingTransform(.mandarinToLatin, reverse: false) ?? ""
                let reading = pinyin.formatPinyin(for: format)
                if !reading.isEmpty {
                    pieces.append(reading)
                }
                currentIndex += 1
            }
        }

        return pieces.joined(separator: needsSpaceBetweenSyllables ? " " : "")
    }

    private func companyNickname(from companyName: String, format: PinyinFormat) -> String {
        let characters = Array(companyName)
        var result = ""
        var currentIndex = 0

        while currentIndex < characters.count {
            if let match = SpecialWordsManager.shared.longestMatch(in: characters, startingAt: currentIndex) {
                for syllable in match.syllables {
                    result += nicknamePiece(from: syllable, format: format)
                }
                currentIndex += match.characters.count
            } else {
                result += nicknameFromText(String(characters[currentIndex]), format: format)
                currentIndex += 1
            }
        }

        return result
    }

    private func nicknameFromText(_ text: String, format: PinyinFormat) -> String {
        let pinyin = text.applyingTransform(.mandarinToLatin, reverse: false) ?? ""
        let words = pinyin
            .removingToneMarks()
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        if format == .plainNoSpace {
            return words
                .map { $0.safePrefix(1).uppercased() + $0.safeDropFirst() }
                .joined()
        }

        return words
            .map { $0.safePrefix(1) }
            .joined()
            .uppercased()
    }

    private func nicknamePiece(from reading: String, format: PinyinFormat) -> String {
        let noTone = reading.removingToneMarks()

        if format == .plainNoSpace {
            return noTone.safePrefix(1).uppercased() + noTone.safeDropFirst()
        }

        return noTone.safePrefix(1).uppercased()
    }
}
