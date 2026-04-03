import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 32.0 / 255.0, green: 38.0 / 255.0, blue: 49.0 / 255.0),
                Color(red: 16.0 / 255.0, green: 20.0 / 255.0, blue: 29.0 / 255.0)
            ]
        }

        return [
            Color(red: 185.0 / 255.0, green: 200.0 / 255.0, blue: 213.0 / 255.0),
            Color(red: 184.0 / 255.0, green: 185.0 / 255.0, blue: 185.0 / 255.0)
        ]
    }
}
