//
//  readytoorderApp.swift
//  readytoorder
//
//  Created by Young on 2026/2/19.
//

import SwiftUI

@main
struct readytoorderApp: App {
    @State private var appSession = AppSession()
    @State private var appAppearanceSettings = AppAppearanceSettings()

    init() {
        AppTelemetryMonitor.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSession)
                .environment(appAppearanceSettings)
                .preferredColorScheme(appAppearanceSettings.preferredColorScheme)
        }
    }
}
