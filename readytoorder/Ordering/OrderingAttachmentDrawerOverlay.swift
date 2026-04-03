import Observation
import PhotosUI
import SwiftUI

struct OrderingAttachmentDrawerOverlay: View {
    let featureModel: OrderingFeatureModel

    var body: some View {
        @Bindable var bindableFeatureModel = featureModel

        ZStack(alignment: .bottom) {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .allowsHitTesting(featureModel.isAttachmentDrawerPresented)
                .onTapGesture {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        featureModel.closeAttachmentDrawer()
                    }
                }

            OrderingAttachmentDrawerCard(
                tiles: featureModel.recentPhotosModel.tiles,
                isLoading: featureModel.recentPhotosModel.isLoading,
                canAddMore: featureModel.chatViewModel.remainingAttachmentSlots > 0,
                onTapCamera: featureModel.openDrawerCamera,
                onTapRecentPhoto: { tile in
                    Task {
                        await featureModel.addRecentPhoto(tile)
                    }
                },
                onTapAllPhotos: featureModel.openAllPhotosPicker
            )
            .offset(y: featureModel.isAttachmentDrawerPresented ? 0 : 340)
            .opacity(featureModel.isAttachmentDrawerPresented ? 1.0 : 0.001)
            .allowsHitTesting(featureModel.isAttachmentDrawerPresented)
        }
        .ignoresSafeArea(edges: .bottom)
        .zIndex(40)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: featureModel.isAttachmentDrawerPresented)
        .sheet(isPresented: $bindableFeatureModel.isShowingDrawerCamera) {
            CameraCaptureSheet { image in
                featureModel.ingestDrawerCameraImage(image)
            }
            .ignoresSafeArea()
        }
        .alert("当前设备不支持拍照", isPresented: $bindableFeatureModel.isShowingDrawerCameraUnavailableAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请改用相册上传菜单图片。")
        }
        .photosPicker(
            isPresented: $bindableFeatureModel.isShowingDrawerPhotoPicker,
            selection: $bindableFeatureModel.drawerPhotoPickerItems,
            maxSelectionCount: max(1, featureModel.chatViewModel.remainingAttachmentSlots),
            matching: .images
        )
        .onChange(of: featureModel.drawerPhotoPickerItems) { _, _ in
            Task {
                await featureModel.handleDrawerPhotoPickerSelectionChange()
            }
        }
        .onChange(of: featureModel.isAttachmentDrawerPresented) { _, _ in
            Task {
                await featureModel.handleDrawerPresentationChange()
            }
        }
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
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 12) {
                    drawerContent
                }
            } else {
                drawerContent
            }
        }
    }

    private var drawerContent: some View {
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

                Button("全部照片", action: onTapAllPhotos)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.26, green: 0.25, blue: 0.32))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .modifier(OrderingDrawerGlassCapsuleStyle(interactive: true))
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
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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
        .modifier(OrderingDrawerMainGlassStyle())
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
            .modifier(OrderingDrawerGlassTileStyle(interactive: true))
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
        .modifier(OrderingDrawerGlassTileStyle(interactive: false))
    }
}

private struct OrderingDrawerMainGlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(
                        .regular.tint(Color.white.opacity(0.04)).interactive(),
                        in: .rect(cornerRadius: 28)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
            } else {
                content
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.76), lineWidth: 1)
                    )
            }
        }
    }
}

private struct OrderingDrawerGlassTileStyle: ViewModifier {
    let interactive: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(
                        interactive ? .regular.tint(Color.white.opacity(0.04)).interactive()
                            : .regular.tint(Color.white.opacity(0.04)),
                        in: .rect(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.26), lineWidth: 1)
                    )
            } else {
                content
                    .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.76), lineWidth: 1)
                    )
            }
        }
    }
}

private struct OrderingDrawerGlassCapsuleStyle: ViewModifier {
    let interactive: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(
                        interactive ? .regular.tint(Color.white.opacity(0.04)).interactive()
                            : .regular.tint(Color.white.opacity(0.04)),
                        in: .capsule
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.26), lineWidth: 1)
                    )
            } else {
                content
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.76), lineWidth: 1)
                    )
            }
        }
    }
}
