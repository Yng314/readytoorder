import SwiftUI

enum TasteDeckSwipeFeedbackStyle {
    case like
    case dislike

    var icon: String {
        switch self {
        case .like:
            return "heart.fill"
        case .dislike:
            return "xmark"
        }
    }

    var symbolColor: Color {
        .white
    }

    var cardTint: Color {
        switch self {
        case .like:
            return Color(red: 0.95, green: 0.24, blue: 0.36)
        case .dislike:
            return .black
        }
    }

    var shadowColor: Color {
        switch self {
        case .like:
            return Color(red: 0.95, green: 0.24, blue: 0.36).opacity(0.24)
        case .dislike:
            return .black.opacity(0.2)
        }
    }
}

struct TasteLearningDeckSection<SwipeGesture: Gesture>: View {
    let viewModel: TasteTrainerViewModel
    let cardHeight: CGFloat
    let dragOffset: CGSize
    let isAnimatingSwipe: Bool
    let foregroundFeedbackProgress: CGFloat
    let backgroundRevealProgress: CGFloat
    let swipeFeedbackStyle: TasteDeckSwipeFeedbackStyle
    let swipeGesture: SwipeGesture

    var body: some View {
        ZStack {
            if let dish = viewModel.currentDish {
                if let nextDish = viewModel.visibleDeck.dropFirst().first {
                    TasteDeckBackgroundCard(
                        dish: nextDish,
                        revealProgress: backgroundRevealProgress
                    )
                        .zIndex(0)
                }

                ZStack {
                    DishSwipeCard(dish: dish)
                        .zIndex(1)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            swipeFeedbackStyle.cardTint.opacity(
                                0.10 + 0.52 * Double(pow(foregroundFeedbackProgress, 1.1))
                            )
                        )
                        .opacity(Double(pow(foregroundFeedbackProgress, 0.95)))
                        .allowsHitTesting(false)
                        .zIndex(2)

                    TasteDeckSwipeFeedbackSymbol(
                        style: swipeFeedbackStyle,
                        progress: foregroundFeedbackProgress
                    )
                    .allowsHitTesting(false)
                    .zIndex(3)
                }
                    .offset(x: dragOffset.width, y: dragOffset.height * 0.18)
                    .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                    .allowsHitTesting(!isAnimatingSwipe)
                    .gesture(swipeGesture)
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
}

private struct TasteDeckBackgroundCard: View {
    let dish: DishCandidate
    let revealProgress: CGFloat
    private let cardCornerRadius: CGFloat = 30

    var body: some View {
        let clampedProgress = max(0, min(1, revealProgress))
        let delayedRevealProgress = max(0, (clampedProgress - 0.18) / 0.82)
        let linkedBlurRadius = 18 - 15 * Double(pow(delayedRevealProgress, 1.5))
        let linkedFrostOpacity = 0.34 - 0.34 * Double(pow(delayedRevealProgress, 1.2))
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

        DishSwipeCard(
            dish: dish,
            surfaceOpacity: 1
        )
        .compositingGroup()
        .blur(radius: linkedBlurRadius)
        .overlay {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(linkedFrostOpacity)
        }
        .clipShape(cardShape)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: clampedProgress)
    }
}

private struct TasteDeckSwipeFeedbackSymbol: View {
    let style: TasteDeckSwipeFeedbackStyle
    let progress: CGFloat

    var body: some View {
        let clampedProgress = max(0, min(1, progress))
        let visibleProgress = pow(clampedProgress, 1.35)

        Image(systemName: style.icon)
            .font(.system(size: 52, weight: .black))
            .foregroundStyle(style.symbolColor)
            .shadow(color: style.shadowColor, radius: 22, x: 0, y: 12)
            .opacity(Double(visibleProgress))
            .scaleEffect(0.68 + 0.52 * Double(visibleProgress))
    }
}
