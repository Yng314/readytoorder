//
//  TasteBackendClient.swift
//  readytoorder
//
//  Created by Codex on 2026/2/19.
//

import Foundation

private enum BackendClientConstants {
    static let productionBaseURL = "https://readytoorder-production.up.railway.app"
    static let backendURLKey = "readytoorder.setting.backendURL"
    static let backendAPIKeyKey = "readytoorder.setting.backendApiKey"
    static let deviceIDKey = "readytoorder.device.id"
    static let deviceIDHeader = "X-Device-ID"
    static let clientVersionHeader = "X-Client-Version"
    static let apiKeyHeader = "X-API-Key"
    static let requestIDHeader = "X-Request-ID"
}

struct BackendAPIError: LocalizedError {
    let statusCode: Int
    let code: String
    let message: String
    let requestID: String?

    var errorDescription: String? {
        switch statusCode {
        case 429:
            return "请求过于频繁，请稍后重试。"
        case 502:
            return "服务暂时不可用，请稍后再试。"
        case 503:
            return "服务繁忙，请稍后再试。"
        default:
            return message
        }
    }
}

private struct BackendErrorEnvelope: Decodable {
    let code: String
    let message: String
    let request_id: String?
}

private struct BackendClientErrorEventPayload: Codable {
    let scope: String
    let code: String
    let message: String
    let status_code: Int?
    let request_id: String
}

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
    private let defaults: UserDefaults

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
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
        do {
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
            applyCommonHeaders(to: &request)
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
        } catch {
            reportClientError(scope: "taste_deck", error: error)
            throw error
        }
    }

    func analyzeTaste(
        totalSwipes: Int,
        positive: [TasteInsight],
        negative: [TasteInsight],
        recentEvents: [SwipeEvent]
    ) async throws -> TasteAnalysisResult {
        do {
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
            applyCommonHeaders(to: &request)
            request.httpBody = try encoder.encode(payload)

            let (data, response) = try await session.data(for: request)
            try ensureSuccess(response: response, data: data)

            return try decoder.decode(TasteAnalysisResult.self, from: data)
        } catch {
            reportClientError(scope: "taste_analyze", error: error)
            throw error
        }
    }

    func menuChat(
        mode: MenuChatMode,
        message: String,
        images: [MenuChatImageInput],
        history: [MenuChatTurnInput],
        tasteContext: MenuTasteContextInput,
        params: MenuChatDetailParamsInput?
    ) async throws -> MenuChatResult {
        do {
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
            applyCommonHeaders(to: &request)
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
        } catch {
            reportClientError(scope: "menu_chat", error: error)
            throw error
        }
    }

    private var baseURL: URL? {
        let value: String
#if DEBUG
        let raw = defaults.string(forKey: BackendClientConstants.backendURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        value = (raw?.isEmpty ?? true) ? BackendClientConstants.productionBaseURL : (raw ?? BackendClientConstants.productionBaseURL)
#else
        value = BackendClientConstants.productionBaseURL
#endif
        guard let url = URL(string: value) else {
            return nil
        }
        return url
    }

    private var backendAPIKey: String? {
#if DEBUG
        let raw = defaults.string(forKey: BackendClientConstants.backendAPIKeyKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
#else
        return nil
#endif
    }

    private var deviceID: String {
        if let existing = defaults.string(forKey: BackendClientConstants.deviceIDKey),
           UUID(uuidString: existing.lowercased()) != nil {
            return existing.lowercased()
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: BackendClientConstants.deviceIDKey)
        return generated
    }

    private var clientVersion: String {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return Self.semanticVersion(from: raw)
    }

    private static func semanticVersion(from raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "1.0.0"
        }
        let components = cleaned.split(separator: ".").map(String.init)
        if components.count >= 3 {
            return components.prefix(3).joined(separator: ".")
        }
        if components.count == 2 {
            return "\(components[0]).\(components[1]).0"
        }
        return "\(components[0]).0.0"
    }

    private func applyCommonHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceID, forHTTPHeaderField: BackendClientConstants.deviceIDHeader)
        request.setValue(clientVersion, forHTTPHeaderField: BackendClientConstants.clientVersionHeader)
        if let apiKey = backendAPIKey {
            request.setValue(apiKey, forHTTPHeaderField: BackendClientConstants.apiKeyHeader)
        }
    }

    private func ensureSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let headerRequestID = http.value(forHTTPHeaderField: BackendClientConstants.requestIDHeader)
            if let envelope = try? decoder.decode(BackendErrorEnvelope.self, from: data) {
                throw BackendAPIError(
                    statusCode: http.statusCode,
                    code: envelope.code,
                    message: envelope.message,
                    requestID: envelope.request_id ?? headerRequestID
                )
            }
            let fallbackMessage = String(data: data, encoding: .utf8) ?? "Request failed"
            throw BackendAPIError(
                statusCode: http.statusCode,
                code: "request_failed",
                message: fallbackMessage,
                requestID: headerRequestID
            )
        }
    }

    private func reportClientError(scope: String, error: Error) {
        guard let baseURL else { return }

        let payload: BackendClientErrorEventPayload
        if let backendError = error as? BackendAPIError {
            payload = BackendClientErrorEventPayload(
                scope: scope,
                code: backendError.code,
                message: backendError.message,
                status_code: backendError.statusCode,
                request_id: backendError.requestID ?? ""
            )
        } else {
            payload = BackendClientErrorEventPayload(
                scope: scope,
                code: "network_error",
                message: error.localizedDescription,
                status_code: nil,
                request_id: ""
            )
        }

        guard let data = try? encoder.encode(payload) else { return }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/client/error"))
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        applyCommonHeaders(to: &request)
        request.httpBody = data

        let session = self.session
        Task(priority: .background) {
            _ = try? await session.data(for: request)
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
