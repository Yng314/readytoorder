import Foundation
import UIKit

struct OrderingImageAttachment: Identifiable {
    let id: UUID
    let mimeType: String
    let dataBase64: String
    let previewImage: UIImage
}

struct OrderingChatImage: Identifiable {
    let id: UUID
    let previewImage: UIImage
}

struct OrderingChatMessage: Identifiable {
    enum Role: String, Codable {
        case user
        case assistant

        var menuChatRole: MenuChatRole {
            self == .user ? .user : .assistant
        }
    }

    let id: UUID
    let role: Role
    let text: String
    let recommendations: [MenuRecommendationItem]
    let images: [OrderingChatImage]

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        recommendations: [MenuRecommendationItem],
        images: [OrderingChatImage]
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.recommendations = recommendations
        self.images = images
    }

    static let welcome = OrderingChatMessage(
        role: .assistant,
        text: "先上传菜单图片（最多 6 张），再点“推荐菜品”。你也可以直接问我某道菜的细节。",
        recommendations: [],
        images: []
    )

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var historyText: String {
        let trimmed = trimmedText
        if !trimmed.isEmpty {
            return String(trimmed.prefix(300))
        }
        if !recommendations.isEmpty {
            let names = recommendations.map(\.name).joined(separator: "、")
            return String("推荐结果：\(names)".prefix(300))
        }
        return ""
    }

    var isIntroGuideText: Bool {
        role == .assistant &&
        images.isEmpty &&
        recommendations.isEmpty &&
        text.hasPrefix("先上传菜单图片")
    }
}

struct OrderingDetailParams: Codable, Hashable {
    var dinersText: String = ""
    var budgetText: String = ""
    var spiceLevel: String = "default"
    var allergiesText: String = ""
    var notes: String = ""

    mutating func reset() {
        dinersText = ""
        budgetText = ""
        spiceLevel = "default"
        allergiesText = ""
        notes = ""
    }

    func toBackendInput() -> MenuChatDetailParamsInput? {
        let dinersValue = clampedInt(from: dinersText, low: 1, high: 20)
        let budgetValue = clampedInt(from: budgetText, low: 1, high: 50_000)
        let allergies = allergiesText
            .split(whereSeparator: { ",，;；\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let notesValue = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasCustomValue =
            dinersValue != nil ||
            budgetValue != nil ||
            spiceLevel != "default" ||
            !allergies.isEmpty ||
            !notesValue.isEmpty
        guard hasCustomValue else { return nil }

        return MenuChatDetailParamsInput(
            diners: dinersValue,
            budgetCNY: budgetValue,
            spiceLevel: spiceLevel,
            allergies: Array(allergies.prefix(12)),
            notes: String(notesValue.prefix(200))
        )
    }

    private func clampedInt(from raw: String, low: Int, high: Int) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed) else { return nil }
        return max(low, min(high, value))
    }
}

struct OrderingChatSnapshot: Codable {
    struct StoredImage: Codable {
        let id: UUID
        let dataBase64: String
    }

    struct StoredMessage: Codable {
        let id: UUID
        let role: OrderingChatMessage.Role
        let text: String
        let recommendations: [MenuRecommendationItem]
        let images: [StoredImage]

        private enum CodingKeys: String, CodingKey {
            case id
            case role
            case text
            case recommendations
            case images
        }

        init(
            id: UUID,
            role: OrderingChatMessage.Role,
            text: String,
            recommendations: [MenuRecommendationItem],
            images: [StoredImage]
        ) {
            self.id = id
            self.role = role
            self.text = text
            self.recommendations = recommendations
            self.images = images
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            role = try container.decode(OrderingChatMessage.Role.self, forKey: .role)
            text = try container.decode(String.self, forKey: .text)
            recommendations = try container.decodeIfPresent([MenuRecommendationItem].self, forKey: .recommendations) ?? []
            images = try container.decodeIfPresent([StoredImage].self, forKey: .images) ?? []
        }
    }

    let messages: [StoredMessage]
    let detailParams: OrderingDetailParams
    let draftText: String
}
