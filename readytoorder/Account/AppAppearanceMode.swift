import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "浅色模式"
        case .dark:
            return "深色模式"
        case .system:
            return "跟随系统"
        }
    }

    var subtitle: String {
        switch self {
        case .light:
            return "当前版本默认使用浅色外观。"
        case .dark:
            return "深色模式还在开发中。"
        case .system:
            return "跟随系统还在开发中。"
        }
    }

    var iconName: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "gearshape.2"
        }
    }

    var badgeTitle: String? {
        switch self {
        case .light:
            return "默认"
        case .dark, .system:
            return "开发中"
        }
    }

    var isAvailable: Bool {
        self == .light
    }
}
