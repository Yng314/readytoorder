import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @Environment(AppSession.self) private var appSession
    @Environment(AppAppearanceSettings.self) private var appAppearanceSettings

    @State private var presentedSheet: AccountSheet?
    @State private var isShowingSignOutConfirmation = false

    var body: some View {
        @Bindable var appAppearanceSettings = appAppearanceSettings

        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack(spacing: 18) {
                        AccountHeroCard(
                            appSession: appSession,
                            onPrepareAppleRequest: configureAppleRequest(_:),
                            onCompleteAppleSignIn: handleAppleSignInResult(_:),
                            onSignOut: { isShowingSignOutConfirmation = true }
                        )

                        AccountDataSection(appSession: appSession)
                        AccountAppearanceSection(appAppearanceSettings: appAppearanceSettings)
                        AccountSyncPreviewCard(appSession: appSession)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("我")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
#if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("后端连接") {
                            presentedSheet = .backendConfig
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("更多设置")
                    }
                }
#endif
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .backendConfig:
                BackendDebugSettingsSheet()
            }
        }
        .alert("Apple 登录失败", isPresented: isShowingErrorAlert) {
            Button("知道了", role: .cancel) {
                appSession.dismissError()
            }
        } message: {
            Text(appSession.lastErrorMessage ?? "请再试一次。")
        }
        .confirmationDialog("退出当前账号？", isPresented: $isShowingSignOutConfirmation, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                appSession.signOut()
            }
            Button("取消", role: .cancel) {}
        }
        .alert(item: $appAppearanceSettings.pendingUnavailableMode) { mode in
            Alert(
                title: Text(mode.title),
                message: Text("\(mode.title)还在开发中，当前版本会继续保持浅色模式。"),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    private var isShowingErrorAlert: Binding<Bool> {
        Binding(
            get: { appSession.lastErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    appSession.dismissError()
                }
            }
        )
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        appSession.beginAppleAuthorization()
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                appSession.failAuthorization(with: AccountAuthError.unsupportedCredential)
                return
            }
            let applePayload = payload(from: credential)
            Task {
                await appSession.completeAppleSignIn(with: applePayload)
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                appSession.cancelAuthorization()
                return
            }
            appSession.failAuthorization(with: error)
        }
    }

    private func payload(from credential: ASAuthorizationAppleIDCredential) -> AppleSignInPayload {
        let nameFormatter = PersonNameComponentsFormatter()
        let rawDisplayName = credential.fullName
            .map { nameFormatter.string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let displayName = rawDisplayName?.isEmpty == true ? nil : rawDisplayName

        return AppleSignInPayload(
            userID: credential.user,
            identityToken: stringValue(from: credential.identityToken),
            authorizationCode: stringValue(from: credential.authorizationCode),
            email: credential.email,
            displayName: displayName
        )
    }

    private func stringValue(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private enum AccountSheet: Identifiable {
    case backendConfig

    var id: String { "backendConfig" }
}

private struct AccountHeroCard: View {
    let appSession: AppSession
    let onPrepareAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompleteAppleSignIn: (Result<ASAuthorization, Error>) -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.68))
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.78), lineWidth: 1)
                    )

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color(red: 0.33, green: 0.36, blue: 0.44))
            }

            VStack(spacing: 6) {
                Text(appSession.heroTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(appSession.heroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if appSession.isSignedIn {
                VStack(spacing: 12) {
                    AccountStatusChip(
                        icon: "checkmark.seal.fill",
                        text: "Apple ID 已连接"
                    )

                    Button("退出登录", role: .destructive, action: onSignOut)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white.opacity(0.66))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.78), lineWidth: 1)
                        )
                }
            } else {
                ZStack {
                    SignInWithAppleButton(.continue, onRequest: onPrepareAppleRequest, onCompletion: onCompleteAppleSignIn)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(!appSession.isAuthorizing)
                        .opacity(appSession.isAuthorizing ? 0.55 : 1)

                    if appSession.isAuthorizing {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }

            Text(appSession.syncStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.74), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

private struct AccountDataSection: View {
    let appSession: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("数据与账号")
                .font(.headline.weight(.semibold))

            AccountInfoRow(
                icon: "person.badge.key",
                title: "账号体系",
                detail: appSession.isSignedIn
                    ? "当前 Apple 登录已经接到你的后端 session，后续请求会带上登录态。"
                    : "第一版将使用 Sign in with Apple 作为唯一登录方式。"
            )

            AccountInfoRow(
                icon: "arrow.triangle.2.circlepath.circle",
                title: "同步内容",
                detail: "会同步口味画像、分析结果和历史偏好；不会上传聊天全文和菜单图片。"
            )

            AccountInfoRow(
                icon: "lock.shield",
                title: "隐私边界",
                detail: "用户上传的菜单图仅用于当前推荐请求，不作为长期账号数据保存。"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.70), lineWidth: 1)
        )
    }
}

private struct AccountStatusChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color(red: 0.23, green: 0.34, blue: 0.23))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.16), in: Capsule())
    }
}

private struct AccountInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(red: 0.31, green: 0.41, blue: 0.63))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AccountSyncPreviewCard: View {
    let appSession: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appSession.isSignedIn ? "当前登录状态" : "后续账号能力")
                .font(.headline.weight(.semibold))

            Text(appSession.isSignedIn
                ? "这一步已经拿到 Apple 授权并完成服务端登录。接下来口味画像、分析结果和历史偏好会开始走云端同步。"
                : "下一步会接入真实服务端登录、已登录状态展示、登出入口，以及口味画像的云端同步。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                syncTag("口味画像")
                syncTag("分析结果")
                syncTag("历史偏好")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.50), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.68), lineWidth: 1)
        )
    }

    private func syncTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 0.27, green: 0.36, blue: 0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.72), in: Capsule())
    }
}

#Preview {
    AccountView()
        .environment(AppSession())
        .environment(AppAppearanceSettings())
}

private enum AccountAuthError: LocalizedError {
    case unsupportedCredential

    var errorDescription: String? {
        switch self {
        case .unsupportedCredential:
            return "没有拿到可用的 Apple 登录凭证，请再试一次。"
        }
    }
}
