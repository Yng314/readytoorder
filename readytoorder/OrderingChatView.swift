//
//  OrderingChatView.swift
//  readytoorder
//
//  Created by Codex on 2026/2/22.
//

import SwiftUI
import PhotosUI
import UIKit
import Combine

struct OrderingChatView: View {
    @Binding var selectedTab: AppTab
    @ObservedObject var viewModel: OrderingChatViewModel
    let composerReservedBottomInset: CGFloat
    @State private var isShowingParams = false
    @State private var isShowingClearChatConfirm = false
    @State private var previewImageItem: OrderingPreviewImageItem?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 185.0 / 255.0, green: 200.0 / 255.0, blue: 213.0 / 255.0),
                        Color(red: 184.0 / 255.0, green: 185.0 / 255.0, blue: 185.0 / 255.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topControlRow
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    if let errorBanner = viewModel.errorBanner {
                        errorBannerView(errorBanner)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                    }

                    chatList
                        .padding(.bottom, composerReservedBottomInset)
                }

                if let item = previewImageItem {
                    OrderingImagePreviewScreen(previewImage: item.previewImage) {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            previewImageItem = nil
                        }
                    }
                    .transition(.opacity)
                    .zIndex(30)
                }
            }
            .animation(.easeInOut(duration: 0.20), value: previewImageItem != nil)
            .toolbar(.hidden, for: .navigationBar)
        }
        .confirmationDialog(
            "确定清空当前对话？",
            isPresented: $isShowingClearChatConfirm,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) {
                viewModel.clearConversation()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会清空当前聊天内容与待发送图片。")
        }
        .sheet(isPresented: $isShowingParams) {
            OrderingDetailParamsSheet(params: $viewModel.detailParams)
        }
    }

    private func errorBannerView(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                viewModel.errorBanner = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        )
    }

    private var topControlRow: some View {
        HStack(spacing: 10) {
            Button {
                isShowingClearChatConfirm = true
            } label: {
                Label("清空", systemImage: "trash")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                    .background(.white.opacity(0.38), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSending)

            Spacer()

            Button {
                isShowingParams = true
            } label: {
                Label("详细参数", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                    .background(.white.opacity(0.38), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Keep a plain VStack here: LazyVStack regressed on-device with this chat's
                // update/scroll pattern and can freeze after recommend -> chat -> fast scroll.
                VStack(spacing: 18) {
                    ForEach(viewModel.messages) { message in
                        OrderingMessageBubble(message: message) { image in
                            withAnimation(.easeInOut(duration: 0.20)) {
                                previewImageItem = OrderingPreviewImageItem(previewImage: image.previewImage)
                            }
                        }
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color(red: 0.45, green: 0.45, blue: 0.55))
                            Text("Generating in progress...")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.messages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let target = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    init(
        selectedTab: Binding<AppTab>,
        viewModel: OrderingChatViewModel,
        composerReservedBottomInset: CGFloat
    ) {
        _selectedTab = selectedTab
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.composerReservedBottomInset = composerReservedBottomInset
    }
}

struct OrderingComposerPanel: View {
    @ObservedObject var viewModel: OrderingChatViewModel
    let outerContainerCornerRadius: CGFloat
    let contentInsetFromOuterCard: CGFloat
    @Binding var isAttachmentDrawerPresented: Bool
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingCameraUnavailableAlert = false
    @FocusState private var isComposerFocused: Bool

    private var hasAttachments: Bool {
        !viewModel.attachments.isEmpty
    }

    private var canSendNow: Bool {
        if hasAttachments {
            return !viewModel.isSending
        }
        return !viewModel.isSending && !viewModel.trimmedDraftText.isEmpty
    }

    private var inputCardCornerRadius: CGFloat {
        // Equal-offset geometry: keep corner tangents visually parallel to the outer card.
        max(10, outerContainerCornerRadius - contentInsetFromOuterCard)
    }

    private func sendPrimaryAction() {
        isComposerFocused = false
        if hasAttachments {
            viewModel.sendRecommend()
        } else {
            viewModel.sendChat()
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if !viewModel.attachments.isEmpty {
                attachmentStrip
            }

            HStack(alignment: .center, spacing: 10) {
                Button {
                    isComposerFocused = false
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        isAttachmentDrawerPresented.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.33, green: 0.22, blue: 0.52))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending || viewModel.remainingAttachmentSlots <= 0)

                TextField("发送菜单推荐菜品...", text: $viewModel.draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isComposerFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(false)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 16)
                    .submitLabel(.send)
                    .onSubmit {
                        sendPrimaryAction()
                    }

                Button {
                    sendPrimaryAction()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.33, green: 0.22, blue: 0.52))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(!canSendNow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: inputCardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: inputCardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.88), lineWidth: 1)
            )
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await viewModel.ingestPhotoPickerItems(newItems)
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureSheet { image in
                viewModel.ingestCameraImage(image)
            }
            .ignoresSafeArea()
        }
        .alert("当前设备不支持拍照", isPresented: $isShowingCameraUnavailableAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请改用相册上传菜单图片。")
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: max(1, viewModel.remainingAttachmentSlots),
            matching: .images
        )
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: attachment.previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white.opacity(0.72), lineWidth: 1)
                            )

                        Button {
                            viewModel.removeAttachment(id: attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 19))
                                .foregroundStyle(.white, Color.black.opacity(0.45))
                        }
                        .offset(x: 7, y: -7)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 2)
    }
}

private struct OrderingMessageBubble: View {
    let message: OrderingChatMessage
    var onTapImage: (OrderingChatImage) -> Void = { _ in }

    private let headlineColor = Color(red: 0.25, green: 0.22, blue: 0.30)
    private let bodyColor = Color(red: 0.30, green: 0.29, blue: 0.36)

    var body: some View {
        Group {
            if message.role == .user {
                if shouldHideAutoRecommendPromptBubble {
                    EmptyView()
                } else {
                    userPromptBubble
                }
            } else {
                assistantDigest
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var userPromptBubble: some View {
        Text(userPromptText)
            .font(.title3.weight(.medium))
            .foregroundStyle(headlineColor.opacity(0.98))
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.44), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.56), lineWidth: 1)
        )
    }

    private var assistantDigest: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !message.images.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("菜单缩略图")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(bodyColor.opacity(0.52))

                recommendationVisualStrip
            }

            if !message.recommendations.isEmpty {
                Text(recommendationIntroText)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(headlineColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(message.recommendations.enumerated()), id: \.element.id) { index, item in
                        recommendationRow(index: index + 1, item: item)
                    }
                }
            } else if !message.trimmedText.isEmpty {
                if message.isIntroGuideText {
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(bodyColor.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(bodyColor.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var recommendationVisualStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(message.images) { image in
                    previewTile(for: image)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func recommendationRow(index: Int, item: MenuRecommendationItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index).")
                .font(.title3.weight(.bold))
                .foregroundStyle(headlineColor)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(headlineColor)
                        .lineLimit(2)
                    if !item.originalName.isEmpty {
                        Text(item.originalName)
                            .font(.caption)
                            .foregroundStyle(bodyColor.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Text(item.reason)
                    .font(.body)
                    .foregroundStyle(bodyColor.opacity(0.93))
                    .fixedSize(horizontal: false, vertical: true)

                Text("匹配度 \(item.matchScore)%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.45, green: 0.49, blue: 0.60).opacity(0.68))
                    )
            }
        }
    }

    private func previewTile(for image: OrderingChatImage) -> some View {
        Button {
            onTapImage(image)
        } label: {
            Image(uiImage: image.previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.52), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var userPromptText: String {
        if !message.trimmedText.isEmpty {
            return message.text
        }
        if !message.images.isEmpty {
            return "请根据我上传的菜单图片来推荐。"
        }
        return "继续这个点菜话题。"
    }

    private var shouldHideAutoRecommendPromptBubble: Bool {
        message.role == .user &&
        !message.images.isEmpty &&
        message.recommendations.isEmpty &&
        message.trimmedText.hasPrefix("请根据菜单图片推荐")
    }

    private var recommendationIntroText: String {
        let trimmed = message.trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "结合你的口味画像和菜单内容，先给你一组可直接下单的建议。"
        }
        return message.text
    }
}

private struct OrderingPreviewImageItem: Identifiable {
    let id = UUID()
    let previewImage: UIImage
}

private struct OrderingImagePreviewScreen: View {
    let previewImage: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(Color.white.opacity(0.10).ignoresSafeArea())

            Image(uiImage: previewImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 24)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primary.opacity(0.88))
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .onTapGesture {
            onClose()
        }
    }
}

@MainActor
final class OrderingChatViewModel: ObservableObject {
    // Temporary debug switch: bypass menu LLM and return fixed templates.
    private static let menuChatDebugModeEnabled = false

    @Published var draftText: String = ""
    @Published var detailParams = OrderingDetailParams()
    @Published private(set) var messages: [OrderingChatMessage] = []
    @Published private(set) var attachments: [OrderingImageAttachment] = []
    @Published private(set) var isSending = false
    @Published var errorBanner: String?

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

        let messageText: String
        if text.isEmpty {
            messageText = "请根据菜单图片推荐 5 道菜，包含 1 个保守备选和 1 个冒险尝试。"
        } else {
            messageText = text
        }

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
                messages.append(OrderingChatMessage(role: .assistant, text: failure, recommendations: [], images: messageImages))
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
        return OrderingChatImage(
            id: UUID(),
            previewImage: thumbnail
        )
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
        return OrderingChatSnapshot.StoredImage(
            id: image.id,
            dataBase64: jpeg.base64EncodedString()
        )
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

private struct OrderingChatSnapshot: Codable {
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

private struct OrderingDetailParamsSheet: View {
    @Binding var params: OrderingDetailParams
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("用餐人数（可选）", text: $params.dinersText)
                        .keyboardType(.numberPad)
                    TextField("人均预算 CNY（可选）", text: $params.budgetText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("人数与预算")
                } footer: {
                    Text("默认：人数不限制，预算不限。")
                }

                Section {
                    Picker("辣度", selection: $params.spiceLevel) {
                        Text("默认").tag("default")
                        Text("不辣").tag("none")
                        Text("微辣").tag("mild")
                        Text("中辣").tag("medium")
                        Text("重辣").tag("hot")
                    }
                } header: {
                    Text("辣度偏好")
                } footer: {
                    Text("默认：跟随你的口味画像与菜单信息自动判断。")
                }

                Section {
                    TextField("用逗号分隔，例如：花生, 海鲜", text: $params.allergiesText, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("过敏/忌口（可选）")
                } footer: {
                    Text("默认：无过敏/忌口限制。")
                }

                Section {
                    TextField("例如：想吃清淡一点，尽量少油", text: $params.notes, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("补充说明（可选）")
                } footer: {
                    Text("默认：无额外偏好说明。")
                }
            }
            .navigationTitle("详细参数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("恢复默认") {
                        params.reset()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CameraCaptureSheet: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureSheet

        init(parent: CameraCaptureSheet) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }
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

#Preview {
    OrderingChatView(
        selectedTab: .constant(.ordering),
        viewModel: OrderingChatViewModel(),
        composerReservedBottomInset: 180
    )
}
