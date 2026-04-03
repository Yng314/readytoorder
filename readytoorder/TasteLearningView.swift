//
//  TasteLearningView.swift
//  readytoorder
//
//  Created by Young on 2026/2/19.
//

import SwiftUI

struct TasteLearningView: View {
    @Environment(AppSession.self) private var appSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = TasteTrainerViewModel()
    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingSwipe = false
    @State private var isShowingProfileSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                GeometryReader { proxy in
                    let layout = TasteLearningLayout(
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        dynamicTypeSize: dynamicTypeSize
                    )

                    ZStack {
                        TasteLearningDeckSection(
                            viewModel: viewModel,
                            cardHeight: layout.cardHeight,
                            dragOffset: dragOffset,
                            isAnimatingSwipe: isAnimatingSwipe,
                            swipeFeedbackProgress: swipeFeedbackProgress,
                            swipeFeedbackColor: swipeFeedbackColor,
                            swipeFeedbackIcon: swipeFeedbackIcon,
                            swipeGesture: swipeGesture
                        )
                        .frame(width: layout.cardWidth, height: layout.cardHeight, alignment: .center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: layout.cardCenterYOffset)

                        TasteLearningActionBar(
                            canUndo: viewModel.canUndo,
                            hasCurrentDish: viewModel.currentDish != nil,
                            isAnimatingSwipe: isAnimatingSwipe,
                            onUndo: undoLastSwipe,
                            onAdvanceNeutral: animateNeutralAdvance
                        )
                        .frame(maxWidth: layout.actionBarWidth)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, layout.actionBarTop)
                    }
                    .overlay(alignment: .top) {
                        TasteLearningTopBar(
                            statusText: tasteStatusText,
                            statusColor: tasteStatusColor,
                            onOpenProfile: openProfile
                        )
                        .padding(.horizontal, layout.horizontalInset)
                        .padding(.top, layout.topPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isShowingProfileSheet) {
            TasteProfileSheet(
                viewModel: viewModel,
                onReset: resetProfile,
                onRefreshAnalysis: viewModel.refreshAnalysisNow
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task(id: appSession.currentUser?.id) {
            await viewModel.handleSessionChange(userID: appSession.currentUser?.id)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            Task {
                await viewModel.syncToCloudNowIfPossible()
            }
        }
    }

    private var tasteStatusText: String {
        if viewModel.isAnalyzingTaste {
            return "口味分析中"
        }
        if viewModel.latestAnalysis != nil {
            return "口味分析完成"
        }
        return "口味收集中"
    }

    private var tasteStatusColor: Color {
        if viewModel.isAnalyzingTaste {
            return .orange
        }
        if viewModel.latestAnalysis != nil {
            return .green
        }
        return .blue
    }

    private var swipeFeedbackProgress: CGFloat {
        min(1, abs(dragOffset.width) / 150)
    }

    private var swipeFeedbackColor: Color {
        dragOffset.width >= 0 ? .green : .red
    }

    private var swipeFeedbackIcon: String {
        dragOffset.width >= 0 ? "heart.fill" : "xmark"
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isAnimatingSwipe else { return }
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.86)) {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                guard !isAnimatingSwipe else { return }
                finalizeSwipe(width: value.translation.width)
            }
    }

    private func openProfile() {
        isShowingProfileSheet = true
    }

    private func finalizeSwipe(width: CGFloat) {
        let threshold: CGFloat = 100
        if width > threshold {
            animateSwipe(.like, endX: 620)
        } else if width < -threshold {
            animateSwipe(.dislike, endX: -620)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                dragOffset = .zero
            }
        }
    }

    private func animateSwipe(_ action: SwipeAction, endX: CGFloat) {
        isAnimatingSwipe = true
        withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
            dragOffset = CGSize(width: endX, height: 26)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))

            var noAnimation = Transaction()
            noAnimation.disablesAnimations = true
            withTransaction(noAnimation) {
                viewModel.submitSwipe(action)
                dragOffset = .zero
            }
            isAnimatingSwipe = false
        }
    }

    private func animateNeutralAdvance() {
        guard !isAnimatingSwipe else { return }
        isAnimatingSwipe = true

        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            dragOffset = CGSize(width: 0, height: 24)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))

            var noAnimation = Transaction()
            noAnimation.disablesAnimations = true
            withTransaction(noAnimation) {
                viewModel.submitSwipe(.neutral)
                dragOffset = .zero
            }
            isAnimatingSwipe = false
        }
    }

    private func undoLastSwipe() {
        guard !isAnimatingSwipe else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            dragOffset = .zero
        }
        viewModel.undoLastSwipe()
    }

    private func resetProfile() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            dragOffset = .zero
        }
        viewModel.resetAll()
        isShowingProfileSheet = false
    }
}

private struct TasteLearningLayout {
    let horizontalInset: CGFloat
    let topPadding: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let actionBarWidth: CGFloat
    let cardCenterYOffset: CGFloat
    let actionBarTop: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets, dynamicTypeSize: DynamicTypeSize) {
        horizontalInset = 30
        topPadding = min(18, 10 + safeAreaInsets.top * 0.2)

        let availableWidth = max(0, size.width - horizontalInset * 2)
        cardWidth = availableWidth
        cardHeight = availableWidth * 1.5
        actionBarWidth = min(cardWidth, dynamicTypeSize.isAccessibilitySize ? 320 : 340)
        cardCenterYOffset = -(AppChromeMetrics.bottomTabBarHeight / 2.0)

        let actionGap: CGFloat = dynamicTypeSize.isAccessibilitySize ? 24 : 20
        actionBarTop = (size.height / 2.0) + cardCenterYOffset + (cardHeight / 2.0) + actionGap
    }
}

#Preview {
    TasteLearningView()
        .environment(AppSession())
}
