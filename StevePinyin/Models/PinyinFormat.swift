import Foundation

enum PinyinFormat: String, CaseIterable, Sendable {
    case withTone
    case plainLetter
    case firstLetter
    case plainNoSpace
    case firstNoSpace
    case nickname
}
