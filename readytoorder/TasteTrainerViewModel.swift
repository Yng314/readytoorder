//
//  TasteTrainerViewModel.swift
//  readytoorder
//
//  Created by Codex on 2026/2/19.
//

import Foundation
import Combine

@MainActor
final class TasteTrainerViewModel: ObservableObject {
    @Published private(set) var deck: [DishCandidate] = []
    @Published private(set) var profile = TasteProfile()
    @Published private(set) var history: [SwipeEvent] = []
    @Published private(set) var latestAnalysis: TasteAnalysisResult?
    @Published private(set) var isAnalyzingTaste = false
    @Published private(set) var deckErrorMessage: String?
    @Published private(set) var analysisErrorMessage: String?

    private let store: TasteProfileStore
    private let backendClient: TasteBackendClient
    private let localGenerator = LocalPlaceholderDishGenerator()

    private let initialDeckSize = 20
    private let refillDeckSize = 20
    private let minimumDeckThreshold = 6
    private let maxHistory = 200
    private let analysisInterval = 15
    private let minimumSwipesForFirstAnalysis = 15

    convenience init() {
        self.init(store: TasteProfileStore(), backendClient: .shared)
    }

    init(store: TasteProfileStore, backendClient: TasteBackendClient) {
        self.store = store
        self.backendClient = backendClient
        bootstrap()
        refillDeckIfNeeded(targetCount: initialDeckSize)
    }

    var visibleDeck: [DishCandidate] {
        Array(deck.prefix(3))
    }

    var currentDish: DishCandidate? {
        deck.first
    }

    var positiveInsights: [TasteInsight] {
        profile.insights(positive: true, limit: 6)
    }

    var negativeInsights: [TasteInsight] {
        profile.insights(positive: false, limit: 6)
    }

    var recentLikedDishNames: [String] {
        history
            .filter { $0.action == .like }
            .prefix(3)
            .map(\.dish.name)
    }

    var canUndo: Bool {
        !history.isEmpty
    }

    var signalCoverage: Int {
        TasteFeatureCatalog.features.filter { profile.normalizedScore(for: $0.id) != 0 }.count
    }

    var isGeneratingDeck: Bool {
        deck.isEmpty
    }

    var deckStatusText: String {
        if let deckErrorMessage {
            return deckErrorMessage
        }
        return "正在准备菜品..."
    }

    var analysisHeadline: String {
        if isAnalyzingTaste {
            return "正在分析中..."
        }
        if let latestAnalysis {
            return latestAnalysis.summary
        }
        guard hasEnoughDataForFirstAnalysis else {
            let remaining = max(0, minimumSwipesForFirstAnalysis - profile.totalSwipes)
            return "继续滑动让我们了解你的口味（还需 \(remaining) 次）。"
        }
        if analysisErrorMessage != nil {
            return "分析未完成，点击“更新分析”重试。"
        }
        return "已达到分析条件，点击“更新分析”生成口味总结。"
    }

    var analysisAvoid: String {
        if isAnalyzingTaste {
            return "Gemini 正在生成避雷建议。"
        }
        if let latestAnalysis {
            return latestAnalysis.avoid
        }
        return hasEnoughDataForFirstAnalysis ? "点击“更新分析”生成避雷建议。" : "继续滑动后会生成避雷建议。"
    }

    var analysisStrategy: String {
        if isAnalyzingTaste {
            return "Gemini 正在生成下一步点菜策略。"
        }
        if let latestAnalysis {
            return latestAnalysis.strategy
        }
        return hasEnoughDataForFirstAnalysis ? "点击“更新分析”生成点菜策略。" : "继续滑动后会生成点菜策略。"
    }

    var canRefreshAnalysis: Bool {
        latestAnalysis != nil || hasEnoughDataForFirstAnalysis
    }

    func submitSwipe(_ action: SwipeAction) {
        guard let dish = deck.first else {
            refillDeckIfNeeded(targetCount: initialDeckSize)
            return
        }

        let event = SwipeEvent(dish: dish, action: action)
        profile.apply(event: event)
        history.insert(event, at: 0)
        if history.count > maxHistory {
            history.removeLast(history.count - maxHistory)
        }

        deck.removeFirst()

        if deck.count < minimumDeckThreshold {
            refillDeckIfNeeded(targetCount: refillDeckSize)
        }

        persist()
        triggerAnalysisIfNeeded()
    }

    func undoLastSwipe() {
        guard let last = history.first else { return }
        history.removeFirst()
        profile.revert(event: last)
        deck.insert(last.dish, at: 0)
        persist()
    }

    func resetAll() {
        profile = TasteProfile()
        history = []
        latestAnalysis = nil
        deck = localGenerator.makeDeck(count: initialDeckSize)
        deckErrorMessage = nil
        analysisErrorMessage = nil
        store.clear()
        persist()
    }

    func refreshAnalysisNow() {
        guard canRefreshAnalysis else { return }
        triggerTasteAnalysis()
    }

    private func bootstrap() {
        if let snapshot = store.load() {
            profile = snapshot.profile
            history = snapshot.history
            if snapshot.deck.isEmpty {
                let usedNames = Set(snapshot.history.map(\.dish.name))
                if usedNames.isEmpty {
                    deck = localGenerator.makeDeck(count: initialDeckSize)
                    deckErrorMessage = nil
                } else {
                    deck = localGenerator.makeDeck(count: initialDeckSize, avoiding: usedNames)
                    deckErrorMessage = deck.isEmpty ? "菜品没有了，点击重置重新开始。" : nil
                }
            } else {
                deck = snapshot.deck
                deckErrorMessage = nil
            }
            latestAnalysis = snapshot.latestAnalysis
            persist()
            return
        }

        deck = localGenerator.makeDeck(count: initialDeckSize)
        persist()
    }

    private func persist() {
        let snapshot = TasteTrainingSnapshot(profile: profile, deck: deck, history: history, latestAnalysis: latestAnalysis)
        store.save(snapshot)
    }

    private func refillDeckIfNeeded(targetCount: Int) {
        let needed = max(0, targetCount - deck.count)
        guard needed > 0 else { return }

        let avoidNames = Set(deck.map(\.name)).union(history.map(\.dish.name))
        let refill = localGenerator.makeDeck(count: needed, avoiding: avoidNames)
        guard !refill.isEmpty else {
            deckErrorMessage = "菜品没有了，点击重置重新开始。"
            return
        }

        deck.append(contentsOf: refill)
        deckErrorMessage = nil
        persist()
    }

    private func triggerAnalysisIfNeeded() {
        guard hasEnoughDataForFirstAnalysis else { return }
        guard profile.totalSwipes % analysisInterval == 0 else { return }
        triggerTasteAnalysis()
    }

    private func triggerTasteAnalysis() {
        guard canRefreshAnalysis else { return }
        guard !isAnalyzingTaste else { return }

        isAnalyzingTaste = true
        analysisErrorMessage = nil

        let totalSwipes = profile.totalSwipes
        let positive = positiveInsights
        let negative = negativeInsights
        let recent = Array(history.prefix(20))

        Task {
            do {
                let result = try await backendClient.analyzeTaste(
                    totalSwipes: totalSwipes,
                    positive: positive,
                    negative: negative,
                    recentEvents: recent
                )
                await MainActor.run {
                    latestAnalysis = result
                    analysisErrorMessage = nil
                    isAnalyzingTaste = false
                    persist()
                }
            } catch {
                await MainActor.run {
                    analysisErrorMessage = "Gemini 分析失败：\(error.localizedDescription)"
                    isAnalyzingTaste = false
                }
            }
        }
    }

    private var hasEnoughDataForFirstAnalysis: Bool {
        profile.totalSwipes >= minimumSwipesForFirstAnalysis
    }
}
