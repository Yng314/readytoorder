import SwiftUI

struct OrderingMessageBubble: View {
    let message: OrderingChatMessage
    var onTapImage: (OrderingChatImage) -> Void = { _ in }

    private let headlineColor = Color(red: 0.25, green: 0.22, blue: 0.30)
    private let bodyColor = Color(red: 0.30, green: 0.29, blue: 0.36)

    var body: some View {
        Group {
            if message.role == .user {
                if shouldHideAutoRecommendPromptBubble {
                    EmptyView()
                } else {
                    userPromptBubble
                }
            } else {
                assistantDigest
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var userPromptBubble: some View {
        Text(userPromptText)
            .font(.body.weight(.medium))
            .foregroundStyle(headlineColor.opacity(0.98))
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(0.44), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.56), lineWidth: 1)
            )
    }

    private var assistantDigest: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !message.images.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("菜单缩略图")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(bodyColor.opacity(0.52))

                recommendationVisualStrip
            }

            if !message.recommendations.isEmpty {
                Text(recommendationIntroText)
                    .font(.body.weight(.bold))
                    .foregroundStyle(headlineColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(message.recommendations.enumerated()), id: \.element.id) { index, item in
                        recommendationRow(index: index + 1, item: item)
                    }
                }
            } else if !message.trimmedText.isEmpty {
                if message.isIntroGuideText {
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(bodyColor.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(bodyColor.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var recommendationVisualStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(message.images) { image in
                    previewTile(for: image)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func recommendationRow(index: Int, item: MenuRecommendationItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index).")
                .font(.title3.weight(.bold))
                .foregroundStyle(headlineColor)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(headlineColor)
                        .lineLimit(2)
                    if !item.originalName.isEmpty {
                        Text(item.originalName)
                            .font(.caption)
                            .foregroundStyle(bodyColor.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Text(item.reason)
                    .font(.body)
                    .foregroundStyle(bodyColor.opacity(0.93))
                    .fixedSize(horizontal: false, vertical: true)

                Text("匹配度 \(item.matchScore)%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.45, green: 0.49, blue: 0.60).opacity(0.68))
                    )
            }
        }
    }

    private func previewTile(for image: OrderingChatImage) -> some View {
        Button {
            onTapImage(image)
        } label: {
            Image(uiImage: image.previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.52), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var userPromptText: String {
        if !message.trimmedText.isEmpty {
            return message.text
        }
        if !message.images.isEmpty {
            return "请根据我上传的菜单图片来推荐。"
        }
        return "继续这个点菜话题。"
    }

    private var shouldHideAutoRecommendPromptBubble: Bool {
        message.role == .user &&
        !message.images.isEmpty &&
        message.recommendations.isEmpty &&
        message.trimmedText.hasPrefix("请根据菜单图片推荐")
    }

    private var recommendationIntroText: String {
        let trimmed = message.trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "结合你的口味画像和菜单内容，先给你一组可直接下单的建议。"
        }
        return message.text
    }
}
