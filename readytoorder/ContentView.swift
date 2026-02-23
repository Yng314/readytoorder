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
    case settings

    var title: String {
        switch self {
        case .tasteLearning:
            return "口味学习"
        case .ordering:
            return "点菜"
        case .settings:
            return "设置"
        }
    }

    var icon: String {
        switch self {
        case .tasteLearning:
            return "heart.text.square"
        case .ordering:
            return "fork.knife"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .tasteLearning
    @StateObject private var orderingViewModel = OrderingChatViewModel()

    private var orderingExpandedHeight: CGFloat {
        orderingViewModel.attachments.isEmpty ? 132 : 252
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 185.0 / 255.0, green: 200.0 / 255.0, blue: 213.0 / 255.0),
                    Color(red: 184.0 / 255.0, green: 185.0 / 255.0, blue: 185.0 / 255.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TasteLearningView()
                .opacity(selectedTab == .tasteLearning ? 1 : 0)
                .allowsHitTesting(selectedTab == .tasteLearning)
                .zIndex(selectedTab == .tasteLearning ? 1 : 0)

            OrderingChatView(selectedTab: $selectedTab, viewModel: orderingViewModel)
                .opacity(selectedTab == .ordering ? 1 : 0)
                .allowsHitTesting(selectedTab == .ordering)
                .zIndex(selectedTab == .ordering ? 1 : 0)

            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
                .zIndex(selectedTab == .settings ? 1 : 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomMorphingTabBar(selectedTab: $selectedTab, expandedMaxHeight: orderingExpandedHeight) {
                OrderingComposerPanel(viewModel: orderingViewModel)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.light)
    }
}

struct BottomMorphingTabBar<ExpandedContent: View>: View {
    @Binding var selectedTab: AppTab
    let expandedMaxHeight: CGFloat
    @ViewBuilder var expandedContent: () -> ExpandedContent

    private var expandProgress: CGFloat {
        selectedTab == .ordering ? 1 : 0
    }

    private var containerRadius: CGFloat {
        30 - (4 * expandProgress)
    }

    private var visibleExpandedHeight: CGFloat {
        expandedMaxHeight * expandProgress
    }

    var body: some View {
        VStack(spacing: 0) {
            expandedContent()
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
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
            row
                .padding(7)
        }
    }
}

private struct SettingsView: View {
    @AppStorage("readytoorder.setting.haptics") private var hapticsEnabled = true
    @AppStorage("readytoorder.setting.autoRefill") private var autoRefillEnabled = true
    @AppStorage("readytoorder.setting.backendURL") private var backendURL = "https://readytoorder-production.up.railway.app"

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 185.0 / 255.0, green: 200.0 / 255.0, blue: 213.0 / 255.0),
                        Color(red: 184.0 / 255.0, green: 185.0 / 255.0, blue: 185.0 / 255.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    settingRow(title: "滑卡触感反馈", subtitle: "左右滑动时震动提示", isOn: $hapticsEnabled)
                    settingRow(title: "卡池自动补充", subtitle: "训练卡片低于阈值时自动生成", isOn: $autoRefillEnabled)
                    backendURLRow
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                )
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func settingRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(12)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backendURLRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gemini 后端 URL")
                .font(.subheadline.weight(.semibold))
            TextField("https://readytoorder-production.up.railway.app", text: $backendURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled(true)
                .font(.subheadline.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("默认使用 Railway 云端地址；本地调试时可改成局域网 IP。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ContentView()
}
