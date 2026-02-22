//
//  TasteModels.swift
//  readytoorder
//
//  Created by Codex on 2026/2/19.
//

import Foundation

enum SwipeAction: String, Codable {
    case like
    case neutral
    case dislike
}

enum TasteFeatureGroup: String, Codable, CaseIterable {
    case cuisine = "菜系"
    case flavor = "味型"
    case texture = "口感"
    case technique = "做法"
    case ingredient = "食材"
    case nutrition = "健康倾向"
}

enum TasteFeatureID: String, Codable, CaseIterable, Hashable {
    case chuanStyle
    case cantoneseStyle
    case japaneseStyle
    case thaiStyle

    case spicy
    case numbing
    case sweet
    case sour
    case umami
    case salty
    case smoky
    case herbal
    case rich
    case light
    case fresh

    case crispy
    case tender
    case chewy
    case juicy
    case brothy

    case stirFried
    case grilled
    case braised
    case deepFried
    case steamed
    case raw

    case noodle
    case rice
    case seafood
    case beef
    case pork
    case chicken
    case lamb
    case duck
    case tofu
    case mushroom
    case cheese
    case cilantro
    case garlic

    case highProtein
    case lowCarb
    case veggieForward
}

struct TasteFeature: Identifiable, Hashable, Codable {
    let id: TasteFeatureID
    let name: String
    let group: TasteFeatureGroup
}

enum TasteFeatureCatalog {
    static let features: [TasteFeature] = [
        TasteFeature(id: .chuanStyle, name: "川味", group: .cuisine),
        TasteFeature(id: .cantoneseStyle, name: "粤式", group: .cuisine),
        TasteFeature(id: .japaneseStyle, name: "日式", group: .cuisine),
        TasteFeature(id: .thaiStyle, name: "泰式", group: .cuisine),

        TasteFeature(id: .spicy, name: "辛辣", group: .flavor),
        TasteFeature(id: .numbing, name: "麻感", group: .flavor),
        TasteFeature(id: .sweet, name: "偏甜", group: .flavor),
        TasteFeature(id: .sour, name: "偏酸", group: .flavor),
        TasteFeature(id: .umami, name: "鲜味", group: .flavor),
        TasteFeature(id: .salty, name: "咸香", group: .flavor),
        TasteFeature(id: .smoky, name: "烟火香", group: .flavor),
        TasteFeature(id: .herbal, name: "香草香料", group: .flavor),
        TasteFeature(id: .rich, name: "厚重浓郁", group: .flavor),
        TasteFeature(id: .light, name: "清爽清淡", group: .flavor),
        TasteFeature(id: .fresh, name: "清新感", group: .flavor),

        TasteFeature(id: .crispy, name: "酥脆", group: .texture),
        TasteFeature(id: .tender, name: "软嫩", group: .texture),
        TasteFeature(id: .chewy, name: "筋道", group: .texture),
        TasteFeature(id: .juicy, name: "多汁", group: .texture),
        TasteFeature(id: .brothy, name: "汤感", group: .texture),

        TasteFeature(id: .stirFried, name: "爆炒", group: .technique),
        TasteFeature(id: .grilled, name: "炙烤", group: .technique),
        TasteFeature(id: .braised, name: "红烧/炖煮", group: .technique),
        TasteFeature(id: .deepFried, name: "油炸", group: .technique),
        TasteFeature(id: .steamed, name: "清蒸", group: .technique),
        TasteFeature(id: .raw, name: "冷食/生食", group: .technique),

        TasteFeature(id: .noodle, name: "面食", group: .ingredient),
        TasteFeature(id: .rice, name: "米饭搭配", group: .ingredient),
        TasteFeature(id: .seafood, name: "海鲜", group: .ingredient),
        TasteFeature(id: .beef, name: "牛肉", group: .ingredient),
        TasteFeature(id: .pork, name: "猪肉", group: .ingredient),
        TasteFeature(id: .chicken, name: "鸡肉", group: .ingredient),
        TasteFeature(id: .lamb, name: "羊肉", group: .ingredient),
        TasteFeature(id: .duck, name: "鸭肉", group: .ingredient),
        TasteFeature(id: .tofu, name: "豆腐", group: .ingredient),
        TasteFeature(id: .mushroom, name: "菌菇", group: .ingredient),
        TasteFeature(id: .cheese, name: "芝士奶香", group: .ingredient),
        TasteFeature(id: .cilantro, name: "香菜", group: .ingredient),
        TasteFeature(id: .garlic, name: "蒜香", group: .ingredient),

        TasteFeature(id: .highProtein, name: "高蛋白偏好", group: .nutrition),
        TasteFeature(id: .lowCarb, name: "低碳倾向", group: .nutrition),
        TasteFeature(id: .veggieForward, name: "蔬菜导向", group: .nutrition)
    ]

    static let byID: [TasteFeatureID: TasteFeature] = Dictionary(uniqueKeysWithValues: features.map { ($0.id, $0) })

    static func feature(for id: TasteFeatureID) -> TasteFeature {
        byID[id] ?? TasteFeature(id: id, name: id.rawValue, group: .flavor)
    }
}

struct DishCandidate: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let subtitle: String
    let signals: [TasteFeatureID: Double]
    let categoryTags: DishCategoryTags?
    let imageDataURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        signals: [TasteFeatureID: Double],
        categoryTags: DishCategoryTags? = nil,
        imageDataURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.signals = signals
        self.categoryTags = categoryTags
        self.imageDataURL = imageDataURL
    }

    func withoutImagePayload() -> DishCandidate {
        DishCandidate(
            id: id,
            name: name,
            subtitle: subtitle,
            signals: signals,
            categoryTags: categoryTags,
            imageDataURL: nil
        )
    }

    var topTags: [TasteFeature] {
        signals
            .sorted { abs($0.value) > abs($1.value) }
            .prefix(4)
            .map { TasteFeatureCatalog.feature(for: $0.key) }
    }

    var normalizedTags: [String] {
        displayCategoryTags.displayValues
    }

    var displayCategoryTags: DishCategoryTags {
        let cuisine = normalizedCuisineTags(raw: categoryTags?.cuisine ?? [])
        let flavor = normalizedFlavorTags(raw: categoryTags?.flavor ?? [])
        let ingredient = normalizedIngredientTags(raw: categoryTags?.ingredient ?? [])

        return DishCategoryTags(
            cuisine: cuisine.isEmpty ? inferredCuisineTags() : cuisine,
            flavor: flavor.isEmpty ? inferredFlavorTags() : flavor,
            ingredient: ingredient.isEmpty ? inferredIngredientTags() : ingredient
        )
    }

    private func inferredCuisineTags() -> [String] {
        let candidates: [(TasteFeatureID, String)] = [
            (.chuanStyle, "川菜"),
            (.cantoneseStyle, "粤菜"),
            (.japaneseStyle, "日式"),
            (.thaiStyle, "泰式")
        ]
        guard let top = candidates.max(by: { signals[$0.0, default: 0] < signals[$1.0, default: 0] }),
              signals[top.0, default: 0] >= 0.45 else {
            return []
        }
        return [top.1]
    }

    private func inferredFlavorTags() -> [String] {
        let candidates: [(TasteFeatureID, String)] = [
            (.sour, "酸"),
            (.sweet, "甜"),
            (.spicy, "辣"),
            (.salty, "咸"),
            (.numbing, "麻"),
            (.umami, "鲜")
        ]
        let ranked = candidates
            .compactMap { feature, label -> (String, Double)? in
                let score = signals[feature, default: 0]
                guard score >= 0.5 else { return nil }
                return (label, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        return orderedUnique(Array(ranked.prefix(3)))
    }

    private func inferredIngredientTags() -> [String] {
        let candidates: [(TasteFeatureID, String)] = [
            (.chicken, "鸡肉"),
            (.duck, "鸭肉"),
            (.pork, "猪肉"),
            (.beef, "牛肉"),
            (.lamb, "羊肉"),
            (.seafood, "海鲜"),
            (.tofu, "豆腐"),
            (.mushroom, "菌菇")
        ]
        let ranked = candidates
            .compactMap { feature, label -> (String, Double)? in
                let score = signals[feature, default: 0]
                guard score >= 0.54 else { return nil }
                return (label, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        return orderedUnique(Array(ranked.prefix(3)))
    }

    private func normalizedCuisineTags(raw: [String]) -> [String] {
        var result: [String] = []
        for item in raw {
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }
            if value.contains("川") {
                result.append("川菜")
            } else if value.contains("粤") || value.contains("广") {
                result.append("粤菜")
            } else if value.contains("日") {
                result.append("日式")
            } else if value.contains("泰") {
                result.append("泰式")
            } else {
                result.append(value)
            }
        }
        return orderedUnique(result)
    }

    private func normalizedFlavorTags(raw: [String]) -> [String] {
        let atomicFlavors = ["酸", "甜", "苦", "辣", "咸", "麻", "鲜"]
        var result: [String] = []
        for item in raw {
            for flavor in atomicFlavors where item.contains(flavor) {
                result.append(flavor)
            }
        }
        return orderedUnique(result)
    }

    private func normalizedIngredientTags(raw: [String]) -> [String] {
        var result: [String] = []
        for item in raw {
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }
            if value.contains("鸡") {
                result.append("鸡肉")
            } else if value.contains("鸭") {
                result.append("鸭肉")
            } else if value.contains("猪") {
                result.append("猪肉")
            } else if value.contains("牛") {
                result.append("牛肉")
            } else if value.contains("羊") {
                result.append("羊肉")
            } else if value.contains("虾") || value.contains("蟹") || value.contains("鱼") || value.contains("贝") {
                result.append("海鲜")
            } else if value.contains("豆腐") || value.contains("豆") {
                result.append("豆腐")
            } else if value.contains("菌") || value.contains("菇") {
                result.append("菌菇")
            } else {
                result.append(value)
            }
        }
        return orderedUnique(result)
    }

    private func orderedUnique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for item in items where !item.isEmpty {
            guard !seen.contains(item) else { continue }
            seen.insert(item)
            output.append(item)
        }
        return output
    }
}

struct DishCategoryTags: Codable, Hashable {
    let cuisine: [String]
    let flavor: [String]
    let ingredient: [String]

    init(cuisine: [String] = [], flavor: [String] = [], ingredient: [String] = []) {
        self.cuisine = cuisine
        self.flavor = flavor
        self.ingredient = ingredient
    }

    var displayValues: [String] {
        var seen = Set<String>()
        var output: [String] = []
        for item in cuisine + flavor + ingredient where !item.isEmpty {
            guard !seen.contains(item) else { continue }
            seen.insert(item)
            output.append(item)
        }
        return output
    }
}

struct SwipeEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let dish: DishCandidate
    let action: SwipeAction
    let createdAt: Date

    init(id: UUID = UUID(), dish: DishCandidate, action: SwipeAction, createdAt: Date = .now) {
        self.id = id
        self.dish = dish
        self.action = action
        self.createdAt = createdAt
    }
}

struct TasteInsight: Identifiable, Hashable {
    let feature: TasteFeature
    let score: Double
    let confidence: Double

    var id: TasteFeatureID {
        feature.id
    }
}

struct TasteProfile: Codable, Hashable {
    private(set) var scoreByFeature: [TasteFeatureID: Double] = [:]
    private(set) var exposureByFeature: [TasteFeatureID: Double] = [:]
    private(set) var totalSwipes: Int = 0

    mutating func apply(event: SwipeEvent) {
        apply(action: event.action, dish: event.dish, intensity: 1, adjustSwipeCount: 1)
    }

    mutating func revert(event: SwipeEvent) {
        apply(action: event.action, dish: event.dish, intensity: -1, adjustSwipeCount: -1)
    }

    private mutating func apply(action: SwipeAction, dish: DishCandidate, intensity: Double, adjustSwipeCount: Int) {
        let direction: Double
        switch action {
        case .like:
            direction = 1.0
        case .neutral:
            direction = -0.25
        case .dislike:
            direction = -1.0
        }

        for (featureID, signal) in dish.signals {
            scoreByFeature[featureID, default: 0] += direction * signal * intensity
            exposureByFeature[featureID, default: 0] += abs(signal) * intensity

            if abs(scoreByFeature[featureID, default: 0]) < 0.0001 {
                scoreByFeature[featureID] = 0
            }
            if exposureByFeature[featureID, default: 0] <= 0.0001 {
                exposureByFeature[featureID] = 0
            }
        }

        totalSwipes = max(0, totalSwipes + adjustSwipeCount)
    }

    func normalizedScore(for featureID: TasteFeatureID) -> Double {
        let exposure = exposureByFeature[featureID, default: 0]
        guard exposure > 0 else { return 0 }
        return scoreByFeature[featureID, default: 0] / exposure
    }

    func insights(positive: Bool, limit: Int, minimumExposure: Double = 0.7) -> [TasteInsight] {
        let candidates = TasteFeatureCatalog.features.compactMap { feature -> TasteInsight? in
            let exposure = exposureByFeature[feature.id, default: 0]
            guard exposure >= minimumExposure else { return nil }

            let score = normalizedScore(for: feature.id)
            let pass = positive ? score > 0.12 : score < -0.12
            guard pass else { return nil }

            let confidence = min(1, exposure / 4)
            return TasteInsight(feature: feature, score: score, confidence: confidence)
        }

        let sorted: [TasteInsight]
        if positive {
            sorted = candidates.sorted { $0.score > $1.score }
        } else {
            sorted = candidates.sorted { $0.score < $1.score }
        }
        return Array(sorted.prefix(limit))
    }
}
