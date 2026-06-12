import Foundation

// 胡牌检测：基于 34-bucket 的递归
struct EchoAgariChecker {

    // 入口
    static func canAgari(bucket: [Int], openMelds: Int) -> Bool {
        if openMelds == 0 {
            if isThirteenOrphans(bucket: bucket) { return true }
            if isSevenPairs(bucket: bucket) { return true }
        }
        return decompose(bucket: bucket, sets: 4 - openMelds, hasPair: false)
    }

    static func isSevenPairs(bucket: [Int]) -> Bool {
        var pairs = 0
        var totals = 0
        for c in bucket {
            if c == 0 { continue }
            if c != 2 { return false }
            pairs += 1
            totals += c
        }
        return pairs == 7 && totals == 14
    }

    static func isThirteenOrphans(bucket: [Int]) -> Bool {
        // 幺九 13 种: 1m,9m,1p,9p,1s,9s,E,S,W,N,白,发,中
        let yaochuu = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33]
        var seen = 0
        var doubled = 0
        var others = 0
        for code in 0..<34 {
            let c = bucket[code]
            if yaochuu.contains(code) {
                if c >= 1 { seen += 1 }
                if c >= 2 { doubled += 1 }
            } else {
                others += c
            }
        }
        return seen == 13 && doubled == 1 && others == 0
    }

    // 递归：bucket 上拆 sets 个面子 + 1 个对子
    private static func decompose(bucket: [Int], sets: Int, hasPair: Bool) -> Bool {
        var b = bucket
        // 找首个非零
        guard let first = (0..<34).first(where: { b[$0] > 0 }) else {
            return sets == 0 && hasPair
        }

        // 1) 当对子
        if !hasPair && b[first] >= 2 {
            b[first] -= 2
            if decompose(bucket: b, sets: sets, hasPair: true) { return true }
            b[first] += 2
        }
        // 2) 当刻子
        if sets > 0 && b[first] >= 3 {
            b[first] -= 3
            if decompose(bucket: b, sets: sets - 1, hasPair: hasPair) { return true }
            b[first] += 3
        }
        // 3) 当顺子（只有数牌）
        if sets > 0 && first < 27 {
            let suitStart = (first / 9) * 9
            let pos = first - suitStart
            if pos <= 6, b[first] > 0, b[first + 1] > 0, b[first + 2] > 0 {
                b[first] -= 1; b[first + 1] -= 1; b[first + 2] -= 1
                if decompose(bucket: b, sets: sets - 1, hasPair: hasPair) { return true }
                b[first] += 1; b[first + 1] += 1; b[first + 2] += 1
            }
        }
        return false
    }

    // 听牌检测：13 张手牌 + 副露，看摸/捡哪张能胡
    static func waitingTiles(bucket: [Int], openMelds: Int) -> [Int] {
        var result: [Int] = []
        for code in 0..<34 where bucket[code] < 4 {
            var b = bucket
            b[code] += 1
            if canAgari(bucket: b, openMelds: openMelds) {
                result.append(code)
            }
        }
        return result
    }
}

// 手牌分解结果（用于役种识别）
struct EchoHandDecomposition {
    let pair: Int                       // pair 的 code
    let runs: [Int]                     // 顺子起始 code
    let triplets: [Int]                 // 刻子 code（含杠）
    let openKongs: [Int]                // 副露杠
    let concealedKongs: [Int]
    let originIsConcealedTriplet: [Bool]  // triplets 是不是暗刻

    var allSetCodes: [Int] {
        runs + triplets + openKongs + concealedKongs
    }
}

// 试图把手牌分解为 4 面子 1 对子，返回所有可能拆法（用于番种最优）
struct EchoDecomposer {
    static func enumerate(bucket: [Int], openMelds: [EchoMeld]) -> [EchoHandDecomposition] {
        var results: [EchoHandDecomposition] = []

        // 副露中已有的面子
        var openKongs: [Int] = []
        var openRuns:  [Int] = []
        var openTriplets: [Int] = []
        var concealedKongs: [Int] = []
        for m in openMelds {
            guard let head = m.tiles.first else { continue }
            switch m.kind {
            case .ankan:                    concealedKongs.append(head.code)
            case .minkan, .kakan:           openKongs.append(head.code)
            case .pon, .triplet:            openTriplets.append(head.code)
            case .chi, .run:                openRuns.append(head.code)
            case .pair:                     break
            }
        }

        // 暗手部分继续拆
        let setsNeeded = 4 - openMelds.count
        var work = bucket
        var collected: [(runs: [Int], triplets: [Int])] = []
        enumeratePairAndSets(bucket: &work, setsNeeded: setsNeeded, runsAcc: [], tripsAcc: [], pairCode: nil, results: &collected, foundPair: nil)

        // collected 内每个元素只有暗手部分。下面判断三连暗刻：
        for c in collected {
            // pair 在 collected 内通过 foundPair 传出？ 上面没传, 重写更直观
            _ = c
        }

        // 上面那段实现欠缺。换简单稳健的写法：
        results = enumerateAllPairs(bucket: bucket,
                                    setsNeeded: setsNeeded,
                                    openRuns: openRuns,
                                    openTriplets: openTriplets,
                                    openKongs: openKongs,
                                    concealedKongs: concealedKongs)

        return results
    }

    // 已弃用占位
    private static func enumeratePairAndSets(bucket: inout [Int],
                                             setsNeeded: Int,
                                             runsAcc: [Int],
                                             tripsAcc: [Int],
                                             pairCode: Int?,
                                             results: inout [(runs: [Int], triplets: [Int])],
                                             foundPair: Int?) { /* 留作扩展位 */ }

    private static func enumerateAllPairs(bucket: [Int],
                                          setsNeeded: Int,
                                          openRuns: [Int],
                                          openTriplets: [Int],
                                          openKongs: [Int],
                                          concealedKongs: [Int]) -> [EchoHandDecomposition] {
        var out: [EchoHandDecomposition] = []
        for pair in 0..<34 where bucket[pair] >= 2 {
            var b = bucket
            b[pair] -= 2
            var partial: [(runs: [Int], trips: [Int])] = []
            collectSets(bucket: &b, setsLeft: setsNeeded, runs: [], trips: [], out: &partial)
            for branch in partial {
                let allTrips = openTriplets + branch.trips
                let isConcealedTriplet = openTriplets.map { _ in false } + branch.trips.map { _ in true }
                let decomp = EchoHandDecomposition(
                    pair: pair,
                    runs: openRuns + branch.runs,
                    triplets: allTrips,
                    openKongs: openKongs,
                    concealedKongs: concealedKongs,
                    originIsConcealedTriplet: isConcealedTriplet
                )
                out.append(decomp)
            }
        }
        return out
    }

    private static func collectSets(bucket: inout [Int],
                                    setsLeft: Int,
                                    runs: [Int],
                                    trips: [Int],
                                    out: inout [(runs: [Int], trips: [Int])]) {
        if setsLeft == 0 {
            if bucket.allSatisfy({ $0 == 0 }) {
                out.append((runs, trips))
            }
            return
        }
        guard let first = (0..<34).first(where: { bucket[$0] > 0 }) else {
            return
        }
        // 刻子
        if bucket[first] >= 3 {
            bucket[first] -= 3
            collectSets(bucket: &bucket, setsLeft: setsLeft - 1, runs: runs, trips: trips + [first], out: &out)
            bucket[first] += 3
        }
        // 顺子
        if first < 27 {
            let suitStart = (first / 9) * 9
            let pos = first - suitStart
            if pos <= 6, bucket[first] > 0, bucket[first + 1] > 0, bucket[first + 2] > 0 {
                bucket[first] -= 1; bucket[first + 1] -= 1; bucket[first + 2] -= 1
                collectSets(bucket: &bucket, setsLeft: setsLeft - 1, runs: runs + [first], trips: trips, out: &out)
                bucket[first] += 1; bucket[first + 1] += 1; bucket[first + 2] += 1
            }
        }
    }
}
