import Foundation
import Combine

// 简单的 UserDefaults JSON 持久化
struct EchoStoredProfile: Codable {
    var rank: Int
    var rankPoints: Int
    var matchesPlayed: Int
    var winCount: Int
    var riichiCount: Int
    var preferredDifficulty: EchoDifficulty
    var soundEnabled: Bool
    var fxEnabled: Bool

    static var fresh: EchoStoredProfile {
        .init(rank: 1, rankPoints: 0,
              matchesPlayed: 0, winCount: 0, riichiCount: 0,
              preferredDifficulty: .balanced,
              soundEnabled: true, fxEnabled: true)
    }
}

// 一局的快速回放数据
struct EchoReplaySnapshot: Codable, Identifiable {
    var id: UUID
    var date: Date
    var roundWind: EchoWind
    var seatWind: EchoWind
    var resultTitle: String
    var resultHan:  Int
    var resultFu:   Int
    var yakuLabels: [String]
    var winnerName: String

    init(id: UUID = UUID(),
         date: Date = Date(),
         roundWind: EchoWind,
         seatWind: EchoWind,
         resultTitle: String,
         resultHan: Int,
         resultFu: Int,
         yakuLabels: [String],
         winnerName: String) {
        self.id = id
        self.date = date
        self.roundWind = roundWind
        self.seatWind = seatWind
        self.resultTitle = resultTitle
        self.resultHan = resultHan
        self.resultFu = resultFu
        self.yakuLabels = yakuLabels
        self.winnerName = winnerName
    }
}

final class EchoDataStore: ObservableObject {
    private let defaults: UserDefaults
    private let kProfile = "eclipse.profile.v1"
    private let kReplays = "eclipse.replays.v1"

    @Published var profile: EchoStoredProfile
    @Published var replays: [EchoReplaySnapshot]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: kProfile),
           let decoded = try? JSONDecoder().decode(EchoStoredProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = .fresh
        }
        if let data = defaults.data(forKey: kReplays),
           let decoded = try? JSONDecoder().decode([EchoReplaySnapshot].self, from: data) {
            self.replays = decoded
        } else {
            self.replays = []
        }
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: kProfile)
        }
    }

    func appendReplay(_ snap: EchoReplaySnapshot) {
        replays.insert(snap, at: 0)
        if replays.count > 10 { replays = Array(replays.prefix(10)) }
        if let data = try? JSONEncoder().encode(replays) {
            defaults.set(data, forKey: kReplays)
        }
    }

    func recordRiichi() {
        profile.riichiCount += 1
        saveProfile()
    }

    func recordMatchResult(won: Bool, gainedPoints: Int) {
        profile.matchesPlayed += 1
        if won { profile.winCount += 1 }
        profile.rankPoints += gainedPoints
        if profile.rankPoints >= 1000 {
            profile.rank += 1
            profile.rankPoints -= 1000
        } else if profile.rankPoints < 0 && profile.rank > 1 {
            profile.rank -= 1
            profile.rankPoints = max(0, 800 + profile.rankPoints)
        }
        saveProfile()
    }

    var winRateText: String {
        if profile.matchesPlayed == 0 { return "—" }
        let pct = Double(profile.winCount) / Double(profile.matchesPlayed) * 100
        return String(format: "%.1f%%", pct)
    }

    var riichiRateText: String {
        if profile.matchesPlayed == 0 { return "—" }
        let pct = Double(profile.riichiCount) / Double(profile.matchesPlayed) * 100
        return String(format: "%.1f%%", pct)
    }
}
