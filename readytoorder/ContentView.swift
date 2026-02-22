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

    var body: some View {
        ZStack {
            TasteLearningView()
                .opacity(selectedTab == .tasteLearning ? 1 : 0)
                .allowsHitTesting(selectedTab == .tasteLearning)

            OrderingChatView()
                .opacity(selectedTab == .ordering ? 1 : 0)
                .allowsHitTesting(selectedTab == .ordering)

            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomPillTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .preferredColorScheme(.light)
    }
}

private struct BottomPillTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
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
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
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
                        Color(red: 0.96, green: 0.98, blue: 1.0),
                        Color(red: 0.98, green: 0.97, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
