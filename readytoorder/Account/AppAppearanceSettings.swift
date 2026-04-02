import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppAppearanceSettings {
    private enum StorageKeys {
        static let selectedMode = "readytoorder.settings.appearanceMode"
    }

    var pendingUnavailableMode: AppAppearanceMode?
    private(set) var selectedMode: AppAppearanceMode

    private let defaults: UserDefaults

    convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.selectedMode = Self.restoreSelectedMode(from: defaults)
    }

    var preferredColorScheme: ColorScheme? {
        .light
    }

    func select(_ mode: AppAppearanceMode) {
        guard mode.isAvailable else {
            pendingUnavailableMode = mode
            return
        }

        pendingUnavailableMode = nil
        selectedMode = mode
        persist()
    }

    func dismissPendingUnavailableMode() {
        pendingUnavailableMode = nil
    }

    private func persist() {
        defaults.set(selectedMode.rawValue, forKey: StorageKeys.selectedMode)
    }

    private static func restoreSelectedMode(from defaults: UserDefaults) -> AppAppearanceMode {
        guard let rawValue = defaults.string(forKey: StorageKeys.selectedMode),
              let restoredMode = AppAppearanceMode(rawValue: rawValue),
              restoredMode.isAvailable else {
            return .light
        }

        return restoredMode
    }
}
