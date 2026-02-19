//
//  TasteTrainingEngine.swift
//  readytoorder
//
//  Created by Codex on 2026/2/19.
//

import Foundation

struct LocalPlaceholderDishGenerator {
    private struct DishTemplate {
        let name: String
        let subtitle: String
        let signalTags: [TasteFeatureID]
        let categoryTags: DishCategoryTags

        var signals: [TasteFeatureID: Double] {
            var mapped: [TasteFeatureID: Double] = [:]
            for (index, tag) in signalTags.enumerated() {
                let weight = max(0.5, 0.92 - Double(index) * 0.1)
                mapped[tag] = max(mapped[tag] ?? 0, weight)
            }
            if mapped.count < 2 {
                mapped[.umami] = 0.65
                mapped[.light] = 0.55
            }
            return mapped
        }

        func makeCandidate() -> DishCandidate {
            DishCandidate(name: name, subtitle: subtitle, signals: signals, categoryTags: categoryTags)
        }
    }

    private let templates: [DishTemplate] = Self.library

    func makeDeck(count: Int) -> [DishCandidate] {
        makeDeck(count: count, avoiding: Set<String>())
    }

    func makeDeck(count: Int, avoiding blockedNames: Set<String>) -> [DishCandidate] {
        guard count > 0, !templates.isEmpty else { return [] }

        let selected = Array(
            templates
                .filter { !blockedNames.contains($0.name) }
                .shuffled()
                .prefix(count)
        )
        return selected.map { $0.makeCandidate() }
    }

    private static func dish(
        _ name: String,
        _ subtitle: String,
        signalTags: [TasteFeatureID],
        cuisine: [String],
        flavor: [String],
        ingredient: [String]
    ) -> DishTemplate {
        DishTemplate(
            name: name,
            subtitle: subtitle,
            signalTags: signalTags,
            categoryTags: DishCategoryTags(cuisine: cuisine, flavor: flavor, ingredient: ingredient)
        )
    }

    // 调试阶段先固定 20 个菜，便于快速回归测试。
    private static let library: [DishTemplate] = [
        dish("麻婆豆腐", "川味下饭，麻辣鲜香", signalTags: [.chuanStyle, .spicy, .tofu, .rice], cuisine: ["川菜"], flavor: ["辣", "麻"], ingredient: ["豆腐", "牛肉末"]),
        dish("宫保鸡丁", "甜辣平衡，颗粒感丰富", signalTags: [.chuanStyle, .spicy, .sweet, .chicken], cuisine: ["川菜"], flavor: ["甜", "辣"], ingredient: ["鸡肉", "花生"]),
        dish("酸菜鱼", "酸辣开胃，鱼片滑嫩", signalTags: [.chuanStyle, .sour, .spicy, .seafood], cuisine: ["川菜"], flavor: ["酸", "辣"], ingredient: ["鱼片", "酸菜"]),
        dish("水煮牛肉", "重辣过瘾，牛肉滑嫩", signalTags: [.chuanStyle, .spicy, .beef, .brothy], cuisine: ["川菜"], flavor: ["辣", "麻"], ingredient: ["牛肉", "豆芽"]),
        dish("回锅肉", "锅气十足，咸香浓郁", signalTags: [.chuanStyle, .spicy, .pork, .rich], cuisine: ["川菜"], flavor: ["辣", "咸"], ingredient: ["五花肉", "青椒"]),

        dish("清蒸鲈鱼", "鲜甜清爽，口味轻盈", signalTags: [.cantoneseStyle, .seafood, .light, .steamed], cuisine: ["粤菜"], flavor: ["鲜"], ingredient: ["鲈鱼", "姜丝"]),
        dish("白切鸡", "原味突出，嫩滑清淡", signalTags: [.cantoneseStyle, .chicken, .light, .fresh], cuisine: ["粤菜"], flavor: ["鲜", "咸"], ingredient: ["鸡肉", "葱姜"]),
        dish("蜜汁叉烧", "甜咸交织，焦香明显", signalTags: [.cantoneseStyle, .sweet, .pork, .grilled], cuisine: ["粤菜"], flavor: ["甜", "咸"], ingredient: ["猪肉", "蜂蜜"]),
        dish("干炒牛河", "镬气浓郁，河粉筋道", signalTags: [.cantoneseStyle, .beef, .noodle, .stirFried], cuisine: ["粤菜"], flavor: ["咸"], ingredient: ["牛肉", "河粉"]),
        dish("云吞面", "汤鲜面弹，经典广味", signalTags: [.cantoneseStyle, .pork, .noodle, .brothy], cuisine: ["粤菜"], flavor: ["鲜", "咸"], ingredient: ["云吞", "面条"]),

        dish("豚骨拉面", "浓汤挂面，满足感强", signalTags: [.japaneseStyle, .pork, .noodle, .rich], cuisine: ["日式"], flavor: ["鲜", "咸"], ingredient: ["猪骨", "拉面"]),
        dish("照烧三文鱼饭", "甜咸平衡，油脂适中", signalTags: [.japaneseStyle, .sweet, .seafood, .rice], cuisine: ["日式"], flavor: ["甜", "咸"], ingredient: ["三文鱼", "米饭"]),
        dish("日式咖喱鸡", "香料柔和，浓郁拌饭", signalTags: [.japaneseStyle, .spicy, .chicken, .rice], cuisine: ["日式"], flavor: ["辣", "咸"], ingredient: ["鸡肉", "土豆"]),
        dish("亲子丼", "鸡肉滑蛋，汤汁拌饭", signalTags: [.japaneseStyle, .sweet, .chicken, .rice], cuisine: ["日式"], flavor: ["甜", "咸"], ingredient: ["鸡肉", "鸡蛋"]),
        dish("鳗鱼饭", "酱香浓厚，口感细腻", signalTags: [.japaneseStyle, .sweet, .seafood, .rice], cuisine: ["日式"], flavor: ["甜", "咸"], ingredient: ["鳗鱼", "米饭"]),

        dish("泰式冬阴功", "酸辣清冽，香草感强", signalTags: [.thaiStyle, .sour, .spicy, .seafood], cuisine: ["泰式"], flavor: ["酸", "辣"], ingredient: ["虾", "香茅"]),
        dish("泰式青木瓜沙拉", "清爽酸辣，蔬菜主导", signalTags: [.thaiStyle, .sour, .spicy, .veggieForward], cuisine: ["泰式"], flavor: ["酸", "辣"], ingredient: ["青木瓜", "花生"]),

        dish("孜然烤羊排", "香料饱满，肉香直接", signalTags: [.lamb, .grilled, .rich, .smoky], cuisine: ["西北风味"], flavor: ["咸", "辣"], ingredient: ["羊排", "孜然"]),
        dish("红烧牛腩", "软烂浓郁，酱香醇厚", signalTags: [.beef, .braised, .rich, .umami], cuisine: ["家常"], flavor: ["咸", "鲜"], ingredient: ["牛腩", "土豆"]),
        dish("番茄炒蛋", "酸甜清爽，家常下饭", signalTags: [.sour, .sweet, .stirFried, .light], cuisine: ["家常"], flavor: ["酸", "甜"], ingredient: ["番茄", "鸡蛋"])
    ]
}

struct TasteTrainingSnapshot: Codable {
    let profile: TasteProfile
    let deck: [DishCandidate]
    let history: [SwipeEvent]
    let latestAnalysis: TasteAnalysisResult?
}

final class TasteProfileStore {
    private let defaults = UserDefaults.standard
    private let snapshotKey = "readytoorder.taste_training_snapshot"

    func load() -> TasteTrainingSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(TasteTrainingSnapshot.self, from: data)
    }

    func save(_ snapshot: TasteTrainingSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func clear() {
        defaults.removeObject(forKey: snapshotKey)
    }
}
