import Observation
import Photos
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class OrderingFeatureModel {
    let chatViewModel: OrderingChatViewModel
    let recentPhotosModel: OrderingRecentPhotosModel

    var isAttachmentDrawerPresented = false
    var isShowingDrawerCamera = false
    var isShowingDrawerCameraUnavailableAlert = false
    var drawerPhotoPickerItems: [PhotosPickerItem] = []
    var isShowingDrawerPhotoPicker = false

    init(
        chatViewModel: OrderingChatViewModel,
        recentPhotosModel: OrderingRecentPhotosModel
    ) {
        self.chatViewModel = chatViewModel
        self.recentPhotosModel = recentPhotosModel
    }

    convenience init() {
        self.init(
            chatViewModel: OrderingChatViewModel(),
            recentPhotosModel: OrderingRecentPhotosModel()
        )
    }

    func toggleAttachmentDrawer() {
        guard chatViewModel.remainingAttachmentSlots > 0 else { return }
        isAttachmentDrawerPresented.toggle()
    }

    func closeAttachmentDrawer() {
        isAttachmentDrawerPresented = false
    }

    func openDrawerCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingDrawerCamera = true
        } else {
            isShowingDrawerCameraUnavailableAlert = true
        }
    }

    func ingestDrawerCameraImage(_ image: UIImage) {
        chatViewModel.ingestCameraImage(image)
        closeAttachmentDrawer()
    }

    func addRecentPhoto(_ tile: OrderingRecentPhotoTile) async {
        guard chatViewModel.remainingAttachmentSlots > 0 else { return }
        guard let data = await recentPhotosModel.loadImageData(for: tile.asset) else { return }
        chatViewModel.ingestPhotoLibraryData(data)
        closeAttachmentDrawer()
    }

    func openAllPhotosPicker() {
        isShowingDrawerPhotoPicker = true
    }

    func handleDrawerPhotoPickerSelectionChange() async {
        guard !drawerPhotoPickerItems.isEmpty else { return }
        let items = drawerPhotoPickerItems
        await chatViewModel.ingestPhotoPickerItems(items)
        drawerPhotoPickerItems = []
        closeAttachmentDrawer()
    }

    func handleDrawerPresentationChange() async {
        guard isAttachmentDrawerPresented else { return }
        await recentPhotosModel.loadRecentTiles(limit: 18)
    }

    func handleSelectedTabChange() {
        closeAttachmentDrawer()
    }
}

struct OrderingRecentPhotoTile: Identifiable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage
}

@MainActor
@Observable
final class OrderingRecentPhotosModel {
    private(set) var tiles: [OrderingRecentPhotoTile] = []
    private(set) var isLoading = false

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
