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

enum DishTagDimension: String, Codable, CaseIterable, Hashable {
    case flavor
    case ingredient
    case texture
    case cookingMethod = "cooking_method"
    case cuisine
    case course
    case allergen

    var displayName: String {
        switch self {
        case .flavor:
            return "味型"
        case .ingredient:
            return "食材"
        case .texture:
            return "口感"
        case .cookingMethod:
            return "做法"
        case .cuisine:
            return "菜系"
        case .course:
            return "餐类"
        case .allergen:
            return "过敏原"
        }
    }
}

struct DishTagRef: Codable, Hashable, Identifiable {
    let dimension: DishTagDimension
    let key: String

    var id: String { storageKey }
    var storageKey: String { "\(dimension.rawValue):\(key)" }
    var displayName: String { TasteTagCatalog.displayName(for: self) }

    init(dimension: DishTagDimension, key: String) {
        self.dimension = dimension
        self.key = key
    }

    init?(storageKey: String) {
        let parts = storageKey.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let dimension = DishTagDimension(rawValue: parts[0]) else {
            return nil
        }
        self.dimension = dimension
        self.key = parts[1]
    }
}

enum TasteTagCatalog {
    static let labels: [DishTagDimension: [String: String]] = [
        .flavor: [
            "spicy": "辣",
            "numbing": "麻",
            "sour": "酸",
            "sweet": "甜",
            "salty": "咸",
            "bitter": "苦",
            "umami": "鲜",
            "savory": "咸香",
            "herbal": "草本香",
            "smoky": "烟熏香",
            "creamy": "奶香",
            "oily": "油润",
            "refreshing": "清爽",
            "rich": "浓郁"
        ],
        .ingredient: [
            "chicken": "鸡肉",
            "duck": "鸭肉",
            "pork": "猪肉",
            "beef": "牛肉",
            "lamb": "羊肉",
            "fish": "鱼类",
            "shrimp": "虾",
            "crab": "蟹",
            "shellfish": "贝类海鲜",
            "eel": "鳗鱼",
            "seafood": "海鲜",
            "tofu": "豆腐",
            "egg": "鸡蛋",
            "mushroom": "菌菇",
            "vegetable": "蔬菜",
            "seaweed": "海藻",
            "rice": "米饭",
            "noodle": "面食",
            "bread": "面包",
            "cheese": "芝士",
            "milk": "奶制品",
            "peanut": "花生",
            "sesame": "芝麻",
            "soy": "大豆",
            "chili": "辣椒",
            "garlic": "蒜"
        ],
        .texture: [
            "crispy": "酥脆",
            "crunchy": "脆爽",
            "tender": "嫩",
            "juicy": "多汁",
            "chewy": "有嚼劲",
            "bouncy": "弹牙",
            "silky": "顺滑",
            "soft": "软",
            "sticky": "软糯",
            "flaky": "酥松"
        ],
        .cookingMethod: [
            "stir_fried": "炒",
            "deep_fried": "油炸",
            "pan_fried": "煎",
            "grilled": "炙烤",
            "roasted": "炉烤",
            "braised": "焖烧",
            "stewed": "炖煮",
            "steamed": "清蒸",
            "boiled": "水煮",
            "poached": "白灼",
            "baked": "烘焙",
            "raw": "生食",
            "cured": "腌制"
        ],
        .cuisine: [
            "chinese": "中国菜",
            "sichuan": "川菜",
            "hunan": "湘菜",
            "cantonese": "粤菜",
            "beijing": "北京菜",
            "shanghainese": "上海菜",
            "shandong": "鲁菜",
            "jiangsu": "苏菜",
            "zhejiang": "浙菜",
            "anhui": "徽菜",
            "fujianese": "闽菜",
            "hangzhou": "杭帮菜",
            "japanese": "日本料理",
            "thai": "泰国菜",
            "vietnamese": "越南菜",
            "korean": "韩国菜",
            "indian": "印度菜",
            "mexican": "墨西哥菜",
            "french": "法国菜",
            "italian": "意大利菜",
            "spanish": "西班牙菜"
        ],
        .course: [
            "appetizer": "前菜",
            "main": "主菜",
            "soup": "汤品",
            "staple": "主食",
            "dessert": "甜品",
            "snack": "小吃",
            "drink": "饮品"
        ],
        .allergen: [
            "peanut": "花生",
            "tree_nut": "树坚果",
            "sesame": "芝麻",
            "soy": "大豆",
            "egg": "鸡蛋",
            "milk": "奶制品",
            "wheat": "小麦",
            "shellfish": "甲壳/贝类",
            "fish": "鱼类"
        ]
    ]

    static func displayName(for tag: DishTagRef) -> String {
        if let label = labels[tag.dimension]?[tag.key] {
            return label
        }
        return tag.key
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

struct DishTags: Codable, Hashable {
    let flavor: [String]
    let ingredient: [String]
    let texture: [String]
    let cookingMethod: [String]
    let cuisine: [String]
    let course: [String]
    let allergen: [String]

    init(
        flavor: [String] = [],
        ingredient: [String] = [],
        texture: [String] = [],
        cookingMethod: [String] = [],
        cuisine: [String] = [],
        course: [String] = [],
        allergen: [String] = []
    ) {
        self.flavor = Self.orderedUnique(flavor)
        self.ingredient = Self.orderedUnique(ingredient)
        self.texture = Self.orderedUnique(texture)
        self.cookingMethod = Self.orderedUnique(cookingMethod)
        self.cuisine = Self.orderedUnique(cuisine)
        self.course = Self.orderedUnique(course)
        self.allergen = Self.orderedUnique(allergen)
    }

    var allRefs: [DishTagRef] {
        var refs: [DishTagRef] = []
        refs.append(contentsOf: cuisine.map { DishTagRef(dimension: .cuisine, key: $0) })
        refs.append(contentsOf: flavor.map { DishTagRef(dimension: .flavor, key: $0) })
        refs.append(contentsOf: texture.map { DishTagRef(dimension: .texture, key: $0) })
        refs.append(contentsOf: cookingMethod.map { DishTagRef(dimension: .cookingMethod, key: $0) })
        refs.append(contentsOf: ingredient.map { DishTagRef(dimension: .ingredient, key: $0) })
        refs.append(contentsOf: course.map { DishTagRef(dimension: .course, key: $0) })
        refs.append(contentsOf: allergen.map { DishTagRef(dimension: .allergen, key: $0) })
        return refs
    }

    func displayRefs(limitPerDimension: Int = 2, maxTotal: Int = 8) -> [DishTagRef] {
        var refs: [DishTagRef] = []
        refs.append(contentsOf: cuisine.prefix(limitPerDimension).map { DishTagRef(dimension: .cuisine, key: $0) })
        refs.append(contentsOf: flavor.prefix(limitPerDimension).map { DishTagRef(dimension: .flavor, key: $0) })
        refs.append(contentsOf: texture.prefix(limitPerDimension).map { DishTagRef(dimension: .texture, key: $0) })
        refs.append(contentsOf: cookingMethod.prefix(limitPerDimension).map { DishTagRef(dimension: .cookingMethod, key: $0) })
        refs.append(contentsOf: ingredient.prefix(limitPerDimension).map { DishTagRef(dimension: .ingredient, key: $0) })
        refs.append(contentsOf: course.prefix(limitPerDimension).map { DishTagRef(dimension: .course, key: $0) })
        refs.append(contentsOf: allergen.prefix(limitPerDimension).map { DishTagRef(dimension: .allergen, key: $0) })
        return Array(refs.prefix(maxTotal))
    }

    var storageKeys: [String] {
        allRefs.map(\.storageKey)
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for raw in values {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            output.append(value)
        }
        return output
    }
}

struct DishCandidate: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let subtitle: String
    let tags: DishTags
    let imageDataURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        tags: DishTags,
        imageDataURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.tags = tags
        self.imageDataURL = imageDataURL
    }

    func withoutImagePayload() -> DishCandidate {
        DishCandidate(
            id: id,
            name: name,
            subtitle: subtitle,
            tags: tags,
            imageDataURL: nil
        )
    }

    var displayTags: [DishTagRef] {
        tags.displayRefs(limitPerDimension: 2, maxTotal: 8)
    }

    var tagStorageKeys: [String] {
        tags.storageKeys
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

struct TasteInsight: Identifiable, Hashable, Codable {
    let tag: DishTagRef
    let score: Double
    let confidence: Double

    var id: String { tag.id }
}

struct TasteProfile: Codable, Hashable {
    private(set) var likeCountByTag: [String: Double] = [:]
    private(set) var dislikeCountByTag: [String: Double] = [:]
    private(set) var exposureByTag: [String: Double] = [:]
    private(set) var totalSwipes: Int = 0

    mutating func apply(event: SwipeEvent) {
        apply(action: event.action, dish: event.dish, intensity: 1, adjustSwipeCount: 1)
    }

    mutating func revert(event: SwipeEvent) {
        apply(action: event.action, dish: event.dish, intensity: -1, adjustSwipeCount: -1)
    }

    private mutating func apply(action: SwipeAction, dish: DishCandidate, intensity: Double, adjustSwipeCount: Int) {
        for storageKey in dish.tagStorageKeys {
            exposureByTag[storageKey, default: 0] += intensity

            switch action {
            case .like:
                likeCountByTag[storageKey, default: 0] += intensity
            case .dislike:
                dislikeCountByTag[storageKey, default: 0] += intensity
            case .neutral:
                break
            }

            if likeCountByTag[storageKey, default: 0] <= 0.0001 {
                likeCountByTag[storageKey] = 0
            }
            if dislikeCountByTag[storageKey, default: 0] <= 0.0001 {
                dislikeCountByTag[storageKey] = 0
            }
            if exposureByTag[storageKey, default: 0] <= 0.0001 {
                exposureByTag[storageKey] = 0
            }
        }

        totalSwipes = max(0, totalSwipes + adjustSwipeCount)
    }

    func preferenceRatio(for storageKey: String, positive: Bool) -> Double {
        let exposure = exposureByTag[storageKey, default: 0]
        guard exposure > 0 else { return 0 }
        if positive {
            return likeCountByTag[storageKey, default: 0] / exposure
        } else {
            return dislikeCountByTag[storageKey, default: 0] / exposure
        }
    }

    func insights(positive: Bool, limit: Int, minimumExposure: Double = 1.5) -> [TasteInsight] {
        exposureByTag
            .compactMap { storageKey, exposure -> TasteInsight? in
                guard exposure >= minimumExposure,
                      let tag = DishTagRef(storageKey: storageKey) else {
                    return nil
                }
                let ratio = preferenceRatio(for: storageKey, positive: positive)
                guard ratio >= 0.34 else { return nil }
                let confidence = min(1, exposure / 6)
                return TasteInsight(tag: tag, score: ratio, confidence: confidence)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.confidence > rhs.confidence
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    var coveredTagCount: Int {
        exposureByTag.values.filter { $0 > 0.0001 }.count
    }
}
