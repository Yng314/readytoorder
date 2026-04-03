//
//  PillBarTestView.swift
//  readytoorder
//
//  Created by Codex on 2026/2/23.
//

import SwiftUI

private enum PillBarTestTab: CaseIterable, Hashable {
    case taste
    case ordering

    var title: String {
        switch self {
        case .taste:
            return "口味学习"
        case .ordering:
            return "点菜"
        }
    }

    var icon: String {
        switch self {
        case .taste:
            return "heart.text.square"
        case .ordering:
            return "fork.knife"
        }
    }
}

struct PillBarTestView: View {
    @State private var selectedTab: PillBarTestTab = .taste
    @State private var draftText: String = ""
    @State private var mockImageCount: Int = 0

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

            Group {
                if selectedTab == .taste {
                    PillBarTestPage(
                        title: "页面 A",
                        subtitle: "先只验证药丸常驻和高亮滑动。"
                    )
                } else {
                    PillBarTestPage(
                        title: "页面 B",
                        subtitle: "后续在这里加“上边界拉升”的输入区。"
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PillBarMorphBar(
                selectedTab: $selectedTab,
                draftText: $draftText,
                mockImageCount: $mockImageCount
            )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedTab)
        .preferredColorScheme(.light)
    }
}

private struct PillBarTestPage: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.24, blue: 0.30))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.30, green: 0.33, blue: 0.40))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct PillBarMorphBar: View {
    @Binding var selectedTab: PillBarTestTab
    @Binding var draftText: String
    @Binding var mockImageCount: Int
    @Namespace private var highlightNamespace

    private var expandProgress: CGFloat {
        selectedTab == .ordering ? 1 : 0
    }

    private var containerRadius: CGFloat {
        30 - (4 * expandProgress)
    }

    private var expandedMaxHeight: CGFloat {
        168
    }

    private var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            composerMockPanel
            .frame(maxHeight: expandedMaxHeight * expandProgress, alignment: .top)
            .opacity(expandProgress)
            .clipped()

            HStack(spacing: 8) {
                ForEach(PillBarTestTab.allCases, id: \.self) { tab in
                    let title = tab.title
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.subheadline.weight(.semibold))
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                        .background {
                            if selectedTab == tab {
                                Capsule(style: .continuous)
                                    .fill(.white.opacity(0.62))
                                    .matchedGeometryEffect(id: "pill-test-highlight", in: highlightNamespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(7)
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
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedTab)
    }

    private var composerMockPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    mockImageCount = min(6, mockImageCount + 1)
                } label: {
                    Image(systemName: "camera")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.60), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    mockImageCount = min(6, mockImageCount + 1)
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.60), in: Circle())
                }
                .buttonStyle(.plain)

                Text("\(mockImageCount)/6")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.42, green: 0.40, blue: 0.48))

                Spacer()

                Button {
                    draftText = ""
                    mockImageCount = 0
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("推荐菜品")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                    .background(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.78),
                                Color(red: 0.90, green: 0.87, blue: 0.96).opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule(style: .continuous)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.85), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask anything...", text: $draftText, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(red: 0.30, green: 0.29, blue: 0.36))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)

                Button {
                    draftText = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.33, green: 0.22, blue: 0.52))
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.84, blue: 0.96),
                                    .white.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.90), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 0.63, green: 0.53, blue: 0.78).opacity(0.45), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(trimmedDraft.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.88), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    PillBarTestView()
}
