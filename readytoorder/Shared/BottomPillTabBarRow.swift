import SwiftUI

struct BottomPillTabBarRow: View {
    @Binding var selectedTab: AppTab
    @GestureState private var dragLocationX: CGFloat?

    private let tabSpacing: CGFloat = 8
    private let tabHeight: CGFloat = AppChromeMetrics.bottomTabBarHeight

    var body: some View {
        GeometryReader { geometry in
            let metrics = BottomPillTabBarMetrics(
                totalWidth: geometry.size.width,
                tabCount: AppTab.allCases.count,
                spacing: tabSpacing
            )
            let highlightedTab = highlightedTab(using: metrics)

            Group {
                if #available(iOS 26, *) {
                    GlassEffectContainer(spacing: 12) {
                        tabBarContent(
                            highlightedTab: highlightedTab,
                            metrics: metrics
                        )
                    }
                } else {
                    tabBarContent(
                        highlightedTab: highlightedTab,
                        metrics: metrics
                    )
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture(using: metrics))
        }
        .frame(height: tabHeight)
    }

    @ViewBuilder
    private func tabBarContent(
        highlightedTab: AppTab,
        metrics: BottomPillTabBarMetrics
    ) -> some View {
        ZStack(alignment: .leading) {
            TabSelectionHighlightView(isDragging: dragLocationX != nil)
                .frame(width: metrics.tabWidth, height: tabHeight)
                .offset(x: metrics.leadingOffset(for: highlightedTab))
                .animation(.spring(response: 0.26, dampingFraction: 0.82), value: highlightedTab)
                .animation(.spring(response: 0.20, dampingFraction: 0.78), value: dragLocationX != nil)

            HStack(spacing: tabSpacing) {
                tabButtons(highlightedTab: highlightedTab)
            }
        }
    }

    private func tabButtons(highlightedTab: AppTab) -> some View {
        ForEach(AppTab.allCases, id: \.self) { tab in
            let isHighlighted = highlightedTab == tab

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
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 4)
                .foregroundStyle(isHighlighted ? Color.primary : Color.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private func highlightedTab(using metrics: BottomPillTabBarMetrics) -> AppTab {
        guard let dragLocationX else { return selectedTab }
        return metrics.tab(at: dragLocationX)
    }

    private func dragGesture(using metrics: BottomPillTabBarMetrics) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($dragLocationX) { value, state, _ in
                state = value.location.x
            }
            .onEnded { value in
                let destinationTab = metrics.tab(at: value.location.x)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    selectedTab = destinationTab
                }
            }
    }
}

private struct BottomPillTabBarMetrics {
    let totalWidth: CGFloat
    let tabCount: Int
    let spacing: CGFloat

    private var clampedTabCount: Int {
        max(1, tabCount)
    }

    var tabWidth: CGFloat {
        let totalSpacing = CGFloat(clampedTabCount - 1) * spacing
        return max(0, (totalWidth - totalSpacing) / CGFloat(clampedTabCount))
    }

    func leadingOffset(for tab: AppTab) -> CGFloat {
        let index = CGFloat(indexOf(tab))
        return index * (tabWidth + spacing)
    }

    func tab(at locationX: CGFloat) -> AppTab {
        let stride = max(1, tabWidth + spacing)
        let rawIndex = Int((locationX / stride).rounded(.down))
        let clampedIndex = min(max(0, rawIndex), AppTab.allCases.count - 1)
        return AppTab.allCases[clampedIndex]
    }

    private func indexOf(_ tab: AppTab) -> Int {
        AppTab.allCases.firstIndex(of: tab) ?? 0
    }
}
