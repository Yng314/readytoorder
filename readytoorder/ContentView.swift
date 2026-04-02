//
//  ContentView.swift
//  readytoorder
//
//  Created by Young on 2026/2/19.
//

import SwiftUI

enum AppTab: CaseIterable, Hashable {
    case tasteLearning
    case ordering
    case me

    var title: String {
        switch self {
        case .tasteLearning:
            return "口味学习"
        case .ordering:
            return "点菜"
        case .me:
            return "我"
        }
    }

    var icon: String {
        switch self {
        case .tasteLearning:
            return "heart.text.square"
        case .ordering:
            return "fork.knife"
        case .me:
            return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .tasteLearning
    @State private var orderingFeatureModel = OrderingFeatureModel()

    var body: some View {
        ZStack {
            AppBackgroundView()

            TabView(selection: $selectedTab) {
                Tab(value: AppTab.tasteLearning) {
                    TasteLearningView()
                        .toolbar(.hidden, for: .tabBar)
                }

                Tab(value: AppTab.ordering) {
                    OrderingChatView(
                        viewModel: orderingFeatureModel.chatViewModel,
                        composerReservedBottomInset: orderingFeatureModel.orderingChatBottomInset
                    )
                    .toolbar(.hidden, for: .tabBar)
                }

                Tab(value: AppTab.me) {
                    AccountView()
                        .toolbar(.hidden, for: .tabBar)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomMorphingTabBar(
                selectedTab: $selectedTab,
                expandedMaxHeight: orderingFeatureModel.orderingExpandedHeight,
                collapsedCornerRadius: orderingFeatureModel.collapsedCornerRadius,
                expandedCornerRadius: orderingFeatureModel.expandedCornerRadius,
                expandedContentInset: orderingFeatureModel.expandedContentInset
            ) {
                OrderingComposerPanel(
                    viewModel: orderingFeatureModel.chatViewModel,
                    outerContainerCornerRadius: orderingFeatureModel.barCornerRadius(for: selectedTab),
                    contentInsetFromOuterCard: orderingFeatureModel.expandedContentInset,
                    onToggleAttachmentDrawer: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            orderingFeatureModel.toggleAttachmentDrawer()
                        }
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .overlay {
            OrderingAttachmentDrawerOverlay(
                selectedTab: selectedTab,
                featureModel: orderingFeatureModel
            )
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
            row.padding(7)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSession())
        .environment(AppAppearanceSettings())
}
