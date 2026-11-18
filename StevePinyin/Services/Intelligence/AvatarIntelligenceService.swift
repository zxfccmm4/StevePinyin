import Contacts
import Foundation
import FoundationModels
import UIKit

enum AvatarIntelligenceMode: String, CaseIterable, Identifiable, Sendable {
    case demo
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demo:
            return "本地规则模式"
        case .system:
            return "Apple Intelligence 模式"
        }
    }

    var description: String {
        switch self {
        case .demo:
            return "使用确定性图像统计与关键词规则评估头像质量与联系人匹配，离线零延迟。"
        case .system:
            return "使用设备端 Foundation Models 多模态图像分析与语义推荐；模型不可用时自动平滑回退本地规则。"
        }
    }
}

enum AvatarIntelligenceTaskKind: Sendable {
    case avatarQuality
    case avatarRecommendation
    case polyphonicDisambiguation
}

struct StevePinyinIntelligenceProfile: LanguageModelSession.DynamicProfile {
    let kind: AvatarIntelligenceTaskKind

    var body: some LanguageModelSession.DynamicProfile {
        switch kind {
        case .avatarQuality:
            LanguageModelSession.Profile {
                Instructions("你是通讯录头像质量顾问。请结合附加图片评估主体清晰度、构图居中度与光线对比度，给出0到100的适合度评分与简短中文建议。")
            }
            .model(SystemLanguageModel(guardrails: .permissiveContentTransformations))
            .temperature(0.1)

        case .avatarRecommendation:
            LanguageModelSession.Profile {
                Instructions("你是联系人头像匹配助手。根据联系人的姓名、拼音、组织特征，从候选头像名称中挑选最契合的前几项并给出简短中文理由。")
            }
            .model(SystemLanguageModel(guardrails: .permissiveContentTransformations))
            .temperature(0.2)
            .historyTransform { Array($0.suffix(4)) }

        case .polyphonicDisambiguation:
            LanguageModelSession.Profile {
                Instructions("你是中文姓名与机构多音字正音专家。根据姓氏惯例与机构语境输出标准汉语拼音（含声调）。")
            }
            .model(SystemLanguageModel(guardrails: .permissiveContentTransformations))
            .temperature(0.0)
        }
    }
}

@Generable(description: "Multimodal avatar suitability score and concise advice")
struct GeneratedAvatarVisualInspection: Sendable {
    var image: ImageReference
    @Guide(description: "Visual suitability score from 0 to 100 for a circular contact avatar")
    var suitabilityScore: Int
    @Guide(description: "One short Chinese sentence describing framing, clarity, or lighting")
    var visualNote: String
}

@Generable(description: "Ranked candidate avatar names for a contact")
struct GeneratedAvatarSemanticMatchList: Sendable {
    @Guide(description: "Ordered list of best matching candidate icon names")
    var rankedIconNames: [String]
    @Guide(description: "Short Chinese explanation for the top match")
    var reason: String
}

@Generable(description: "Context-aware Mandarin pinyin with tone marks")
struct GeneratedPolyphonicReading: Sendable {
    @Guide(description: "Family name pinyin with tone marks")
    var familyNamePinyin: String
    @Guide(description: "Given name pinyin with tone marks")
    var givenNamePinyin: String
    @Guide(description: "Organization name pinyin with tone marks")
    var companyPinyin: String
}

enum AvatarQualityIssue: String, CaseIterable, Codable, Sendable {
    case tooSmall
    case lowDataSize
    case tooDark
    case tooBright
    case lowContrast
    case unusualAspectRatio

    var title: String {
        switch self {
        case .tooSmall:
            return "分辨率偏低"
        case .lowDataSize:
            return "图片数据偏小"
        case .tooDark:
            return "画面偏暗"
        case .tooBright:
            return "画面偏亮"
        case .lowContrast:
            return "对比度偏低"
        case .unusualAspectRatio:
            return "比例不适合头像"
        }
    }

    var suggestion: String {
        switch self {
        case .tooSmall:
            return "建议使用边长至少 256px 的头像。"
        case .lowDataSize:
            return "建议检查图片是否被过度压缩。"
        case .tooDark:
            return "建议选择光线更充足的头像。"
        case .tooBright:
            return "建议选择曝光更均衡的头像。"
        case .lowContrast:
            return "建议选择主体和背景更容易区分的头像。"
        case .unusualAspectRatio:
            return "建议使用接近正方形的头像。"
        }
    }
}

struct AvatarQualityAssessment: Equatable, Sendable {
    let score: Int
    let issues: [AvatarQualityIssue]
    let pixelSize: CGSize
    let dataSize: Int
    let averageBrightness: Double
    let contrast: Double
    let modelNote: String?

    init(
        score: Int,
        issues: [AvatarQualityIssue],
        pixelSize: CGSize,
        dataSize: Int,
        averageBrightness: Double,
        contrast: Double,
        modelNote: String? = nil
    ) {
        self.score = score
        self.issues = issues
        self.pixelSize = pixelSize
        self.dataSize = dataSize
        self.averageBrightness = averageBrightness
        self.contrast = contrast
        self.modelNote = modelNote
    }

    var isRecommended: Bool {
        score >= 75 && issues.contains(.tooSmall) == false
    }

    var summary: String {
        if let modelNote, modelNote.isEmpty == false {
            return modelNote
        }
        if issues.isEmpty {
            return "头像质量良好，适合导入。"
        }

        let issueTitles = issues.map(\.title).joined(separator: "、")
        return "头像可用，但建议优化：\(issueTitles)。"
    }
}

struct AvatarRecommendation: Identifiable, Equatable, Sendable {
    let contactID: String
    let icon: Icon
    let score: Int
    let reasons: [String]

    var id: String {
        "\(contactID)-\(icon.id)"
    }
}

enum AvatarIntelligenceError: LocalizedError, Equatable {
    case invalidImageData
    case noIconsAvailable

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "无法读取头像图片数据"
        case .noIconsAvailable:
            return "没有可用于推荐的头像"
        }
    }
}

struct AvatarIntelligenceService {
    var isSystemModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    func availabilitySummary(mode: AvatarIntelligenceMode = .demo) -> String {
        switch mode {
        case .demo:
            return "本地规则模式已启用：使用确定性图像分析与关键词匹配。"
        case .system:
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Apple Intelligence 设备端模型就绪：支持多模态头像质量评估、语义推荐与多音字判别。"
            case .unavailable(let reason):
                return "当前设备 Apple Intelligence 暂不可用（\(String(describing: reason))），已自动启用本地规则兜底。"
            @unknown default:
                return "当前设备模型状态未知，已自动启用本地规则兜底。"
            }
        }
    }

    func analyzeAvatarQuality(imageData: Data, mode: AvatarIntelligenceMode = .demo) async throws -> AvatarQualityAssessment {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw AvatarIntelligenceError.invalidImageData
        }

        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let metrics = ImageQualityMetrics(cgImage: cgImage)
        let issues = qualityIssues(
            dataSize: imageData.count,
            pixelSize: pixelSize,
            averageBrightness: metrics.averageBrightness,
            contrast: metrics.contrast
        )
        var finalScore = qualityScore(
            dataSize: imageData.count,
            pixelSize: pixelSize,
            averageBrightness: metrics.averageBrightness,
            contrast: metrics.contrast,
            issues: issues
        )
        var modelNote: String? = nil

        if mode == .system, isSystemModelAvailable {
            do {
                let session = LanguageModelSession(
                    profile: StevePinyinIntelligenceProfile(kind: .avatarQuality)
                )
                let labelledImage = Attachment(cgImage).label("CandidateAvatar")
                let prompt = Prompt {
                    labelledImage
                    "请评估这张联系人候选头像（分辨率 \(Int(pixelSize.width))x\(Int(pixelSize.height))）。"
                }
                let response = try await session.respond(
                    to: prompt,
                    generating: GeneratedAvatarVisualInspection.self
                )
                let clampedModelScore = min(max(response.content.suitabilityScore, 0), 100)
                finalScore = Int((Double(finalScore) * 0.6 + Double(clampedModelScore) * 0.4).rounded())
                let trimmedNote = response.content.visualNote.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedNote.isEmpty == false {
                    modelNote = trimmedNote
                }
            } catch {
                modelNote = nil
            }
        }

        return AvatarQualityAssessment(
            score: finalScore,
            issues: issues,
            pixelSize: pixelSize,
            dataSize: imageData.count,
            averageBrightness: metrics.averageBrightness,
            contrast: metrics.contrast,
            modelNote: modelNote
        )
    }
    func recommendAvatars(
        for contact: CNContact,
        icons: [Icon],
        mode: AvatarIntelligenceMode = .demo,
        limit: Int = 3
    ) throws -> [AvatarRecommendation] {
        guard icons.isEmpty == false else {
            throw AvatarIntelligenceError.noIconsAvailable
        }

        let tokens = contactTokens(for: contact)
        let ranked = icons.map { icon in
            recommendation(for: contact, icon: icon, contactTokens: tokens)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.icon.name.localizedStandardCompare(rhs.icon.name) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        return Array(ranked.prefix(max(limit, 1)))
    }

    func recommendAvatars(
        for contacts: [CNContact],
        icons: [Icon],
        mode: AvatarIntelligenceMode = .demo,
        limitPerContact: Int = 3
    ) throws -> [String: [AvatarRecommendation]] {
        var result: [String: [AvatarRecommendation]] = [:]

        for contact in contacts {
            result[contact.stableIdentifier] = try recommendAvatars(
                for: contact,
                icons: icons,
                mode: mode,
                limit: limitPerContact
            )
        }

        return result
    }

    func recommendAvatarsAsync(
        for contact: CNContact,
        icons: [Icon],
        mode: AvatarIntelligenceMode,
        limit: Int = 3
    ) async throws -> [AvatarRecommendation] {
        let baseline = try recommendAvatars(for: contact, icons: icons, mode: .demo, limit: max(limit, 6))
        guard mode == .system, isSystemModelAvailable, baseline.count > 1 else {
            return Array(baseline.prefix(max(limit, 1)))
        }

        do {
            let session = LanguageModelSession(
                profile: StevePinyinIntelligenceProfile(kind: .avatarRecommendation)
            )
            let contactSummary = [
                "\(contact.familyName)\(contact.givenName)",
                contact.organizationName,
                contact.nickname,
            ]
            .filter { $0.isEmpty == false }
            .joined(separator: " / ")
            let candidateNames = baseline.map(\.icon.name).joined(separator: "、")
            let response = try await session.respond(
                to: "联系人：\(contactSummary)\n候选头像：\(candidateNames)\n请选出最匹配的最多 \(limit) 个头像名称。",
                generating: GeneratedAvatarSemanticMatchList.self
            )

            let rankedSet = response.content.rankedIconNames
            let modelReason = response.content.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let reranked = baseline.map { item -> AvatarRecommendation in
                if let rankIndex = rankedSet.firstIndex(where: { $0.localizedCaseInsensitiveCompare(item.icon.name) == .orderedSame }) {
                    let bonus = max(18 - rankIndex * 6, 6)
                    var updatedReasons = item.reasons
                    if modelReason.isEmpty == false {
                        updatedReasons.insert("AI 语义推荐：\(modelReason)", at: 0)
                    }
                    return AvatarRecommendation(
                        contactID: item.contactID,
                        icon: item.icon,
                        score: min(item.score + bonus, 100),
                        reasons: updatedReasons
                    )
                }
                return item
            }
            .sorted { $0.score > $1.score }

            return Array(reranked.prefix(max(limit, 1)))
        } catch {
            return Array(baseline.prefix(max(limit, 1)))
        }
    }

    func disambiguatePolyphonicPinyin(
        familyName: String,
        givenName: String,
        companyName: String
    ) async -> GeneratedPolyphonicReading? {
        guard isSystemModelAvailable else { return nil }
        do {
            let session = LanguageModelSession(
                profile: StevePinyinIntelligenceProfile(kind: .polyphonicDisambiguation)
            )
            let response = try await session.respond(
                to: "姓：\(familyName)，名：\(givenName)，公司：\(companyName)。请给出准确多音字拼音。",
                generating: GeneratedPolyphonicReading.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    private func qualityIssues(
        dataSize: Int,
        pixelSize: CGSize,
        averageBrightness: Double,
        contrast: Double
    ) -> [AvatarQualityIssue] {
        var issues: [AvatarQualityIssue] = []
        let shortestSide = min(pixelSize.width, pixelSize.height)
        let aspectRatio = max(pixelSize.width, pixelSize.height) / max(shortestSide, 1)

        if shortestSide < 256 {
            issues.append(.tooSmall)
        }

        if dataSize < 2_000 {
            issues.append(.lowDataSize)
        }

        if averageBrightness < 0.22 {
            issues.append(.tooDark)
        } else if averageBrightness > 0.88 {
            issues.append(.tooBright)
        }

        if contrast < 0.08 {
            issues.append(.lowContrast)
        }

        if aspectRatio > 1.35 {
            issues.append(.unusualAspectRatio)
        }

        return issues
    }

    private func qualityScore(
        dataSize: Int,
        pixelSize: CGSize,
        averageBrightness: Double,
        contrast: Double,
        issues: [AvatarQualityIssue]
    ) -> Int {
        let shortestSide = min(pixelSize.width, pixelSize.height)
        let resolutionScore = min(shortestSide / 512, 1) * 35
        let dataScore = min(Double(dataSize) / 12_000, 1) * 15
        let brightnessScore = max(0, 1 - abs(averageBrightness - 0.52) / 0.52) * 25
        let contrastScore = min(contrast / 0.25, 1) * 25
        let issuePenalty = Double(issues.count * 4)
        let rawScore = resolutionScore + dataScore + brightnessScore + contrastScore - issuePenalty

        return min(max(Int(rawScore.rounded()), 0), 100)
    }

    private func recommendation(
        for contact: CNContact,
        icon: Icon,
        contactTokens: Set<String>
    ) -> AvatarRecommendation {
        let iconTokens = tokens(from: "\(icon.name) \(icon.url)")
        var score = 20
        var reasons: [String] = []

        let overlap = contactTokens.intersection(iconTokens)
        if overlap.isEmpty == false {
            score += min(overlap.count * 25, 50)
            reasons.append("名称关键词匹配：\(overlap.sorted().prefix(3).joined(separator: "、"))")
        }

        if let initial = primaryInitial(for: contact),
           iconTokens.contains(initial) || icon.name.localizedCaseInsensitiveContains(initial) {
            score += 20
            reasons.append("头像名称包含联系人首字母 \(initial.uppercased())")
        }

        if contact.organizationName.isEmpty == false {
            let organizationTokens = tokens(from: contact.organizationName)
            let organizationOverlap = organizationTokens.intersection(iconTokens)
            if organizationOverlap.isEmpty == false {
                score += 15
                reasons.append("与公司/组织信息相关")
            }
        }

        if icon.isSystemIcon {
            score += 5
            reasons.append("系统符号导入稳定")
        }

        if reasons.isEmpty {
            reasons.append("默认候选，可作为手动选择备选")
        }

        return AvatarRecommendation(
            contactID: contact.stableIdentifier,
            icon: icon,
            score: min(score, 100),
            reasons: reasons
        )
    }

    private func contactTokens(for contact: CNContact) -> Set<String> {
        tokens(
            from: [
                contact.givenName,
                contact.familyName,
                contact.nickname,
                contact.organizationName,
                contact.phoneticGivenName,
                contact.phoneticFamilyName,
                contact.phoneticOrganizationName,
            ].joined(separator: " ")
        )
    }

    private func primaryInitial(for contact: CNContact) -> String? {
        let candidates = [
            contact.givenName,
            contact.familyName,
            contact.nickname,
            contact.organizationName,
            contact.phoneticGivenName,
            contact.phoneticFamilyName,
        ]

        for candidate in candidates {
            guard let first = candidate.trimmingCharacters(in: .whitespacesAndNewlines).first else {
                continue
            }
            return String(first).lowercased()
        }

        return nil
    }

    private func tokens(from text: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        let latinTokens = text
            .lowercased()
            .components(separatedBy: separators)
            .filter { $0.count >= 2 }

        let scalarTokens = text
            .filter { character in
                character.unicodeScalars.contains { $0.value > 0x7F } &&
                    !character.isWhitespace &&
                    !character.isPunctuation &&
                    !character.isSymbol
            }
            .map { String($0).lowercased() }
            .filter { $0.isEmpty == false }

        return Set(latinTokens + scalarTokens)
    }
}

private struct ImageQualityMetrics {
    let averageBrightness: Double
    let contrast: Double

    init(cgImage: CGImage) {
        let sampleSize = 32
        let bytesPerPixel = 4
        let bytesPerRow = sampleSize * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

        guard let context = CGContext(
            data: &rawData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            averageBrightness = 0
            contrast = 0
            return
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var luminanceValues: [Double] = []
        luminanceValues.reserveCapacity(sampleSize * sampleSize)

        for index in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            let red = Double(rawData[index]) / 255
            let green = Double(rawData[index + 1]) / 255
            let blue = Double(rawData[index + 2]) / 255
            luminanceValues.append((0.2126 * red) + (0.7152 * green) + (0.0722 * blue))
        }

        let average = luminanceValues.reduce(0, +) / Double(max(luminanceValues.count, 1))
        let variance = luminanceValues.reduce(0) { partial, value in
            partial + pow(value - average, 2)
        } / Double(max(luminanceValues.count, 1))

        averageBrightness = average
        contrast = sqrt(variance)
    }
}
