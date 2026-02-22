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
    @StateObject private var viewModel = OrderingChatViewModel()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingParams = false
    @State private var isShowingCameraUnavailableAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.98, blue: 1.0),
                        Color(red: 0.98, green: 0.97, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let errorBanner = viewModel.errorBanner {
                        errorBannerView(errorBanner)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                    }

                    chatList
                    composerSection
                }
            }
            .navigationTitle("点菜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("详细参数") {
                        isShowingParams = true
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $isShowingParams) {
            OrderingDetailParamsSheet(params: $viewModel.detailParams)
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
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await viewModel.ingestPhotoPickerItems(newItems)
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
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

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        OrderingMessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在请求 Gemini...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.messages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: viewModel.isSending) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
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

    private var composerSection: some View {
        VStack(spacing: 10) {
            if !viewModel.attachments.isEmpty {
                attachmentStrip
            }

            HStack(spacing: 10) {
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        isShowingCamera = true
                    } else {
                        isShowingCameraUnavailableAlert = true
                    }
                } label: {
                    Image(systemName: "camera")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending || viewModel.remainingAttachmentSlots <= 0)

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: max(1, viewModel.remainingAttachmentSlots),
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(viewModel.isSending || viewModel.remainingAttachmentSlots <= 0)

                Text("已选 \(viewModel.attachments.count)/\(viewModel.maxImages) 张")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    viewModel.sendRecommend()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("推荐菜品")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.16, green: 0.54, blue: 0.36), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("问菜单细节，或上传图片后点“推荐菜品”", text: $viewModel.draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(false)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .submitLabel(.send)
                    .onSubmit {
                        viewModel.sendChat()
                    }

                Button {
                    viewModel.sendChat()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(red: 0.18, green: 0.36, blue: 0.82), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSending || viewModel.trimmedDraftText.isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.66))
                .frame(height: 1)
        }
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: attachment.previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.white.opacity(0.78), lineWidth: 1)
                            )

                        Button {
                            viewModel.removeAttachment(id: attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, Color.black.opacity(0.45))
                        }
                        .offset(x: 6, y: -6)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct OrderingMessageBubble: View {
    let message: OrderingChatMessage

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            }

            if !message.recommendations.isEmpty {
                VStack(spacing: 8) {
                    ForEach(message.recommendations) { recommendation in
                        OrderingRecommendationCard(item: recommendation)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Color(red: 0.20, green: 0.40, blue: 0.85))
        }
        return AnyShapeStyle(.white.opacity(0.82))
    }
}

private struct OrderingRecommendationCard: View {
    let item: MenuRecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !item.originalName.isEmpty {
                        Text(item.originalName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("匹配 \(item.matchScore)%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Text(item.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            ProgressView(value: min(100, max(0, Double(item.matchScore))), total: 100)
                .tint(.green)
        }
        .padding(12)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        )
    }
}

@MainActor
private final class OrderingChatViewModel: ObservableObject {
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
    private let snapshotKey = "readytoorder.ordering_chat_snapshot.v1"
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

        let historyPayload = buildHistoryPayload()
        let imagesPayload = attachments.map { MenuChatImageInput(mimeType: $0.mimeType, dataBase64: $0.dataBase64) }
        let paramsPayload = detailParams.toBackendInput()
        let tasteContext = buildTasteContext()

        messages.append(OrderingChatMessage(role: .user, text: messageText, recommendations: []))
        draftText = ""
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
                        recommendations: result.recommendations
                    )
                )
            } catch {
                let failure = "请求失败：\(error.localizedDescription)"
                messages.append(OrderingChatMessage(role: .assistant, text: failure, recommendations: []))
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

    private func trimMessagesIfNeeded() {
        guard messages.count > maxPersistedMessages else { return }
        messages = Array(messages.suffix(maxPersistedMessages))
    }

    private func persistSnapshot() {
        let snapshot = OrderingChatSnapshot(
            messages: messages,
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

        messages = snapshot.messages
        detailParams = snapshot.detailParams
        draftText = snapshot.draftText
        attachments = []
    }
}

private struct OrderingChatSnapshot: Codable {
    let messages: [OrderingChatMessage]
    let detailParams: OrderingDetailParams
    let draftText: String
}

private struct OrderingImageAttachment: Identifiable {
    let id: UUID
    let mimeType: String
    let dataBase64: String
    let previewImage: UIImage
}

private struct OrderingChatMessage: Identifiable, Codable {
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

    init(id: UUID = UUID(), role: Role, text: String, recommendations: [MenuRecommendationItem]) {
        self.id = id
        self.role = role
        self.text = text
        self.recommendations = recommendations
    }

    static let welcome = OrderingChatMessage(
        role: .assistant,
        text: "先上传菜单图片（最多 6 张），再点“推荐菜品”。你也可以直接问我某道菜的细节。",
        recommendations: []
    )

    var historyText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct OrderingDetailParams: Codable, Hashable {
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
                Section("人数与预算") {
                    TextField("用餐人数（可选）", text: $params.dinersText)
                        .keyboardType(.numberPad)
                    TextField("人均预算 CNY（可选）", text: $params.budgetText)
                        .keyboardType(.numberPad)
                }

                Section("辣度偏好") {
                    Picker("辣度", selection: $params.spiceLevel) {
                        Text("默认").tag("default")
                        Text("不辣").tag("none")
                        Text("微辣").tag("mild")
                        Text("中辣").tag("medium")
                        Text("重辣").tag("hot")
                    }
                }

                Section("过敏/忌口（可选）") {
                    TextField("用逗号分隔，例如：花生, 海鲜", text: $params.allergiesText, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("补充说明（可选）") {
                    TextField("例如：想吃清淡一点，尽量少油", text: $params.notes, axis: .vertical)
                        .lineLimit(2...5)
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
    OrderingChatView()
}
