import Foundation
import Observation

struct AppleSignInPayload: Equatable {
    let userID: String
    let identityToken: String?
    let authorizationCode: String?
    let email: String?
    let displayName: String?
}

struct AccountUser: Codable, Equatable {
    let id: String
    let appleUserID: String
    let sessionToken: String
    let displayName: String?
    let email: String?
    let signedInAt: Date
}

private struct StoredAccountSession: Codable {
    let user: AccountUser
}

@MainActor
@Observable
final class AppSession {
    private enum StorageKeys {
        static let localSession = "readytoorder.auth.localSession"
    }

    private(set) var currentUser: AccountUser?
    private(set) var isAuthorizing = false
    private(set) var lastErrorMessage: String?
    private(set) var pendingApplePayload: AppleSignInPayload?

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        restore()
    }

    var isSignedIn: Bool {
        guard let currentUser else { return false }
        return !currentUser.sessionToken.isEmpty
    }

    var displayName: String {
        currentUser?.displayName?.trimmedNonEmpty ?? "Apple 用户"
    }

    var emailAddress: String? {
        currentUser?.email?.trimmedNonEmpty
    }

    var heroTitle: String {
        isSignedIn ? displayName : "未登录"
    }

    var heroSubtitle: String {
        if let emailAddress {
            return emailAddress
        }
        if isSignedIn {
            return "Apple 账号已连接，当前设备会使用后端会话同步你的口味画像。"
        }
        return "登录后可在新设备上恢复你的口味画像与历史偏好。"
    }

    var syncStatusText: String {
        if isAuthorizing {
            return "正在连接账号并换取服务端会话。"
        }
        if isSignedIn {
            return "已连接账号，口味画像会开始和云端同步。"
        }
        return "登录后会同步口味画像、分析结果和历史偏好，不上传聊天全文和菜单图片。"
    }

    func beginAppleAuthorization() {
        isAuthorizing = true
        lastErrorMessage = nil
    }

    func cancelAuthorization() {
        isAuthorizing = false
        pendingApplePayload = nil
    }

    func completeAppleSignIn(with payload: AppleSignInPayload) async {
        isAuthorizing = true
        lastErrorMessage = nil
        pendingApplePayload = payload

        do {
            let authSession = try await TasteBackendClient.shared.signInWithApple(payload)
            let mergedUser = AccountUser(
                id: authSession.user.id,
                appleUserID: authSession.user.apple_user_id,
                sessionToken: authSession.session_token,
                displayName: authSession.user.display_name?.trimmedNonEmpty ?? payload.displayName?.trimmedNonEmpty,
                email: authSession.user.email?.trimmedNonEmpty ?? payload.email?.trimmedNonEmpty,
                signedInAt: Date()
            )

            currentUser = mergedUser
            pendingApplePayload = nil
            isAuthorizing = false
            lastErrorMessage = nil
            persist()
        } catch {
            isAuthorizing = false
            currentUser = nil
            pendingApplePayload = nil
            lastErrorMessage = normalizedMessage(for: error)
        }
    }

    func completeLocalAppleSignIn(with payload: AppleSignInPayload) {
        let mergedUser = AccountUser(
            id: currentUser?.id ?? "",
            appleUserID: payload.userID,
            sessionToken: currentUser?.sessionToken ?? "",
            displayName: payload.displayName?.trimmedNonEmpty ?? currentUser?.displayName?.trimmedNonEmpty,
            email: payload.email?.trimmedNonEmpty ?? currentUser?.email?.trimmedNonEmpty,
            signedInAt: Date()
        )

        currentUser = mergedUser
        pendingApplePayload = payload
        isAuthorizing = false
        lastErrorMessage = nil
        persist()
    }

    func failAuthorization(with error: Error) {
        isAuthorizing = false
        pendingApplePayload = nil
        lastErrorMessage = normalizedMessage(for: error)
    }

    func dismissError() {
        lastErrorMessage = nil
    }

    func signOut() {
        isAuthorizing = false
        currentUser = nil
        pendingApplePayload = nil
        lastErrorMessage = nil
        TasteBackendClient.shared.clearSession()
        defaults.removeObject(forKey: StorageKeys.localSession)
    }

    private func restore() {
        guard let data = defaults.data(forKey: StorageKeys.localSession),
              let stored = try? decoder.decode(StoredAccountSession.self, from: data) else {
            return
        }
        currentUser = stored.user
    }

    private func persist() {
        guard let currentUser else {
            defaults.removeObject(forKey: StorageKeys.localSession)
            return
        }

        let stored = StoredAccountSession(user: currentUser)
        guard let data = try? encoder.encode(stored) else { return }
        defaults.set(data, forKey: StorageKeys.localSession)
    }

    private func normalizedMessage(for error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Apple 登录没有成功完成，请再试一次。" : message
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
