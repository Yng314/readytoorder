//
//  OrderingChatView.swift
//  readytoorder
//
//  Created by Codex on 2026/2/22.
//

import Observation
import SwiftUI
import UIKit

struct OrderingChatView: View {
    let featureModel: OrderingFeatureModel

    @State private var isShowingParams = false
    @State private var isShowingClearChatConfirm = false
    @State private var previewImageItem: OrderingPreviewImageItem?
    @State private var composerDockHeight: CGFloat = 0
    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        let viewModel = featureModel.chatViewModel
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            ZStack {
                AppBackgroundView()

                OrderingMessageList(
                    messages: viewModel.messages,
                    isSending: viewModel.isSending,
                    topContentInset: 0,
                    bottomContentInset: composerDockHeight + tabBarHeight
                ) { image in
                    withAnimation(.easeInOut(duration: 0.20)) {
                        previewImageItem = OrderingPreviewImageItem(previewImage: image.previewImage)
                    }
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
            .navigationTitle("点菜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingClearChatConfirm = true
                    }
                    label: {
                        Text("清空")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(viewModel.isSending)
                    .opacity(viewModel.isSending ? 0.48 : 1.0)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingParams = true
                    }
                    label: {
                        Text("详细参数")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .background {
                OrderingTabBarHeightReader { height in
                    tabBarHeight = height
                }
            }
            .overlay(alignment: .bottom) {
                OrderingComposerDock(featureModel: featureModel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: OrderingComposerDockHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                    .zIndex(20)
            }
            .onPreferenceChange(OrderingComposerDockHeightPreferenceKey.self) { value in
                composerDockHeight = value
            }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top) {
            if let errorBanner = viewModel.errorBanner {
                OrderingErrorBanner(text: errorBanner) {
                    viewModel.errorBanner = nil
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }
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
            OrderingDetailParamsSheet(params: $bindableViewModel.detailParams)
        }
    }
}

private struct OrderingErrorBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
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
}

private struct OrderingMessageList: View {
    private enum ScrollMetrics {
        static let coordinateSpaceName = "ordering-message-list-scroll"
        static let nearBottomThreshold: CGFloat = 80
        static let bottomAnchorID = "ordering-message-list-bottom-anchor"
    }

    let messages: [OrderingChatMessage]
    let isSending: Bool
    let topContentInset: CGFloat
    let bottomContentInset: CGFloat
    let onTapImage: (OrderingChatImage) -> Void

    @State private var viewportHeight: CGFloat = 0
    @State private var bottomAnchorMaxY: CGFloat = 0
    @State private var isNearBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    Color.clear
                        .frame(height: max(0, topContentInset))

                    ForEach(messages) { message in
                        OrderingMessageBubble(message: message, onTapImage: onTapImage)
                            .id(message.id)
                    }

                    if isSending {
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

                    Color.clear
                        .frame(height: max(34, bottomContentInset + 22))

                    Color.clear
                        .frame(height: 1)
                        .id(ScrollMetrics.bottomAnchorID)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: OrderingMessageListBottomAnchorPreferenceKey.self,
                                    value: proxy.frame(in: .named(ScrollMetrics.coordinateSpaceName)).maxY
                                )
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .coordinateSpace(name: ScrollMetrics.coordinateSpaceName)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: OrderingMessageListViewportHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onPreferenceChange(OrderingMessageListViewportHeightPreferenceKey.self) { value in
                viewportHeight = value
                refreshNearBottomState()
            }
            .onPreferenceChange(OrderingMessageListBottomAnchorPreferenceKey.self) { value in
                bottomAnchorMaxY = value
                refreshNearBottomState()
            }
            .onChange(of: messages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: isSending) { _, _ in
                guard isNearBottom else { return }
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let target: AnyHashable = ScrollMetrics.bottomAnchorID
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    private func refreshNearBottomState() {
        guard viewportHeight > 0 else { return }
        isNearBottom = (bottomAnchorMaxY - viewportHeight) <= ScrollMetrics.nearBottomThreshold
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct OrderingMessageListViewportHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct OrderingMessageListBottomAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct OrderingComposerDockHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    OrderingChatView(
        featureModel: OrderingFeatureModel()
    )
}

private struct OrderingTabBarHeightReader: UIViewRepresentable {
    let onUpdate: (CGFloat) -> Void

    func makeUIView(context: Context) -> OrderingTabBarHeightProbeView {
        let view = OrderingTabBarHeightProbeView()
        view.onUpdate = onUpdate
        return view
    }

    func updateUIView(_ uiView: OrderingTabBarHeightProbeView, context: Context) {
        uiView.onUpdate = onUpdate
        uiView.reportIfNeeded()
    }
}

private final class OrderingTabBarHeightProbeView: UIView {
    var onUpdate: ((CGFloat) -> Void)?
    private var lastReportedHeight: CGFloat = -1

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportIfNeeded()
    }

    func reportIfNeeded() {
        let height = nearestTabBarHeight()
        guard abs(height - lastReportedHeight) > 0.5 else { return }
        lastReportedHeight = height

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onUpdate?(height)
        }
    }

    private func nearestTabBarHeight() -> CGFloat {
        sequence(first: next as UIResponder?, next: { $0?.next })
            .compactMap { $0 as? UIViewController }
            .first(where: { $0.tabBarController != nil })?
            .tabBarController?
            .tabBar
            .frame.height ?? 0
    }
}
