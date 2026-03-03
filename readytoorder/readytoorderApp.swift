//
//  readytoorderApp.swift
//  readytoorder
//
//  Created by Young on 2026/2/19.
//

import SwiftUI

@main
struct readytoorderApp: App {
    init() {
        AppTelemetryMonitor.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
