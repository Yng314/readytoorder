//
//  ContentView.swift
//  readytoorder
//
//  Created by Young on 2026/2/19.
//

import SwiftUI
import Photos
import PhotosUI
import UIKit
import Combine

private enum BottomBarLayout {
    static let collapsedCornerRadius: CGFloat = 30
    static let orderingCornerRadius: CGFloat = 26
    static let expandedContentInset: CGFloat = 12
}

enum AppTab: CaseIterable, Hashable {
    case tasteLearning
    case ordering
    case settings

    var title: String {
        switch self {
        case .tasteLearning:
            return "口味学习"
        case .ordering:
            return "点菜"
        case .settings:
            return "设置"
        }
    }

    var icon: String {
        switch self {
        case .tasteLearning:
            return "heart.text.square"
        case .ordering:
            return "fork.knife"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .tasteLearning
    @StateObject private var orderingViewModel = OrderingChatViewModel()
    @State private var isAttachmentDrawerPresented = false
    @StateObject private var recentPhotosModel = OrderingRecentPhotosModel()
    @State private var isShowingDrawerCamera = false
    @State private var isShowingDrawerCameraUnavailableAlert = false
    @State private var drawerPhotoPickerItems: [PhotosPickerItem] = []
    @State private var isShowingDrawerPhotoPicker = false

    private var composerLineCount: Int {
        let normalized = orderingViewModel.draftText.replacingOccurrences(of: "\r\n", with: "\n")
        guard !normalized.isEmpty else { return 1 }

        let explicitLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).count
        let wrappedApproxLines = Int(ceil(Double(normalized.count) / 20.0))
        return min(4, max(1, max(explicitLines, wrappedApproxLines)))
    }

    private var composerExtraHeight: CGFloat {
        CGFloat(max(0, composerLineCount - 1) * 18)
    }

    private var orderingExpandedHeight: CGFloat {
        let baseHeight: CGFloat = orderingViewModel.attachments.isEmpty ? 84.0 : 176.0
        return baseHeight + composerExtraHeight
    }

    private var orderingBarCornerRadius: CGFloat {
        selectedTab == .ordering ? BottomBarLayout.orderingCornerRadius : BottomBarLayout.collapsedCornerRadius
    }

    private var orderingChatBottomInset: CGFloat {
        // Keep the latest chat bubble above the whole morphing bottom bar.
        orderingExpandedHeight + 74
    }

    private func openDrawerCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingDrawerCamera = true
        } else {
            isShowingDrawerCameraUnavailableAlert = true
        }
    }

    private func addRecentPhoto(_ tile: OrderingRecentPhotoTile) {
        guard orderingViewModel.remainingAttachmentSlots > 0 else { return }
        Task {
            guard let data = await recentPhotosModel.loadImageData(for: tile.asset) else { return }
            await MainActor.run {
                orderingViewModel.ingestPhotoLibraryData(data)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    isAttachmentDrawerPresented = false
                }
            }
        }
    }

    private func openAllPhotosPicker() {
        isShowingDrawerPhotoPicker = true
    }

    var body: some View {
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

            TasteLearningView()
                .opacity(selectedTab == .tasteLearning ? 1 : 0)
                .allowsHitTesting(selectedTab == .tasteLearning)
                .zIndex(selectedTab == .tasteLearning ? 1 : 0)
                .animation(nil, value: selectedTab)

            OrderingChatView(
                selectedTab: $selectedTab,
                viewModel: orderingViewModel,
                composerReservedBottomInset: orderingChatBottomInset
            )
                .opacity(selectedTab == .ordering ? 1 : 0)
                .allowsHitTesting(selectedTab == .ordering)
                .zIndex(selectedTab == .ordering ? 1 : 0)
                .animation(nil, value: selectedTab)

            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
                .zIndex(selectedTab == .settings ? 1 : 0)
                .animation(nil, value: selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomMorphingTabBar(
                selectedTab: $selectedTab,
                expandedMaxHeight: orderingExpandedHeight,
                collapsedCornerRadius: BottomBarLayout.collapsedCornerRadius,
                expandedCornerRadius: BottomBarLayout.orderingCornerRadius,
                expandedContentInset: BottomBarLayout.expandedContentInset
            ) {
                OrderingComposerPanel(
                    viewModel: orderingViewModel,
                    outerContainerCornerRadius: orderingBarCornerRadius,
                    contentInsetFromOuterCard: BottomBarLayout.expandedContentInset,
                    isAttachmentDrawerPresented: $isAttachmentDrawerPresented
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .overlay {
            if selectedTab == .ordering {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(isAttachmentDrawerPresented ? 0.01 : 0.0)
                        .ignoresSafeArea()
                        .allowsHitTesting(isAttachmentDrawerPresented)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                isAttachmentDrawerPresented = false
                            }
                        }

                    OrderingAttachmentDrawerCard(
                        tiles: recentPhotosModel.tiles,
                        isLoading: recentPhotosModel.isLoading,
                        canAddMore: orderingViewModel.remainingAttachmentSlots > 0,
                        onTapCamera: openDrawerCamera,
                        onTapRecentPhoto: addRecentPhoto,
                        onTapAllPhotos: openAllPhotosPicker
                    )
                        .offset(y: isAttachmentDrawerPresented ? 0 : 340)
                        .opacity(isAttachmentDrawerPresented ? 1.0 : 0.001)
                        .allowsHitTesting(isAttachmentDrawerPresented)
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(40)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isAttachmentDrawerPresented)
            }
        }
        .sheet(isPresented: $isShowingDrawerCamera) {
            OrderingDrawerCameraCaptureSheet { image in
                orderingViewModel.ingestCameraImage(image)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    isAttachmentDrawerPresented = false
                }
            }
            .ignoresSafeArea()
        }
        .alert("当前设备不支持拍照", isPresented: $isShowingDrawerCameraUnavailableAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请改用相册上传菜单图片。")
        }
        .photosPicker(
            isPresented: $isShowingDrawerPhotoPicker,
            selection: $drawerPhotoPickerItems,
            maxSelectionCount: max(1, orderingViewModel.remainingAttachmentSlots),
            matching: .images
        )
        .onChange(of: drawerPhotoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await orderingViewModel.ingestPhotoPickerItems(newItems)
                await MainActor.run {
                    drawerPhotoPickerItems = []
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        isAttachmentDrawerPresented = false
                    }
                }
            }
        }
        .onChange(of: isAttachmentDrawerPresented) { _, isPresented in
            guard selectedTab == .ordering else { return }
            if isPresented {
                Task {
                    await recentPhotosModel.loadRecentTiles(limit: 18)
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            isAttachmentDrawerPresented = false
        }
        .preferredColorScheme(.light)
    }
}

private struct OrderingAttachmentDrawerCard: View {
    let tiles: [OrderingRecentPhotoTile]
    let isLoading: Bool
    let canAddMore: Bool
    let onTapCamera: () -> Void
    let onTapRecentPhoto: (OrderingRecentPhotoTile) -> Void
    let onTapAllPhotos: () -> Void

    private let squareSize: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.70))
                    .frame(width: 48, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            HStack(spacing: 10) {
                Text("添加菜单图片")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))

                Spacer()

                Button("全部照片") {
                    onTapAllPhotos()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.blue)
                .disabled(!canAddMore)
            }
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    cameraTile

                    if isLoading && tiles.isEmpty {
                        loadingTile
                    } else {
                        ForEach(tiles) { tile in
                            Button {
                                onTapRecentPhoto(tile)
                            } label: {
                                Image(uiImage: tile.thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: squareSize, height: squareSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(.white.opacity(0.72), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddMore)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 200, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28),
                style: .continuous
            )
            .fill(.ultraThinMaterial)
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28),
                style: .continuous
            )
            .stroke(.white.opacity(0.76), lineWidth: 1)
        )
    }

    private var cameraTile: some View {
        Button(action: onTapCamera) {
            VStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("拍照")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
            .frame(width: squareSize, height: squareSize)
            .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var loadingTile: some View {
        VStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("读取中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: squareSize, height: squareSize)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.76), lineWidth: 1)
        )
    }
}

private struct OrderingRecentPhotoTile: Identifiable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage
}

@MainActor
private final class OrderingRecentPhotosModel: ObservableObject {
    @Published private(set) var tiles: [OrderingRecentPhotoTile] = []
    @Published private(set) var isLoading = false

    private let imageManager = PHCachingImageManager()
    private let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    func loadRecentTiles(limit: Int) async {
        if isRunningInPreview {
            tiles = []
            return
        }

        let status = await resolveAuthorizationStatus()
        guard status == .authorized || status == .limited else {
            tiles = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        let assets = fetchRecentAssets(limit: limit)
        var loaded: [OrderingRecentPhotoTile] = []
        loaded.reserveCapacity(assets.count)

        for asset in assets {
            if let thumbnail = await requestThumbnail(for: asset, targetSize: CGSize(width: 220, height: 220)) {
                loaded.append(OrderingRecentPhotoTile(id: asset.localIdentifier, asset: asset, thumbnail: thumbnail))
            }
        }
        tiles = loaded
    }

    func loadImageData(for asset: PHAsset) async -> Data? {
        if isRunningInPreview {
            return nil
        }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func resolveAuthorizationStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current != .notDetermined {
            return current
        }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func fetchRecentAssets(limit: Int) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = max(1, limit)

        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

private struct OrderingDrawerCameraCaptureSheet: UIViewControllerRepresentable {
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
        private let parent: OrderingDrawerCameraCaptureSheet

        init(parent: OrderingDrawerCameraCaptureSheet) {
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

struct BottomMorphingTabBar<ExpandedContent: View>: View {
    @Binding var selectedTab: AppTab
    let expandedMaxHeight: CGFloat
    let collapsedCornerRadius: CGFloat
    let expandedCornerRadius: CGFloat
    let expandedContentInset: CGFloat
    @ViewBuilder var expandedContent: () -> ExpandedContent

    private var expandProgress: CGFloat {
        selectedTab == .ordering ? 1.0 : 0.0
    }

    private var containerRadius: CGFloat {
        collapsedCornerRadius - ((collapsedCornerRadius - expandedCornerRadius) * expandProgress)
    }

    private var visibleExpandedHeight: CGFloat {
        expandedMaxHeight * expandProgress
    }

    var body: some View {
        VStack(spacing: 0) {
            expandedContent()
                .padding(.horizontal, expandedContentInset)
                .padding(.top, expandedContentInset)
                .padding(.bottom, expandedContentInset)
                .frame(height: visibleExpandedHeight, alignment: .top)
                .opacity(expandProgress)
                .clipped()
                .allowsHitTesting(selectedTab == .ordering)

            BottomPillTabBar(selectedTab: $selectedTab, style: .embedded)
        }
        .background(
            RoundedRectangle(cornerRadius: containerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: containerRadius, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.22), value: selectedTab == .ordering)
        .animation(.easeInOut(duration: 0.16), value: expandedMaxHeight)
    }
}

struct BottomPillTabBar: View {
    enum Style {
        case embedded
    }

    @Binding var selectedTab: AppTab
    var style: Style = .embedded
    @Namespace private var tabHighlightNamespace

    var body: some View {
        let row = HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.subheadline.weight(.semibold))
                        Text(tab.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    .background {
                        if selectedTab == tab {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.62))
                                .matchedGeometryEffect(id: "tab-highlight", in: tabHighlightNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }

        switch style {
        case .embedded:
            row
                .padding(7)
        }
    }
}

private struct SettingsView: View {
    @AppStorage("readytoorder.setting.haptics") private var hapticsEnabled = true
    @AppStorage("readytoorder.setting.autoRefill") private var autoRefillEnabled = true
    @AppStorage("readytoorder.setting.backendURL") private var backendURL = "https://readytoorder-production.up.railway.app"

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

                VStack(spacing: 14) {
                    settingRow(title: "滑卡触感反馈", subtitle: "左右滑动时震动提示", isOn: $hapticsEnabled)
                    settingRow(title: "卡池自动补充", subtitle: "训练卡片低于阈值时自动生成", isOn: $autoRefillEnabled)
                    backendURLRow
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                )
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func settingRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(12)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backendURLRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gemini 后端 URL")
                .font(.subheadline.weight(.semibold))
            TextField("https://readytoorder-production.up.railway.app", text: $backendURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled(true)
                .font(.subheadline.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("默认使用 Railway 云端地址；本地调试时可改成局域网 IP。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ContentView()
}
