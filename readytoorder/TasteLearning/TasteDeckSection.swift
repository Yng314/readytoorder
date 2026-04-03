import SwiftUI

struct TasteLearningDeckSection<SwipeGesture: Gesture>: View {
    let viewModel: TasteTrainerViewModel
    let cardHeight: CGFloat
    let dragOffset: CGSize
    let isAnimatingSwipe: Bool
    let swipeFeedbackProgress: CGFloat
    let swipeFeedbackColor: Color
    let swipeFeedbackIcon: String
    let swipeGesture: SwipeGesture

    var body: some View {
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

                DishSwipeCard(dish: dish)
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
