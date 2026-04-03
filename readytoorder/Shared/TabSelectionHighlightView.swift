import SwiftUI

struct TabSelectionHighlightView: View {
    let isDragging: Bool

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(Color.black.opacity(0.08)),
                        in: .capsule
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
            } else {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.10))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .allowsHitTesting(false)
    }
}
