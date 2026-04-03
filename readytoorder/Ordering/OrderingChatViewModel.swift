import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class OrderingChatViewModel {
    private static let menuChatDebugModeEnabled = false

    var draftText: String = ""
    var detailParams = OrderingDetailParams()
    private(set) var messages: [OrderingChatMessage] = []
    private(set) var attachments: [OrderingImageAttachment] = []
    private(set) var isSending = false
    var errorBanner: String?

    let maxImages = 6

    private let backendClient: TasteBackendClient
    private let tasteStore: TasteProfileStore
    private let defaults: UserDefaults
    private let snapshotKey = "readytoorder.ordering_chat_snapshot.v3"
    private let maxPersistedMessages = 120

    init(
        backendClient: TasteBackendClient,
        tasteStore: TasteProfileStore,
        defaults: UserDefaults
    ) {
        self.backendClient = backendClient
        self.tasteStore = tasteStore
        self.defaults = defaults
        restoreSnapshot()

        if messages.isEmpty {
            messages = [OrderingChatMessage.welcome]
            persistSnapshot()
        }
    }

    convenience init() {
        self.init(
            backendClient: .shared,
            tasteStore: TasteProfileStore(),
            defaults: .standard
        )
    }

    var trimmedDraftText: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var remainingAttachmentSlots: Int {
        max(0, maxImages - attachments.count)
    }

    func ingestPhotoPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        let available = remainingAttachmentSlots
        guard available > 0 else {
            errorBanner = "最多上传 \(maxImages) 张菜单图。"
            return
        }

        for item in items.prefix(available) {
            do {
                guard let rawData = try await item.loadTransferable(type: Data.self) else { continue }
                ingestRawImageData(rawData)
            } catch {
                errorBanner = "读取图片失败，请重试。"
            }
        }

        if items.count > available {
            errorBanner = "最多上传 \(maxImages) 张菜单图。"
        }
    }

    func ingestCameraImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            errorBanner = "相机图片读取失败。"
            return
        }
        ingestRawImageData(data)
    }

    func ingestPhotoLibraryData(_ data: Data) {
        ingestRawImageData(data)
    }

    func removeAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
        persistSnapshot()
    }

    func sendChat() {
        send(mode: .chat)
    }

    func sendRecommend() {
        send(mode: .recommend)
    }

    func clearConversation() {
        messages = [OrderingChatMessage.welcome]
        attachments = []
        draftText = ""
        errorBanner = nil
        persistSnapshot()
    }

    private func send(mode: MenuChatMode) {
        guard !isSending else { return }

        let text = trimmedDraftText
        if mode == .chat && text.isEmpty {
            return
        }
        if mode == .recommend && attachments.isEmpty {
            errorBanner = "请先上传菜单图片（最多 \(maxImages) 张）。"
            return
        }

        let messageText = text.isEmpty
            ? "请根据菜单图片推荐 5 道菜，包含 1 个保守备选和 1 个冒险尝试。"
            : text

        let outgoingAttachments = attachments
        let historyPayload = buildHistoryPayload()
        let imagesPayload = outgoingAttachments.map { MenuChatImageInput(mimeType: $0.mimeType, dataBase64: $0.dataBase64) }
        let messageImages = outgoingAttachments.compactMap(Self.makeMessageImage(from:))
        let paramsPayload = detailParams.toBackendInput()
        let tasteContext = buildTasteContext()

        messages.append(
            OrderingChatMessage(
                role: .user,
                text: messageText,
                recommendations: [],
                images: messageImages
            )
        )
        draftText = ""
        attachments = []
        errorBanner = nil

        if Self.menuChatDebugModeEnabled {
            let mock = Self.mockMenuTemplate(for: mode)
            messages.append(
                OrderingChatMessage(
                    role: .assistant,
                    text: mock.reply,
                    recommendations: mock.recommendations,
                    images: messageImages
                )
            )
            trimMessagesIfNeeded()
            persistSnapshot()
            return
        }

        isSending = true
        trimMessagesIfNeeded()
        persistSnapshot()

        Task {
            do {
                let result = try await backendClient.menuChat(
                    mode: mode,
                    message: messageText,
                    images: imagesPayload,
                    history: historyPayload,
                    tasteContext: tasteContext,
                    params: paramsPayload
                )

                messages.append(
                    OrderingChatMessage(
                        role: .assistant,
                        text: result.reply,
                        recommendations: result.recommendations,
                        images: messageImages
                    )
                )
            } catch {
                let failure = "请求失败：\(error.localizedDescription)"
                messages.append(
                    OrderingChatMessage(
                        role: .assistant,
                        text: failure,
                        recommendations: [],
                        images: messageImages
                    )
                )
                errorBanner = failure
            }

            trimMessagesIfNeeded()
            isSending = false
            persistSnapshot()
        }
    }

    private func buildHistoryPayload() -> [MenuChatTurnInput] {
        messages
            .suffix(16)
            .compactMap { message -> MenuChatTurnInput? in
                let text = message.historyText
                guard !text.isEmpty else { return nil }
                return MenuChatTurnInput(role: message.role.menuChatRole, text: text)
            }
    }

    private func buildTasteContext() -> MenuTasteContextInput {
        guard let snapshot = tasteStore.load() else {
            return MenuTasteContextInput(totalSwipes: 0, topPositive: [], topNegative: [], recentLikes: [])
        }

        let profile = snapshot.profile
        let positive = profile.insights(positive: true, limit: 8)
        let negative = profile.insights(positive: false, limit: 8)
        let recentLikes = snapshot.history
            .filter { $0.action == .like }
            .prefix(8)
            .map(\.dish.name)

        return MenuTasteContextInput(
            totalSwipes: profile.totalSwipes,
            topPositive: positive,
            topNegative: negative,
            recentLikes: recentLikes
        )
    }

    private func ingestRawImageData(_ rawData: Data) {
        guard remainingAttachmentSlots > 0 else {
            errorBanner = "最多上传 \(maxImages) 张菜单图。"
            return
        }
        guard let attachment = Self.prepareAttachment(from: rawData) else {
            errorBanner = "图片过大或格式不支持，请换一张试试。"
            return
        }
        guard !attachments.contains(where: { $0.dataBase64 == attachment.dataBase64 }) else { return }

        attachments.append(attachment)
        persistSnapshot()
    }

    private static func prepareAttachment(from rawData: Data) -> OrderingImageAttachment? {
        guard let original = UIImage(data: rawData) else { return nil }
        let resized = original.scaledDown(maxDimension: 1800)
        let maxBytes = 3_000_000

        let qualities: [CGFloat] = [0.88, 0.78, 0.68, 0.58, 0.48, 0.38]
        for quality in qualities {
            guard let jpeg = resized.jpegData(compressionQuality: quality) else { continue }
            guard jpeg.count <= maxBytes else { continue }
            let preview = UIImage(data: jpeg) ?? resized
            return OrderingImageAttachment(
                id: UUID(),
                mimeType: "image/jpeg",
                dataBase64: jpeg.base64EncodedString(),
                previewImage: preview
            )
        }

        return nil
    }

    private static func makeMessageImage(from attachment: OrderingImageAttachment) -> OrderingChatImage? {
        let thumbnail = attachment.previewImage.scaledDown(maxDimension: 500)
        return OrderingChatImage(id: UUID(), previewImage: thumbnail)
    }

    private static func mockMenuTemplate(for mode: MenuChatMode) -> (reply: String, recommendations: [MenuRecommendationItem]) {
        switch mode {
        case .chat:
            return (
                reply: "【调试模式】聊天接口已替换为固定回复。当前不调用 LLM，用于联调输入与消息流。",
                recommendations: []
            )
        case .recommend:
            let items = [
                MenuRecommendationItem(name: "宫保鸡丁", originalName: "", reason: "口味均衡，先作为保守备选。", matchScore: 86, style: "保守备选"),
                MenuRecommendationItem(name: "清炒时蔬", originalName: "", reason: "清淡解腻，和主菜搭配稳定。", matchScore: 82, style: "清爽搭配"),
                MenuRecommendationItem(name: "黑椒牛柳", originalName: "", reason: "香气和口感更突出，适合作为主力菜。", matchScore: 84, style: "均衡"),
                MenuRecommendationItem(name: "蒜蓉粉丝虾", originalName: "", reason: "鲜味明显，适合多人分食。", matchScore: 80, style: "分享菜"),
                MenuRecommendationItem(name: "麻辣水煮鱼", originalName: "", reason: "风味更激进，作为冒险尝试。", matchScore: 76, style: "冒险尝试")
            ]
            return (
                reply: "【调试模式】推荐接口已替换为固定模板。以下为 5 道固定示例菜品（含 1 个保守备选 + 1 个冒险尝试）。",
                recommendations: items
            )
        }
    }

    private static func makeStoredSnapshotImage(from image: OrderingChatImage) -> OrderingChatSnapshot.StoredImage? {
        let resized = image.previewImage.scaledDown(maxDimension: 320)
        guard let jpeg = resized.jpegData(compressionQuality: 0.68) else { return nil }
        return OrderingChatSnapshot.StoredImage(id: image.id, dataBase64: jpeg.base64EncodedString())
    }

    private static func makeSnapshotChatImage(from image: OrderingChatSnapshot.StoredImage) -> OrderingChatImage? {
        guard let raw = Data(base64Encoded: image.dataBase64),
              let preview = UIImage(data: raw) else {
            return nil
        }
        return OrderingChatImage(id: image.id, previewImage: preview)
    }

    private func trimMessagesIfNeeded() {
        guard messages.count > maxPersistedMessages else { return }
        messages = Array(messages.suffix(maxPersistedMessages))
    }

    private func persistSnapshot() {
        let snapshot = OrderingChatSnapshot(
            messages: messages.map { message in
                OrderingChatSnapshot.StoredMessage(
                    id: message.id,
                    role: message.role,
                    text: message.text,
                    recommendations: message.recommendations,
                    images: message.images.compactMap(Self.makeStoredSnapshotImage(from:))
                )
            },
            detailParams: detailParams,
            draftText: draftText
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    private func restoreSnapshot() {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(OrderingChatSnapshot.self, from: data) else {
            return
        }

        messages = snapshot.messages.map { item in
            OrderingChatMessage(
                id: item.id,
                role: item.role,
                text: item.text,
                recommendations: item.recommendations,
                images: item.images.compactMap(Self.makeSnapshotChatImage(from:))
            )
        }
        detailParams = snapshot.detailParams
        draftText = snapshot.draftText
        attachments = []
    }
}

private extension UIImage {
    func scaledDown(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
