import Observation
import SwiftUI
import UIKit

struct DishSwipeCard: View {
    let dish: DishCandidate
    let surfaceOpacity: Double

    private let textHorizontalPadding: CGFloat = 20
    private let textTopPadding: CGFloat = 22
    private let frostStart: CGFloat = 0.33
    private let frostFullStop: CGFloat = 0.24
    private let frostEnd: CGFloat = 0.50
    private let cardCornerRadius: CGFloat = 30

    init(dish: DishCandidate, surfaceOpacity: Double = 1.0) {
        self.dish = dish
        self.surfaceOpacity = surfaceOpacity
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

        DishCardImageView(imageDataURL: dish.imageDataURL)
            .overlay(cardSurfaceOverlay)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(dish.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)

                    Text(dish.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 1)

                    let pills = tagPills(from: dish.displayTags)
                    if !pills.isEmpty {
                        TagFlowLayout(itemSpacing: 8, rowSpacing: 8) {
                            ForEach(pills) { pill in
                                Text(pill.text)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(pill.kind.tint.opacity(0.34), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.46), lineWidth: 1)
                                    )
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, textHorizontalPadding)
                .padding(.top, textTopPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(cardShape)
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private var cardSurfaceOverlay: some View {
        topFrostOverlay
            .opacity(surfaceOpacity)
    }

    private var topFrostOverlay: some View {
        let mask = LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white, location: frostFullStop),
                .init(color: .white.opacity(0.94), location: frostStart),
                .init(color: .white.opacity(0.45), location: min(1, frostStart + 0.08)),
                .init(color: .clear, location: frostEnd),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        return ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.98)
                .mask(mask)

            Rectangle()
                .fill(.white.opacity(0.18))
                .mask(mask)

            LinearGradient(
                colors: [
                    .black.opacity(0.34),
                    .black.opacity(0.12),
                    .black.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask(mask)
        }
        .allowsHitTesting(false)
    }

    private func tagPills(from tags: [DishTagRef]) -> [TagPill] {
        tags.map { tag in
            TagPill(id: tag.storageKey, text: tag.displayName, kind: TagKind(dimension: tag.dimension))
        }
    }

    private struct TagPill: Identifiable {
        let id: String
        let text: String
        let kind: TagKind
    }

    private enum TagKind {
        case cuisine
        case flavor
        case ingredient
        case texture
        case cookingMethod
        case course
        case allergen

        init(dimension: DishTagDimension) {
            switch dimension {
            case .cuisine:
                self = .cuisine
            case .flavor:
                self = .flavor
            case .ingredient:
                self = .ingredient
            case .texture:
                self = .texture
            case .cookingMethod:
                self = .cookingMethod
            case .course:
                self = .course
            case .allergen:
                self = .allergen
            }
        }

        var tint: Color {
            switch self {
            case .cuisine:
                return Color(red: 0.32, green: 0.60, blue: 0.95)
            case .flavor:
                return Color(red: 0.95, green: 0.46, blue: 0.42)
            case .ingredient:
                return Color(red: 0.34, green: 0.74, blue: 0.56)
            case .texture:
                return Color(red: 0.74, green: 0.52, blue: 0.93)
            case .cookingMethod:
                return Color(red: 0.95, green: 0.69, blue: 0.30)
            case .course:
                return Color(red: 0.45, green: 0.76, blue: 0.82)
            case .allergen:
                return Color(red: 0.86, green: 0.35, blue: 0.36)
            }
        }
    }
}

private struct DishCardImageView: View {
    let imageDataURL: String?

    @State private var loader = DishCardImageLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.23, blue: 0.27),
                        Color(red: 0.30, green: 0.32, blue: 0.38),
                        Color(red: 0.24, green: 0.26, blue: 0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                )
            }
        }
        .onAppear {
            loader.load(from: imageDataURL)
        }
        .onChange(of: imageDataURL) { _, newValue in
            loader.load(from: newValue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

@Observable
private final class DishCardImageLoader {
    private(set) var image: UIImage?

    private var currentKey: String?
    private let cache = NSCache<NSString, UIImage>()

    func load(from rawDataURL: String?) {
        let normalized = rawDataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else {
            currentKey = nil
            image = nil
            return
        }

        if currentKey == normalized, image != nil {
            return
        }
        currentKey = normalized

        if let cached = cache.object(forKey: normalized as NSString) {
            image = cached
            return
        }

        image = nil
        let decoded = Self.decodeImage(from: normalized)
        if let decoded {
            cache.setObject(decoded, forKey: normalized as NSString)
        }
        guard currentKey == normalized else { return }
        image = decoded
    }

    private static func decodeImage(from dataURL: String) -> UIImage? {
        if let commaIndex = dataURL.firstIndex(of: ",") {
            let payload = String(dataURL[dataURL.index(after: commaIndex)...])
            if let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]),
               let image = UIImage(data: data) {
                return image
            }
        }

        guard let url = URL(string: dataURL),
              url.scheme?.lowercased() == "data",
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

struct TagFlowLayout: Layout {
    var itemSpacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + itemSpacing
        }

        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + itemSpacing
        }
    }
}
