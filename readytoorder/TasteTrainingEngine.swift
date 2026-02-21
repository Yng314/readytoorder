//
//  TasteTrainingEngine.swift
//  readytoorder
//
//  Created by Codex on 2026/2/19.
//

import Foundation

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
