import SwiftUI

struct BottomTabBarGlassBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(Color.white.opacity(0.06)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            }
        }
    }
}
