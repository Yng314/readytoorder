import SwiftUI

struct AccountAppearanceSection: View {
    let appAppearanceSettings: AppAppearanceSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("外观模式")
                .font(.headline.weight(.semibold))

            Text("当前版本默认使用浅色模式。深色模式和跟随系统还在开发中。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    AccountAppearanceModeRow(
                        mode: mode,
                        isSelected: appAppearanceSettings.selectedMode == mode,
                        onSelect: { appAppearanceSettings.select(mode) }
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.70), lineWidth: 1)
        )
    }
}

private struct AccountAppearanceModeRow: View {
    let mode: AppAppearanceMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: mode.iconName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color(red: 0.31, green: 0.41, blue: 0.63))
                    .frame(width: 28, height: 28)
                    .padding(8)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let badgeTitle = mode.badgeTitle {
                            Text(badgeTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(badgeForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badgeBackground, in: Capsule())
                        }
                    }

                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color(red: 0.24, green: 0.46, blue: 0.84) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: Color {
        isSelected ? .white.opacity(0.76) : .white.opacity(0.46)
    }

    private var iconBackground: Color {
        isSelected ? Color(red: 0.31, green: 0.41, blue: 0.63) : .white.opacity(0.78)
    }

    private var badgeForeground: Color {
        mode.isAvailable ? Color(red: 0.27, green: 0.36, blue: 0.55) : Color(red: 0.55, green: 0.38, blue: 0.16)
    }

    private var badgeBackground: Color {
        mode.isAvailable ? .white.opacity(0.78) : Color.orange.opacity(0.18)
    }
}
