import SwiftUI

struct TasteProfileSheet: View {
    let viewModel: TasteTrainerViewModel
    let onReset: () -> Void
    let onRefreshAnalysis: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Button("更新分析", action: onRefreshAnalysis)
                            .font(.subheadline.weight(.semibold))
                            .disabled(viewModel.isAnalyzingTaste || !viewModel.canRefreshAnalysis)

                        Button("重置", role: .destructive, action: onReset)
                            .font(.subheadline.weight(.semibold))
                    }

                    TasteInsightSection(
                        title: "当前偏好",
                        placeholder: "继续滑动识别偏好",
                        insights: Array(viewModel.positiveInsights.prefix(6)),
                        positive: true
                    )

                    TasteInsightSection(
                        title: "当前避雷",
                        placeholder: "继续滑动识别避雷",
                        insights: Array(viewModel.negativeInsights.prefix(6)),
                        positive: false
                    )

                    if !viewModel.recentLikedDishNames.isEmpty {
                        Text("最近喜欢：\(viewModel.recentLikedDishNames.joined(separator: " · "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TasteAnalysisSummary(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("你的口味画像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TasteAnalysisSummary: View {
    let viewModel: TasteTrainerViewModel

    var body: some View {
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
}

private struct TasteInsightSection: View {
    let title: String
    let placeholder: String
    let insights: [TasteInsight]
    let positive: Bool

    var body: some View {
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
                        Text("\(insight.tag.displayName) \(confidence)%")
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
