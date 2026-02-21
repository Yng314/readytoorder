//
//  ContentView.swift
//  readytoorder
//
//  Created by Young on 2026/2/19.
//

import SwiftUI
import UIKit

struct TasteLearningView: View {
    @StateObject private var viewModel = TasteTrainerViewModel()
    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingSwipe = false
    @State private var isShowingProfilePopup = false

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

                GeometryReader { proxy in
                    let actionBottomPadding = max(80, proxy.safeAreaInsets.bottom + 50)
                    let maxCardWidth = min(proxy.size.width - 36, 360)
                    let maxCardHeight = max(360, proxy.size.height - actionBottomPadding - 120)
                    let cardHeight = min(maxCardHeight, maxCardWidth * 1.5)
                    let cardWidth = cardHeight * (2.0 / 3.0)

                    ZStack {
                        cardDeckSection(cardHeight: cardHeight)
                            .frame(width: cardWidth, height: cardHeight, alignment: .center)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.top, 0)
                            .padding(.bottom, 90)

                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Spacer()
                                tasteStatusPill
                                profileIconButton
                            }
                            Spacer()
                        }

                        VStack {
                            Spacer()
                            actionButtons
                                .padding(.bottom, actionBottomPadding)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 50)
                }

                if isShowingProfilePopup {
                    profilePopupOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(20)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: isShowingProfilePopup)
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.light)
    }

    private var profileIconButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isShowingProfilePopup = true
            }
        } label: {
            Image(systemName: "person.crop.circle.badge.sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var tasteStatusPill: some View {
        Text(tasteStatusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tasteStatusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tasteStatusColor.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tasteStatusColor.opacity(0.3), lineWidth: 1)
            )
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

    private func cardDeckSection(cardHeight: CGFloat) -> some View {
        ZStack {
            if let dish = viewModel.currentDish {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(swipeFeedbackColor.opacity(0.14 + 0.34 * Double(swipeFeedbackProgress)))
                    .overlay {
                        Image(systemName: swipeFeedbackIcon)
                            .font(.system(size: 76, weight: .black))
                            .foregroundStyle(.white.opacity(0.95))
                            .opacity(Double(swipeFeedbackProgress))
                            .scaleEffect(0.9 + 0.1 * Double(swipeFeedbackProgress))
                    }
                    .opacity(Double(swipeFeedbackProgress))
                    .allowsHitTesting(false)
                    .zIndex(0)
                cardView(dish: dish)
                    .zIndex(1)
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.8))
                    .frame(height: cardHeight)
                    .overlay {
                        VStack(spacing: 8) {
                            if viewModel.isGeneratingDeck {
                                ProgressView()
                                    .controlSize(.regular)
                            } else {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                            }
                            Text(viewModel.deckStatusText)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                        }
                    }
            }
        }
        .frame(height: cardHeight)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.currentDish?.id)
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

    private func cardView(dish: DishCandidate) -> some View {
        DishSwipeCard(dish: dish)
            .offset(
                x: dragOffset.width,
                y: dragOffset.height * 0.18
            )
            .rotationEffect(.degrees(Double(dragOffset.width / 18)))
            .allowsHitTesting(!isAnimatingSwipe)
            .gesture(swipeGesture)
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

    private var actionButtons: some View {
        HStack(spacing: 14) {
            actionButton(
                icon: "xmark",
                text: "不喜欢",
                color: .red,
                width: 100
            ) {
                animateSwipe(.dislike, endX: -620)
            }

            actionButton(
                icon: "arrow.uturn.backward",
                text: "撤销",
                color: .orange,
                width: 90
            ) {
                if !isAnimatingSwipe {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                    viewModel.undoLastSwipe()
                }
            }
            .disabled(!viewModel.canUndo || isAnimatingSwipe)

            actionButton(
                icon: "heart.fill",
                text: "喜欢",
                color: .green,
                width: 100
            ) {
                animateSwipe(.like, endX: 620)
            }
        }
        .disabled(viewModel.currentDish == nil)
    }

    private func actionButton(icon: String, text: String, color: Color, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                Text(text)
                    .font(.caption.weight(.semibold))
            }
            .frame(width: width, height: 58)
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var profilePopupOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(Color.white.opacity(0.12))
                .overlay(Color.black.opacity(0.08))
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        isShowingProfilePopup = false
                    }
                }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("你的口味画像")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            isShowingProfilePopup = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(.white.opacity(0.8), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Button("更新分析") {
                        viewModel.refreshAnalysisNow()
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(viewModel.isAnalyzingTaste || !viewModel.canRefreshAnalysis)

                    Button("重置") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = .zero
                        }
                        viewModel.resetAll()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            isShowingProfilePopup = false
                        }
                    }
                    .font(.caption.weight(.semibold))
                }

                insightRow(
                    title: "当前偏好",
                    placeholder: "继续滑动识别偏好",
                    insights: Array(viewModel.positiveInsights.prefix(6)),
                    positive: true
                )

                insightRow(
                    title: "当前避雷",
                    placeholder: "继续滑动识别避雷",
                    insights: Array(viewModel.negativeInsights.prefix(6)),
                    positive: false
                )

                if !viewModel.recentLikedDishNames.isEmpty {
                    Text("最近喜欢：\(viewModel.recentLikedDishNames.joined(separator: " · "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                geminiAnalysisSection
            }
            .padding(14)
            .frame(maxWidth: 360, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 12)
        }
    }

    private var geminiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Gemini 口味总结")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if viewModel.isAnalyzingTaste {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(viewModel.analysisHeadline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("避雷建议：\(viewModel.analysisAvoid)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("点菜策略：\(viewModel.analysisStrategy)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let error = viewModel.analysisErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func insightRow(title: String, placeholder: String, insights: [TasteInsight], positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if insights.isEmpty {
                Text(placeholder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 1)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                    ForEach(insights) { insight in
                        let tint: Color = positive ? .green : .red
                        let confidence = Int(insight.confidence * 100)
                        Text("\(insight.feature.name) \(confidence)%")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(tint.opacity(0.32), lineWidth: 1)
                            )
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }
}

private struct DishSwipeCard: View {
    let dish: DishCandidate

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        GeometryReader { geo in
            let imageSide = geo.size.width
            let textHeight = max(120, geo.size.height - imageSide)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(dish.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(dish.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    TagFlowLayout(itemSpacing: 8, rowSpacing: 8) {
                        ForEach(dish.normalizedTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.5), in: Capsule())
                                .foregroundStyle(Color.primary.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, minHeight: textHeight, alignment: .topLeading)
                .background(Color.white.opacity(0.94))

                DishPlaceholderImage()
                    .frame(width: geo.size.width, height: imageSide)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 0.985, green: 0.988, blue: 0.995)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(cardShape)
        .overlay(
            cardShape
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct DishPlaceholderImage: View {
    var body: some View {
        ZStack {
            if let uiImage = UIImage(named: "dish_placeholder") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.58, green: 0.14, blue: 0.10),
                        Color(red: 0.82, green: 0.22, blue: 0.12),
                        Color(red: 0.45, green: 0.11, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                )
            }
        }
        .clipped()
    }
}

private struct TagFlowLayout: Layout {
    var itemSpacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + itemSpacing
        }

        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + itemSpacing
        }
    }
}

private extension TasteFeatureGroup {
    var tint: Color {
        switch self {
        case .cuisine:
            return .indigo
        case .flavor:
            return .pink
        case .texture:
            return .teal
        case .technique:
            return .blue
        case .ingredient:
            return .orange
        case .nutrition:
            return .green
        }
    }
}

#Preview {
    TasteLearningView()
}
