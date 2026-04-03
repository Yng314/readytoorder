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
            TabView(selection: $selectedTab) {
                Tab(AppTab.tasteLearning.title, systemImage: AppTab.tasteLearning.icon, value: AppTab.tasteLearning) {
                    TasteLearningView()
                }

                Tab(AppTab.ordering.title, systemImage: AppTab.ordering.icon, value: AppTab.ordering) {
                    OrderingChatView(featureModel: orderingFeatureModel)
                }

                Tab(AppTab.me.title, systemImage: AppTab.me.icon, value: AppTab.me) {
                    AccountView()
                }
            }

            OrderingAttachmentDrawerOverlay(featureModel: orderingFeatureModel)
                .zIndex(200)
                .allowsHitTesting(selectedTab == .ordering || orderingFeatureModel.isAttachmentDrawerPresented)
                .opacity(selectedTab == .ordering || orderingFeatureModel.isAttachmentDrawerPresented ? 1 : 0)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .ordering {
                orderingFeatureModel.handleSelectedTabChange()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSession())
        .environment(AppAppearanceSettings())
}
