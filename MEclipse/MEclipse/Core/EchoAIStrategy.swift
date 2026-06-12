import Foundation

// AI 策略 — 启发式：向听 + 安全度 + 立直判断
struct EchoAIStrategy {

    let difficulty: EchoDifficulty

    init(difficulty: EchoDifficulty = .balanced) {
        self.difficulty = difficulty
    }

    func bestDiscard(hand: [EchoTile],
                     openMelds: [EchoMeld],
                     visibleDiscards: [[EchoTile]],
                     dora: [EchoTile]) -> EchoTile {
        var bucket = [Int](repeating: 0, count: 34)
        for t in hand { bucket[t.code] += 1 }

        let candidates = Array(Set(hand.map { $0.code })).sorted()
        var best: (code: Int, score: Double) = (candidates.first ?? 0, -1e9)

        for code in candidates {
            bucket[code] -= 1
            let shanten = EchoShantenCounter.shanten(bucket: bucket, openMelds: openMelds.count)
            bucket[code] += 1

            let safety  = safetyScore(code: code, visibleDiscards: visibleDiscards)
            let value   = valueScore(code: code, dora: dora)
            let danger  = isHonorOrTerminal(code: code) ? 0.4 : -0.1

            let weight: (Double, Double, Double, Double) = {
                switch difficulty {
                case .relaxed:  return (3.0, 0.2, 0.0, 0.0)
                case .balanced: return (3.0, 0.9, 0.4, 0.5)
                case .lethal:   return (3.4, 1.6, 0.7, 0.7)
                }
            }()

            let score = -Double(shanten) * weight.0
                      + safety * weight.1
                      - value  * weight.2
                      + danger * weight.3
            if score > best.score {
                best = (code, score)
            }
        }
        // 把对应的牌实例返回
        return hand.first(where: { $0.code == best.code }) ?? hand[0]
    }

    func wantsRiichi(hand: [EchoTile],
                     openMelds: [EchoMeld],
                     score: Int) -> Bool {
        guard difficulty != .relaxed else { return false }
        guard openMelds.isEmpty else { return false }
        guard score >= EchoConstants.riichiStickValue else { return false }
        var bucket = [Int](repeating: 0, count: 34)
        for t in hand { bucket[t.code] += 1 }
        let s = EchoShantenCounter.shanten(bucket: bucket, openMelds: 0)
        return s == 0
    }

    func wantsCallChi(hand: [EchoTile], target: EchoTile) -> Bool {
        // 难度越低，越乱叫
        switch difficulty {
        case .relaxed:  return Bool.random()
        case .balanced: return false
        case .lethal:   return false
        }
    }

    func wantsCallPon(hand: [EchoTile], target: EchoTile, dora: [EchoTile]) -> Bool {
        let matches = hand.filter { $0.sameKind(as: target) }
        guard matches.count >= 2 else { return false }
        let isYakuhai = target.suit == .dragon
        if isYakuhai { return true }
        return difficulty == .relaxed
    }

    func wantsCallKan(hand: [EchoTile], target: EchoTile?) -> Bool {
        if let t = target {
            let matches = hand.filter { $0.sameKind(as: t) }
            return matches.count >= 3 && difficulty != .relaxed
        }
        // 暗杠
        var bucket = [Int](repeating: 0, count: 34)
        for t in hand { bucket[t.code] += 1 }
        return bucket.contains(where: { $0 == 4 })
    }

    // MARK: helpers

    private func safetyScore(code: Int, visibleDiscards: [[EchoTile]]) -> Double {
        var occurrences = 0
        var suji = 0
        for arr in visibleDiscards {
            for t in arr {
                if t.code == code { occurrences += 1 }
                // 筋牌：4 出 → 1/7 安全；5 出 → 2/8 安全；6 出 → 3/9 安全
                if t.suit.isNumeric, let n = t.rank.numeric {
                    let base = (code / 9) * 9
                    let pos  = code - base
                    let tn   = n
                    let tBase = (t.code / 9) * 9
                    if base == tBase {
                        if (tn == 4 && (pos == 0 || pos == 6)) ||
                            (tn == 5 && (pos == 1 || pos == 7)) ||
                            (tn == 6 && (pos == 2 || pos == 8)) {
                            suji += 1
                        }
                    }
                }
            }
        }
        return Double(occurrences) * 1.0 + Double(suji) * 0.4
    }

    private func valueScore(code: Int, dora: [EchoTile]) -> Double {
        var s = 0.0
        for d in dora {
            let real = EchoWallService.doraTile(forIndicator: d)
            if real.code == code { s += 1.0 }
        }
        // 中张更值钱
        if code < 27 {
            let pos = code % 9
            if (2...6).contains(pos) { s += 0.2 }
        } else {
            s += 0.1
        }
        return s
    }

    private func isHonorOrTerminal(code: Int) -> Bool {
        if code >= 27 { return true }
        let pos = code % 9
        return pos == 0 || pos == 8
    }
}

// 向听数 — 简化版：返回需要换多少张牌才能听牌
struct EchoShantenCounter {
    static func shanten(bucket: [Int], openMelds: Int) -> Int {
        let standard = standardShanten(bucket: bucket, openMelds: openMelds)
        if openMelds > 0 { return standard }
        let chiitoi   = chiitoitsuShanten(bucket: bucket)
        let kokushi   = kokushiShanten(bucket: bucket)
        return min(standard, chiitoi, kokushi)
    }

    private static func chiitoitsuShanten(bucket: [Int]) -> Int {
        var pairs = 0
        var kinds = 0
        for c in bucket where c > 0 {
            kinds += 1
            if c >= 2 { pairs += 1 }
        }
        var s = 6 - pairs
        if kinds < 7 { s += (7 - kinds) }
        return s
    }

    private static func kokushiShanten(bucket: [Int]) -> Int {
        let yao = [0,8,9,17,18,26,27,28,29,30,31,32,33]
        var unique = 0
        var hasPair = false
        for c in yao {
            if bucket[c] >= 1 { unique += 1 }
            if bucket[c] >= 2 { hasPair = true }
        }
        return 13 - unique - (hasPair ? 1 : 0)
    }

    // 标准向听：贪心估算
    private static func standardShanten(bucket: [Int], openMelds: Int) -> Int {
        var b = bucket
        var sets = openMelds
        // 取刻
        for code in 0..<34 {
            if b[code] >= 3 {
                b[code] -= 3
                sets += 1
            }
        }
        // 取顺
        for code in 0..<27 {
            let suitBase = (code / 9) * 9
            let pos = code - suitBase
            if pos > 6 { continue }
            while b[code] > 0 && b[code + 1] > 0 && b[code + 2] > 0 {
                b[code] -= 1; b[code + 1] -= 1; b[code + 2] -= 1
                sets += 1
            }
        }
        var partials = 0
        var pair = 0
        for code in 0..<34 {
            if b[code] >= 2 && pair == 0 { pair = 1; b[code] -= 2; continue }
        }
        for code in 0..<27 {
            let suitBase = (code / 9) * 9
            let pos = code - suitBase
            if pos > 7 { continue }
            while b[code] > 0 && b[code + 1] > 0 {
                b[code] -= 1; b[code + 1] -= 1
                partials += 1
            }
        }
        let total = sets * 2 + partials + pair
        return max(0, 8 - total)
    }
}
