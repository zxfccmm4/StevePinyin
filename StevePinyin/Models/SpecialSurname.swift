import Foundation

struct SpecialSurname {
    let character: String
    let surnameReading: String
    let normalReading: String
}

class SpecialSurnameManager {
    static let shared = SpecialSurnameManager()
    
    private let specialSurnames: [String: SpecialSurname] = [
        "单": SpecialSurname(character: "单", surnameReading: "Shàn", normalReading: "Dān"),
        "曾": SpecialSurname(character: "曾", surnameReading: "Zēng", normalReading: "Céng"),
        "解": SpecialSurname(character: "解", surnameReading: "Xiè", normalReading: "Jiě"),
        "查": SpecialSurname(character: "查", surnameReading: "Zhā", normalReading: "Chá"),
        "翟": SpecialSurname(character: "翟", surnameReading: "Zhái", normalReading: "Dí"),
        "重": SpecialSurname(character: "重", surnameReading: "Chóng", normalReading: "Zhòng"),
        "区": SpecialSurname(character: "区", surnameReading: "Ōu", normalReading: "Qū"),
        "秘": SpecialSurname(character: "秘", surnameReading: "Bì", normalReading: "Mì"),
        "乐": SpecialSurname(character: "乐", surnameReading: "Yuè", normalReading: "Lè"),
        "任": SpecialSurname(character: "任", surnameReading: "Rén", normalReading: "Rèn"),
        "覃": SpecialSurname(character: "覃", surnameReading: "Qín", normalReading: "Tán"),
        "柏": SpecialSurname(character: "柏", surnameReading: "Bǎi", normalReading: "Bò"),
        "盖": SpecialSurname(character: "盖", surnameReading: "Gě", normalReading: "Gài"),
        "贾": SpecialSurname(character: "贾", surnameReading: "Jiǎ", normalReading: "Gǔ"),
        "宁": SpecialSurname(character: "宁", surnameReading: "Níng", normalReading: "Nìng"),
        "折": SpecialSurname(character: "折", surnameReading: "Shé", normalReading: "Zhé"),
        "繁": SpecialSurname(character: "繁", surnameReading: "Pó", normalReading: "Fán"),
        "冼": SpecialSurname(character: "冼", surnameReading: "Xiǎn", normalReading: "Shǎn"),
        "种": SpecialSurname(character: "种", surnameReading: "Zhòng", normalReading: "Chóng"),
        "句": SpecialSurname(character: "句", surnameReading: "Gōu", normalReading: "Jù"),
        "仇": SpecialSurname(character: "仇", surnameReading: "Chóu", normalReading: "Qiú"),
        "员": SpecialSurname(character: "员", surnameReading: "Yún", normalReading: "Yuán"),
        "尉": SpecialSurname(character: "尉", surnameReading: "Yù", normalReading: "Wèi"),
        "牟": SpecialSurname(character: "牟", surnameReading: "Mù", normalReading: "Máo"),
        "宿": SpecialSurname(character: "宿", surnameReading: "Sù", normalReading: "Xiǔ"),
        "牵": SpecialSurname(character: "牵", surnameReading: "Qiān", normalReading: "Qiǎn"),
        "朴": SpecialSurname(character: "朴", surnameReading: "Piáo", normalReading: "Pǔ"),
        "艾": SpecialSurname(character: "艾", surnameReading: "Ài", normalReading: "Yì"),
        "师": SpecialSurname(character: "师", surnameReading: "Shī", normalReading: "Sì"),
        "应": SpecialSurname(character: "应", surnameReading: "Yīng", normalReading: "Yìng")
    ]
    
    func isSpecialSurname(_ character: String) -> Bool {
        return specialSurnames[character] != nil
    }
    
    func getSurnameReading(_ character: String) -> String? {
        return specialSurnames[character]?.surnameReading
    }
    
    func getNormalReading(_ character: String) -> String? {
        return specialSurnames[character]?.normalReading
    }
}
