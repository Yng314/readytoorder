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
    @State private var isShowingParams = false
    @State private var isShowingClearChatConfirm = false

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
                }
            }
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
                VStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        OrderingMessageBubble(message: message)
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

    init(selectedTab: Binding<AppTab>, viewModel: OrderingChatViewModel) {
        _selectedTab = selectedTab
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }
}

struct OrderingComposerPanel: View {
    @ObservedObject var viewModel: OrderingChatViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingAttachmentSourcePicker = false
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

            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    isComposerFocused = false
                    isShowingAttachmentSourcePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.33, green: 0.22, blue: 0.52))
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.84, blue: 0.96),
                                    .white.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.90), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 0.63, green: 0.53, blue: 0.78).opacity(0.45), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending || viewModel.remainingAttachmentSlots <= 0)

                TextField("Ask anything...", text: $viewModel.draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isComposerFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(false)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .submitLabel(.send)
                    .onSubmit {
                        sendPrimaryAction()
                    }

                Button {
                    sendPrimaryAction()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.33, green: 0.22, blue: 0.52))
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.84, blue: 0.96),
                                    .white.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.90), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 0.63, green: 0.53, blue: 0.78).opacity(0.45), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!canSendNow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
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
        .confirmationDialog(
            "添加菜单图片",
            isPresented: $isShowingAttachmentSourcePicker,
            titleVisibility: .visible
        ) {
            Button("拍照") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    isShowingCamera = true
                } else {
                    isShowingCameraUnavailableAlert = true
                }
            }
            Button("从相册选择") {
                isShowingPhotoPicker = true
            }
            Button("取消", role: .cancel) {}
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
                            .frame(width: 84, height: 112)
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

    private let headlineColor = Color(red: 0.25, green: 0.22, blue: 0.30)
    private let bodyColor = Color(red: 0.30, green: 0.29, blue: 0.36)

    var body: some View {
        Group {
            if message.role == .user {
                userPromptBubble
            } else {
                assistantDigest
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userPromptBubble: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.58))
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.56, green: 0.60, blue: 0.74).opacity(0.95),
                                Color(red: 0.75, green: 0.73, blue: 0.84).opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 19, height: 19)
                    .blur(radius: 1.2)
            }
            .frame(width: 30, height: 30)

            Text(userPromptText)
                .font(.title3.weight(.medium))
                .foregroundStyle(headlineColor.opacity(0.98))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
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
            if !message.images.isEmpty || !message.recommendations.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("Created in seconds")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(bodyColor.opacity(0.52))

                recommendationVisualStrip
            }

            if !message.recommendations.isEmpty {
                Text("Quick concept starters\nfor your next shoot")
                    .font(.system(size: 47, weight: .bold, design: .rounded))
                    .foregroundStyle(headlineColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(assistantSummary)
                    .font(.body)
                    .foregroundStyle(bodyColor.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(message.recommendations.enumerated()), id: \.element.id) { index, item in
                        recommendationRow(index: index + 1, item: item)
                    }
                }
            } else if !message.trimmedText.isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(bodyColor.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.55), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 2)
    }

    private var recommendationVisualStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if !message.images.isEmpty {
                    ForEach(message.images) { image in
                        previewTile(for: image)
                    }
                } else {
                    ForEach(Array(message.recommendations.prefix(6).enumerated()), id: \.element.id) { index, item in
                        placeholderTile(for: item, index: index)
                    }
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

    private func placeholderTile(for item: MenuRecommendationItem, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("dish_placeholder")
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 180)
                .hueRotation(.degrees(Double(index) * 12))
                .saturation(0.80 + Double(index) * 0.05)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.48)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(item.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(10)
        }
        .frame(width: 180, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.52), lineWidth: 1)
        )
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

    private var assistantSummary: String {
        let trimmed = message.trimmedText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "结合你的口味画像和菜单内容，先给你一组可直接下单的建议。"
        }
        return String(trimmed.prefix(120))
    }
}

@MainActor
final class OrderingChatViewModel: ObservableObject {
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
                        images: []
                    )
                )
            } catch {
                let failure = "请求失败：\(error.localizedDescription)"
                messages.append(OrderingChatMessage(role: .assistant, text: failure, recommendations: [], images: []))
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
                    recommendations: message.recommendations
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
                images: []
            )
        }
        detailParams = snapshot.detailParams
        draftText = snapshot.draftText
        attachments = []
    }
}

private struct OrderingChatSnapshot: Codable {
    struct StoredMessage: Codable {
        let id: UUID
        let role: OrderingChatMessage.Role
        let text: String
        let recommendations: [MenuRecommendationItem]
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
        viewModel: OrderingChatViewModel()
    )
}
