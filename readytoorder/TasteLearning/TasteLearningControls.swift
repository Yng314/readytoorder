import SwiftUI

struct TasteLearningTopBar: View {
    let statusText: String
    let statusColor: Color
    let onOpenProfile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Spacer()
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    )

                Button(action: onOpenProfile) {
                    Image(systemName: "person.crop.circle.badge.sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.72), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开口味画像")
            }

            Spacer()
        }
    }
}

struct TasteLearningActionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let canUndo: Bool
    let hasCurrentDish: Bool
    let isAnimatingSwipe: Bool
    let onUndo: () -> Void
    let onAdvanceNeutral: () -> Void

    private var actionLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(spacing: 12))
        } else {
            AnyLayout(HStackLayout(spacing: 14))
        }
    }

    var body: some View {
        actionLayout {
            actionButton(
                icon: "arrow.uturn.backward",
                text: "撤销",
                color: .orange,
                action: onUndo
            )
            .disabled(!canUndo || isAnimatingSwipe)

            actionButton(
                icon: "minus.circle.fill",
                text: "一般",
                color: .blue,
                action: onAdvanceNeutral
            )
        }
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 320 : nil)
        .disabled(!hasCurrentDish)
    }

    private func actionButton(
        icon: String,
        text: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                Text(text)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 64 : 58)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
