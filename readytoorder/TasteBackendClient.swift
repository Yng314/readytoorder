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
    static let sessionTokenKey = "readytoorder.auth.sessionToken"
    static let deviceIDHeader = "X-Device-ID"
    static let clientVersionHeader = "X-Client-Version"
    static let apiKeyHeader = "X-API-Key"
    static let requestIDHeader = "X-Request-ID"
    static let authorizationHeader = "Authorization"
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

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct BackendAccountUser: Codable, Hashable {
    let id: String
    let apple_user_id: String
    let email: String?
    let display_name: String?
    let created_at: Date
    let last_login_at: Date
}

struct BackendAuthSession: Codable, Hashable {
    let session_token: String
    let user: BackendAccountUser
}

struct BackendSwipeEventPayload: Codable, Hashable {
    struct DishSnapshot: Codable, Hashable {
        let name: String
        let subtitle: String
        let tags: DishTags
    }

    let id: String
    let dish_name: String
    let action: String
    let dish_snapshot_json: DishSnapshot
    let created_at: Date
}

struct BackendProfileSnapshot: Codable {
    let taste_profile_json: TasteProfile
    let analysis_json: TasteAnalysisResult?
    let preferences_json: [String: JSONValue]
    let swipe_events: [BackendSwipeEventPayload]
    let updated_at: Date
}

final class TasteBackendClient {
    static let shared = TasteBackendClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let defaults: UserDefaults

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    var isConfigured: Bool {
        baseURL != nil
    }

    var hasSessionToken: Bool {
        sessionToken != nil
    }

    func signInWithApple(_ payload: AppleSignInPayload) async throws -> BackendAuthSession {
        do {
            guard let baseURL else { throw URLError(.badURL) }
            guard let identityToken = payload.identityToken, !identityToken.isEmpty else {
                throw BackendAPIError(statusCode: 400, code: "missing_identity_token", message: "Apple identity token is missing.", requestID: nil)
            }
            let requestPayload = AppleSignInRequestPayload(
                identity_token: identityToken,
                authorization_code: payload.authorizationCode,
                email: payload.email,
                display_name: payload.displayName
            )

            var request = URLRequest(url: baseURL.appendingPathComponent("v1/auth/apple/sign-in"))
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            applyCommonHeaders(to: &request)
            request.httpBody = try encoder.encode(requestPayload)

            let (data, response) = try await session.data(for: request)
            try ensureSuccess(response: response, data: data)

            let authSession = try decoder.decode(BackendAuthSession.self, from: data)
            defaults.set(authSession.session_token, forKey: BackendClientConstants.sessionTokenKey)
            return authSession
        } catch {
            reportClientError(scope: "auth_sign_in", error: error)
            throw error
        }
    }

    func clearSession() {
        defaults.removeObject(forKey: BackendClientConstants.sessionTokenKey)
    }

    func fetchUserProfile() async throws -> BackendProfileSnapshot {
        do {
            guard let baseURL else { throw URLError(.badURL) }
            var request = URLRequest(url: baseURL.appendingPathComponent("v1/me/profile"))
            request.httpMethod = "GET"
            request.timeoutInterval = 60
            applyCommonHeaders(to: &request)

            let (data, response) = try await session.data(for: request)
            try ensureSuccess(response: response, data: data)
            return try decoder.decode(BackendProfileSnapshot.self, from: data)
        } catch {
            reportClientError(scope: "profile_fetch", error: error)
            throw error
        }
    }

    func updateUserProfile(snapshot: TasteTrainingSnapshot) async throws {
        do {
            guard let baseURL else { throw URLError(.badURL) }
            let payload = ProfileUpdatePayload(
                taste_profile_json: snapshot.profile,
                analysis_json: snapshot.latestAnalysis,
                preferences_json: [:]
            )

            var request = URLRequest(url: baseURL.appendingPathComponent("v1/me/profile"))
            request.httpMethod = "PUT"
            request.timeoutInterval = 60
            applyCommonHeaders(to: &request)
            request.httpBody = try encoder.encode(payload)

            let (data, response) = try await session.data(for: request)
            try ensureSuccess(response: response, data: data)
            _ = try decoder.decode(BackendProfileSnapshot.self, from: data)
        } catch {
            reportClientError(scope: "profile_update", error: error)
            throw error
        }
    }

    func uploadSwipeEvents(_ history: [SwipeEvent]) async throws {
        do {
            guard let baseURL else { throw URLError(.badURL) }
            let payload = SwipeBatchUploadPayload(
                events: history.map {
                    SwipeEventUploadPayload(
                        id: $0.id.uuidString.lowercased(),
                        dish_name: $0.dish.name,
                        action: $0.action.rawValue,
                        dish_snapshot_json: BackendSwipeEventPayload.DishSnapshot(
                            name: $0.dish.name,
                            subtitle: $0.dish.subtitle,
                            tags: $0.dish.tags
                        ),
                        created_at: $0.createdAt
                    )
                }
            )

            var request = URLRequest(url: baseURL.appendingPathComponent("v1/me/swipes/batch"))
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            applyCommonHeaders(to: &request)
            request.httpBody = try encoder.encode(payload)

            let (data, response) = try await session.data(for: request)
            try ensureSuccess(response: response, data: data)
            _ = try decoder.decode(SwipeBatchUploadResponse.self, from: data)
        } catch {
            reportClientError(scope: "swipe_upload", error: error)
            throw error
        }
    }

    func syncTasteSnapshot(_ snapshot: TasteTrainingSnapshot) async throws {
        try await updateUserProfile(snapshot: snapshot)
        try await uploadSwipeEvents(snapshot.history)
    }

    func hasRemoteProfileData(_ snapshot: BackendProfileSnapshot) -> Bool {
        snapshot.taste_profile_json.totalSwipes > 0
            || snapshot.analysis_json != nil
            || !snapshot.swipe_events.isEmpty
    }

    func localSnapshot(from remote: BackendProfileSnapshot) -> TasteTrainingSnapshot {
        let history = remote.swipe_events.map { event in
            SwipeEvent(
                id: UUID(uuidString: event.id) ?? UUID(),
                dish: DishCandidate(
                    name: event.dish_snapshot_json.name,
                    subtitle: event.dish_snapshot_json.subtitle,
                    tags: event.dish_snapshot_json.tags,
                    imageDataURL: nil
                ),
                action: SwipeAction(rawValue: event.action) ?? .neutral,
                createdAt: event.created_at
            )
        }

        return TasteTrainingSnapshot(
            profile: remote.taste_profile_json,
            deck: [],
            history: history,
            latestAnalysis: remote.analysis_json
        )
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
                top_positive: [],
                top_negative: [],
                recent_likes: [],
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
                let tags = normalizedTags(item.tags)
                guard !item.name.isEmpty, !tags.storageKeys.isEmpty else {
                    return nil
                }
                return DishCandidate(
                    name: item.name,
                    subtitle: item.subtitle,
                    tags: tags,
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
                top_positive: positive.map { .init(id: $0.tag.storageKey, score: $0.score) },
                top_negative: negative.map { .init(id: $0.tag.storageKey, score: $0.score) },
                recent_events: recentEvents.prefix(20).map {
                    AnalyzeRequestPayload.RecentEventPayload(
                        dish_name: $0.dish.name,
                        action: $0.action.rawValue,
                        features: Array($0.dish.tagStorageKeys.prefix(8))
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
                top_positive: tasteContext.topPositive.map { .init(id: $0.tag.storageKey, score: $0.score) },
                top_negative: tasteContext.topNegative.map { .init(id: $0.tag.storageKey, score: $0.score) },
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

    private var sessionToken: String? {
        let raw = defaults.string(forKey: BackendClientConstants.sessionTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
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
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: BackendClientConstants.authorizationHeader)
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

    func reportClientEvent(
        scope: String,
        code: String,
        message: String,
        statusCode: Int? = nil,
        requestID: String = ""
    ) {
        guard let baseURL else { return }

        let payload = BackendClientErrorEventPayload(
            scope: scope,
            code: code,
            message: message,
            status_code: statusCode,
            request_id: requestID
        )

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

    private func reportClientError(scope: String, error: Error) {
        let code: String
        let message: String
        let statusCode: Int?
        let requestID: String
        if let backendError = error as? BackendAPIError {
            code = backendError.code
            message = backendError.message
            statusCode = backendError.statusCode
            requestID = backendError.requestID ?? ""
        } else {
            code = "network_error"
            message = error.localizedDescription
            statusCode = nil
            requestID = ""
        }

        reportClientEvent(
            scope: scope,
            code: code,
            message: message,
            statusCode: statusCode,
            requestID: requestID
        )
    }

    private func normalizedTags(_ payload: DeckResponsePayload.DishPayload.TagsPayload?) -> DishTags {
        guard let payload else { return DishTags() }
        return DishTags(
            flavor: payload.flavor.map(normalizeTagKey),
            ingredient: payload.ingredient.map(normalizeTagKey),
            texture: payload.texture.map(normalizeTagKey),
            cookingMethod: payload.cooking_method.map(normalizeTagKey),
            cuisine: payload.cuisine.map(normalizeTagKey),
            course: payload.course.map(normalizeTagKey),
            allergen: payload.allergen.map(normalizeTagKey)
        )
    }

    private func normalizeTagKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
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
        struct TagsPayload: Decodable {
            let flavor: [String]
            let ingredient: [String]
            let texture: [String]
            let cooking_method: [String]
            let cuisine: [String]
            let course: [String]
            let allergen: [String]

            private enum CodingKeys: String, CodingKey {
                case flavor
                case ingredient
                case texture
                case cooking_method
                case cuisine
                case course
                case allergen
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                flavor = try container.decodeIfPresent([String].self, forKey: .flavor) ?? []
                ingredient = try container.decodeIfPresent([String].self, forKey: .ingredient) ?? []
                texture = try container.decodeIfPresent([String].self, forKey: .texture) ?? []
                cooking_method = try container.decodeIfPresent([String].self, forKey: .cooking_method) ?? []
                cuisine = try container.decodeIfPresent([String].self, forKey: .cuisine) ?? []
                course = try container.decodeIfPresent([String].self, forKey: .course) ?? []
                allergen = try container.decodeIfPresent([String].self, forKey: .allergen) ?? []
            }
        }

        let name: String
        let subtitle: String
        let tags: TagsPayload?
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

private struct AppleSignInRequestPayload: Codable {
    let identity_token: String
    let authorization_code: String?
    let email: String?
    let display_name: String?
}

private struct ProfileUpdatePayload: Codable {
    let taste_profile_json: TasteProfile
    let analysis_json: TasteAnalysisResult?
    let preferences_json: [String: JSONValue]
}

private struct SwipeEventUploadPayload: Codable {
    let id: String
    let dish_name: String
    let action: String
    let dish_snapshot_json: BackendSwipeEventPayload.DishSnapshot
    let created_at: Date
}

private struct SwipeBatchUploadPayload: Codable {
    let events: [SwipeEventUploadPayload]
}

private struct SwipeBatchUploadResponse: Codable {
    let inserted_count: Int
    let total_count: Int
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
