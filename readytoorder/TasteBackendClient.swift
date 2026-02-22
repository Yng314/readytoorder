//
//  TasteBackendClient.swift
//  readytoorder
//
//  Created by Codex on 2026/2/19.
//

import Foundation

struct TasteAnalysisResult: Codable {
    let summary: String
    let avoid: String
    let strategy: String
    let source: String
}

enum MenuChatMode: String, Codable {
    case chat
    case recommend
}

enum MenuChatRole: String, Codable {
    case user
    case assistant
}

struct MenuChatImageInput: Codable, Hashable {
    let mimeType: String
    let dataBase64: String
}

struct MenuChatTurnInput: Codable, Hashable {
    let role: MenuChatRole
    let text: String
}

struct MenuChatDetailParamsInput: Codable, Hashable {
    let diners: Int?
    let budgetCNY: Int?
    let spiceLevel: String
    let allergies: [String]
    let notes: String
}

struct MenuTasteContextInput: Hashable {
    let totalSwipes: Int
    let topPositive: [TasteInsight]
    let topNegative: [TasteInsight]
    let recentLikes: [String]
}

struct MenuRecommendationItem: Codable, Hashable, Identifiable {
    let name: String
    let originalName: String
    let reason: String
    let matchScore: Int
    let style: String

    var id: String {
        "\(style)|\(name)|\(originalName)"
    }
}

struct MenuChatResult: Codable, Hashable {
    let mode: MenuChatMode
    let reply: String
    let recommendations: [MenuRecommendationItem]
    let source: String
}

final class TasteBackendClient {
    static let shared = TasteBackendClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isConfigured: Bool {
        baseURL != nil
    }

    func fetchDeck(
        count: Int,
        positive: [TasteInsight],
        negative: [TasteInsight],
        recentLikes: [String],
        avoidNames: [String]
    ) async throws -> (dishes: [DishCandidate], source: String) {
        guard let baseURL else { throw URLError(.badURL) }

        let payload = DeckRequestPayload(
            count: count,
            feature_scores: [:],
            top_positive: positive.map { .init(id: $0.feature.id.rawValue, score: $0.score) },
            top_negative: negative.map { .init(id: $0.feature.id.rawValue, score: $0.score) },
            recent_likes: recentLikes,
            avoid_names: avoidNames,
            locale: "zh-CN"
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/taste/deck"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)

        let decoded = try decoder.decode(DeckResponsePayload.self, from: data)
        let dishes: [DishCandidate] = decoded.dishes.compactMap { item in
            let signals = item.signals.compactMapValues { value -> Double? in
                guard value.isFinite else { return nil }
                return max(0, min(1, value))
            }

            var normalized: [TasteFeatureID: Double] = [:]
            for entry in signals {
                let (key, value) = entry
                guard let feature = TasteFeatureID(rawValue: key) else { continue }
                normalized[feature] = value
            }

            guard !item.name.isEmpty, normalized.count >= 2 else {
                return nil
            }
            return DishCandidate(
                name: item.name,
                subtitle: item.subtitle,
                signals: normalized,
                categoryTags: normalizedCategoryTags(item.category_tags),
                imageDataURL: item.image_data_url
            )
        }

        return (dishes, decoded.source)
    }

    func analyzeTaste(
        totalSwipes: Int,
        positive: [TasteInsight],
        negative: [TasteInsight],
        recentEvents: [SwipeEvent]
    ) async throws -> TasteAnalysisResult {
        guard let baseURL else { throw URLError(.badURL) }

        let payload = AnalyzeRequestPayload(
            total_swipes: totalSwipes,
            top_positive: positive.map { .init(id: $0.feature.id.rawValue, score: $0.score) },
            top_negative: negative.map { .init(id: $0.feature.id.rawValue, score: $0.score) },
            recent_events: recentEvents.prefix(20).map {
                AnalyzeRequestPayload.RecentEventPayload(
                    dish_name: $0.dish.name,
                    action: $0.action.rawValue,
                    features: Array($0.dish.signals.keys.map(\.rawValue).prefix(5))
                )
            }
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/taste/analyze"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)

        return try decoder.decode(TasteAnalysisResult.self, from: data)
    }

    func menuChat(
        mode: MenuChatMode,
        message: String,
        images: [MenuChatImageInput],
        history: [MenuChatTurnInput],
        tasteContext: MenuTasteContextInput,
        params: MenuChatDetailParamsInput?
    ) async throws -> MenuChatResult {
        guard let baseURL else { throw URLError(.badURL) }

        let payload = MenuChatRequestPayload(
            mode: mode.rawValue,
            message: message,
            images: images.map { .init(mime_type: $0.mimeType, data_base64: $0.dataBase64) },
            chat_history: history.map { .init(role: $0.role.rawValue, text: $0.text) },
            total_swipes: tasteContext.totalSwipes,
            top_positive: tasteContext.topPositive.map { .init(id: $0.feature.id.rawValue, score: $0.score) },
            top_negative: tasteContext.topNegative.map { .init(id: $0.feature.id.rawValue, score: $0.score) },
            recent_likes: tasteContext.recentLikes,
            params: params.map {
                .init(
                    diners: $0.diners,
                    budget_cny: $0.budgetCNY,
                    spice_level: $0.spiceLevel,
                    allergies: $0.allergies,
                    notes: $0.notes
                )
            },
            locale: "zh-CN"
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/menu/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        let decoded = try decoder.decode(MenuChatResponsePayload.self, from: data)
        return MenuChatResult(
            mode: MenuChatMode(rawValue: decoded.mode) ?? mode,
            reply: decoded.reply,
            recommendations: decoded.recommendations.map {
                MenuRecommendationItem(
                    name: $0.name,
                    originalName: $0.original_name,
                    reason: $0.reason,
                    matchScore: $0.match_score,
                    style: $0.style
                )
            },
            source: decoded.source
        )
    }

    private var baseURL: URL? {
        let raw = UserDefaults.standard.string(forKey: "readytoorder.setting.backendURL")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (raw?.isEmpty ?? true) ? "https://readytoorder-production.up.railway.app" : raw
        guard let value, let url = URL(string: value) else {
            return nil
        }
        return url
    }

    private func ensureSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown"
            throw NSError(domain: "TasteBackendClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func normalizedCategoryTags(_ payload: DeckResponsePayload.DishPayload.CategoryTagsPayload?) -> DishCategoryTags? {
        guard let payload else { return nil }

        let cuisine = payload.cuisine
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let flavor = payload.flavor
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let ingredient = payload.ingredient
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cuisine.isEmpty || !flavor.isEmpty || !ingredient.isEmpty else {
            return nil
        }
        return DishCategoryTags(cuisine: cuisine, flavor: flavor, ingredient: ingredient)
    }
}

private struct FeatureScorePayload: Codable {
    let id: String
    let score: Double
}

private struct DeckRequestPayload: Codable {
    let count: Int
    let feature_scores: [String: Double]
    let top_positive: [FeatureScorePayload]
    let top_negative: [FeatureScorePayload]
    let recent_likes: [String]
    let avoid_names: [String]
    let locale: String
}

private struct DeckResponsePayload: Decodable {
    struct DishPayload: Decodable {
        struct CategoryTagsPayload: Decodable {
            let cuisine: [String]
            let flavor: [String]
            let ingredient: [String]

            private enum CodingKeys: String, CodingKey {
                case cuisine
                case flavor
                case ingredient
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                cuisine = try container.decodeIfPresent([String].self, forKey: .cuisine) ?? []
                flavor = try container.decodeIfPresent([String].self, forKey: .flavor) ?? []
                ingredient = try container.decodeIfPresent([String].self, forKey: .ingredient) ?? []
            }
        }

        let name: String
        let subtitle: String
        let signals: [String: Double]
        let category_tags: CategoryTagsPayload?
        let image_data_url: String?
    }

    let dishes: [DishPayload]
    let source: String
}

private struct AnalyzeRequestPayload: Codable {
    struct RecentEventPayload: Codable {
        let dish_name: String
        let action: String
        let features: [String]
    }

    let total_swipes: Int
    let top_positive: [FeatureScorePayload]
    let top_negative: [FeatureScorePayload]
    let recent_events: [RecentEventPayload]
}

private struct MenuChatRequestPayload: Codable {
    struct ImagePayload: Codable {
        let mime_type: String
        let data_base64: String
    }

    struct TurnPayload: Codable {
        let role: String
        let text: String
    }

    struct ParamsPayload: Codable {
        let diners: Int?
        let budget_cny: Int?
        let spice_level: String
        let allergies: [String]
        let notes: String
    }

    let mode: String
    let message: String
    let images: [ImagePayload]
    let chat_history: [TurnPayload]
    let total_swipes: Int
    let top_positive: [FeatureScorePayload]
    let top_negative: [FeatureScorePayload]
    let recent_likes: [String]
    let params: ParamsPayload?
    let locale: String
}

private struct MenuChatResponsePayload: Decodable {
    struct RecommendationPayload: Decodable {
        let name: String
        let original_name: String
        let reason: String
        let match_score: Int
        let style: String
    }

    let mode: String
    let reply: String
    let recommendations: [RecommendationPayload]
    let source: String
}
