import Foundation

// 役种计算：返回最大番役的拆解
struct EchoYakuCalculator {

    static func evaluate(hand: EchoWinningHand,
                         context: EchoRoundContext) -> [EchoYaku] {

        // 优先检 13 张幺九/七对子
        let bucket = hand.bucket34()

        if EchoAgariChecker.isThirteenOrphans(bucket: bucket) {
            return [EchoYaku(id: .kokushi, han: 13)]
        }

        var bestYaku: [EchoYaku] = []
        var bestHan  = -1

        // 七对子
        if hand.melds.isEmpty && EchoAgariChecker.isSevenPairs(bucket: bucket) {
            var ys = [EchoYaku(id: .chiitoitsu, han: 2)]
            ys.append(contentsOf: appendBaseFlags(context: context, isPinfu: false))
            ys.append(contentsOf: yakuFromTanyaoHonitsu(decomp: nil, bucket: bucket, hand: hand, context: context))
            bestHan = ys.reduce(0) { $0 + $1.han }
            bestYaku = ys
        }

        // 标准 4 面子 1 对子
        let decomps = EchoDecomposer.enumerate(bucket: handBucketForDecomp(hand: hand), openMelds: hand.melds)
        for d in decomps {
            var ys: [EchoYaku] = []
            ys.append(contentsOf: appendBaseFlags(context: context, isPinfu: isPinfu(decomp: d, hand: hand, context: context)))

            // 役牌
            ys.append(contentsOf: yakuhai(decomp: d, context: context))

            // 一杯口 / 二杯口
            if context.isMenzen {
                let pairs = countIdenticalRuns(d.runs)
                if pairs >= 2 { ys.append(.init(id: .ryanpeikou, han: 3)) }
                else if pairs == 1 { ys.append(.init(id: .iipeiko, han: 1)) }
            }

            // 平和
            if isPinfu(decomp: d, hand: hand, context: context) {
                ys.append(.init(id: .pinfu, han: 1))
            }

            // 三色同顺
            if hasSanshokuDoujun(d.runs) {
                ys.append(.init(id: .sanshokuDoujun, han: context.isMenzen ? 2 : 1))
            }
            // 三色同刻
            if hasSanshokuDoukou(d.triplets + d.openKongs + d.concealedKongs) {
                ys.append(.init(id: .sanshokuDoukou, han: 2))
            }
            // 一气通贯
            if hasIttsuu(d.runs) {
                ys.append(.init(id: .ittsuu, han: context.isMenzen ? 2 : 1))
            }
            // 全帯 / 纯全
            let chanta = chantaCheck(decomp: d, bucket: bucket)
            if chanta == .junchan {
                ys.append(.init(id: .junchan, han: context.isMenzen ? 3 : 2))
            } else if chanta == .chanta {
                ys.append(.init(id: .chanta, han: context.isMenzen ? 2 : 1))
            }
            // 断幺九
            if isTanyao(bucket: bucket) {
                ys.append(.init(id: .tanyao, han: 1))
            }
            // 对对和
            let totalTriplets = d.triplets.count + d.openKongs.count + d.concealedKongs.count
            if totalTriplets == 4 {
                ys.append(.init(id: .toitoi, han: 2))
            }
            // 三暗刻
            let concealedTripletsCount = zip(d.triplets, d.originIsConcealedTriplet).filter { $0.1 }.count + d.concealedKongs.count
            if concealedTripletsCount >= 3 {
                if concealedTripletsCount == 4 {
                    ys.append(.init(id: .suuankou, han: 13))
                } else {
                    ys.append(.init(id: .sanankou, han: 2))
                }
            }
            // 三杠子 / 四杠子
            let kongs = d.openKongs.count + d.concealedKongs.count
            if kongs == 3 { ys.append(.init(id: .sankantsu, han: 2)) }
            if kongs == 4 { ys.append(.init(id: .suukantsu, han: 13)) }

            // 小三元 / 大三元
            let dragons = [31, 32, 33]
            let dragonTripletCount = dragons.filter { code in
                d.triplets.contains(code) || d.openKongs.contains(code) || d.concealedKongs.contains(code)
            }.count
            let dragonPair = (dragons.contains(d.pair)) ? 1 : 0
            if dragonTripletCount == 3 {
                ys.append(.init(id: .daisangen, han: 13))
            } else if dragonTripletCount == 2 && dragonPair == 1 {
                ys.append(.init(id: .shousangen, han: 2))
            }

            // 小四喜 / 大四喜
            let winds = [27, 28, 29, 30]
            let windTripletCount = winds.filter { code in
                d.triplets.contains(code) || d.openKongs.contains(code) || d.concealedKongs.contains(code)
            }.count
            let windPair = winds.contains(d.pair) ? 1 : 0
            if windTripletCount == 4 {
                ys.append(.init(id: .daisuushii, han: 13))
            } else if windTripletCount == 3 && windPair == 1 {
                ys.append(.init(id: .shousuushii, han: 13))
            }

            // 混老头 / 清老头
            if isAllTerminals(bucket: bucket) {
                ys.append(.init(id: .chinroutou, han: 13))
            } else if isAllYaochuu(bucket: bucket) {
                ys.append(.init(id: .honroutou, han: 2))
            }
            // 字一色
            if isAllHonors(bucket: bucket) {
                ys.append(.init(id: .tsuuiisou, han: 13))
            }
            // 绿一色
            if isAllGreen(bucket: bucket) {
                ys.append(.init(id: .ryuuiisou, han: 13))
            }
            // 九莲宝灯
            if hand.melds.isEmpty && isChuurenpoutou(bucket: bucket, winTile: hand.winTile) {
                ys.append(.init(id: .chuurenpoutou, han: 13))
            }

            // 混一色 / 清一色
            ys.append(contentsOf: yakuFromTanyaoHonitsu(decomp: d, bucket: bucket, hand: hand, context: context))

            // 去重：同一役只能保留一份（取 han 最大那条）
            ys = dedupe(ys)

            let han = ys.reduce(0) { $0 + $1.han }
            if han > bestHan {
                bestHan  = han
                bestYaku = ys
            }
        }

        return bestYaku
    }

    // MARK: - 拆解相关

    private static func handBucketForDecomp(hand: EchoWinningHand) -> [Int] {
        var b = [Int](repeating: 0, count: 34)
        for t in hand.concealed { b[t.code] += 1 }
        return b
    }

    // MARK: - 子检测

    private static func appendBaseFlags(context: EchoRoundContext, isPinfu: Bool) -> [EchoYaku] {
        var out: [EchoYaku] = []
        if context.isRiichi && !context.isDoubleRiichi  { out.append(.init(id: .riichi, han: 1)) }
        if context.isDoubleRiichi                       { out.append(.init(id: .doubleRiichi, han: 2)) }
        if context.isIppatsu                            { out.append(.init(id: .ippatsu, han: 1)) }
        // 自摸：门清时叫门前清自摸和
        // 留给 evaluate 外层处理
        return out
    }

    private static func yakuhai(decomp: EchoHandDecomposition, context: EchoRoundContext) -> [EchoYaku] {
        var out: [EchoYaku] = []
        let allTrip = decomp.triplets + decomp.openKongs + decomp.concealedKongs
        for code in allTrip {
            switch code {
            case 31: out.append(.init(id: .yakuhaiHaku,  han: 1))
            case 32: out.append(.init(id: .yakuhaiHatsu, han: 1))
            case 33: out.append(.init(id: .yakuhaiChun,  han: 1))
            default: break
            }
            if code == context.seatWind.rank.rawValue - 11 + 27 {
                out.append(.init(id: .yakuhaiSeat, han: 1))
            }
            if code == context.roundWind.rank.rawValue - 11 + 27 {
                out.append(.init(id: .yakuhaiRound, han: 1))
            }
        }
        return out
    }

    private static func isPinfu(decomp: EchoHandDecomposition, hand: EchoWinningHand, context: EchoRoundContext) -> Bool {
        guard context.isMenzen else { return false }
        // 4 顺子
        guard decomp.triplets.isEmpty, decomp.openKongs.isEmpty, decomp.concealedKongs.isEmpty else { return false }
        // 对子不是役牌
        if [31,32,33].contains(decomp.pair) { return false }
        if decomp.pair == context.seatWind.rank.rawValue - 11 + 27 { return false }
        if decomp.pair == context.roundWind.rank.rawValue - 11 + 27 { return false }
        // 两面听：和牌的 tile 要落在顺子的边端但不能是边张/嵌张
        let winCode = hand.winTile.code
        for runStart in decomp.runs {
            if winCode == runStart || winCode == runStart + 2 {
                // 不能是 12-3 或 7-89 的 1/9
                if runStart % 9 == 0 && winCode == runStart + 2 { continue }   // 1-2-3 的 3 边张
                if runStart % 9 == 6 && winCode == runStart      { continue }   // 7-8-9 的 7 边张
                return true
            }
        }
        return false
    }

    private static func countIdenticalRuns(_ runs: [Int]) -> Int {
        var count: [Int: Int] = [:]
        for r in runs { count[r, default: 0] += 1 }
        return count.values.filter { $0 >= 2 }.count
    }

    private static func hasSanshokuDoujun(_ runs: [Int]) -> Bool {
        // 找 m / p / s 起点相同
        for start in 0...6 {
            if runs.contains(start) && runs.contains(start + 9) && runs.contains(start + 18) {
                return true
            }
        }
        return false
    }

    private static func hasSanshokuDoukou(_ triplets: [Int]) -> Bool {
        for n in 0..<9 {
            if triplets.contains(n) && triplets.contains(n + 9) && triplets.contains(n + 18) { return true }
        }
        return false
    }

    private static func hasIttsuu(_ runs: [Int]) -> Bool {
        // 起点 0/3/6  9/12/15  18/21/24
        for suitBase in [0, 9, 18] {
            if runs.contains(suitBase) && runs.contains(suitBase + 3) && runs.contains(suitBase + 6) {
                return true
            }
        }
        return false
    }

    enum ChantaResult { case none, chanta, junchan }
    private static func chantaCheck(decomp: EchoHandDecomposition, bucket: [Int]) -> ChantaResult {
        // 每个面子都含幺九（1, 9 或字）
        let yaochuuCodes = Set([0,8,9,17,18,26,27,28,29,30,31,32,33])
        func touchesYaochuu(setStart: Int, isRun: Bool) -> Bool {
            if isRun {
                return [setStart, setStart + 2].contains { yaochuuCodes.contains($0) }
            } else {
                return yaochuuCodes.contains(setStart)
            }
        }
        let runsOK = decomp.runs.allSatisfy { touchesYaochuu(setStart: $0, isRun: true) }
        let tripsOK = (decomp.triplets + decomp.openKongs + decomp.concealedKongs).allSatisfy { touchesYaochuu(setStart: $0, isRun: false) }
        let pairOK  = yaochuuCodes.contains(decomp.pair)
        guard runsOK && tripsOK && pairOK else { return .none }
        // 无字 → 纯全
        let usesHonor = (decomp.triplets + decomp.openKongs + decomp.concealedKongs).contains(where: { $0 >= 27 }) ||
                        decomp.pair >= 27
        return usesHonor ? .chanta : .junchan
    }

    private static func isTanyao(bucket: [Int]) -> Bool {
        let yaochuu = [0,8,9,17,18,26,27,28,29,30,31,32,33]
        return yaochuu.allSatisfy { bucket[$0] == 0 }
    }
    private static func isAllYaochuu(bucket: [Int]) -> Bool {
        let yaochuu = Set([0,8,9,17,18,26,27,28,29,30,31,32,33])
        for code in 0..<34 where bucket[code] > 0 {
            if !yaochuu.contains(code) { return false }
        }
        return true
    }
    private static func isAllTerminals(bucket: [Int]) -> Bool {
        let terms = Set([0,8,9,17,18,26])
        for code in 0..<34 where bucket[code] > 0 {
            if !terms.contains(code) { return false }
        }
        return true
    }
    private static func isAllHonors(bucket: [Int]) -> Bool {
        for code in 0..<27 where bucket[code] > 0 { return false }
        return true
    }
    private static func isAllGreen(bucket: [Int]) -> Bool {
        let green = Set([19, 20, 21, 23, 25, 32]) // s2 s3 s4 s6 s8 + 发(32)
        for code in 0..<34 where bucket[code] > 0 {
            if !green.contains(code) { return false }
        }
        return true
    }

    private static func isChuurenpoutou(bucket: [Int], winTile: EchoTile) -> Bool {
        // 同花色 1112345678999 + 同花任 1
        for suit in [0, 9, 18] {
            let pattern = [3,1,1,1,1,1,1,1,3]
            var ok = true
            for i in 0..<9 {
                let need = pattern[i]
                let have = bucket[suit + i]
                if have < need { ok = false; break }
            }
            if !ok { continue }
            // total 14
            let total = (0..<9).reduce(0) { $0 + bucket[suit + $1] }
            if total != 14 { continue }
            // 必须全部花色一致
            for c in 0..<34 where bucket[c] > 0 {
                if c < suit || c >= suit + 9 { ok = false; break }
            }
            if ok && winTile.code >= suit && winTile.code < suit + 9 { return true }
        }
        return false
    }

    private static func yakuFromTanyaoHonitsu(decomp: EchoHandDecomposition?,
                                              bucket: [Int],
                                              hand: EchoWinningHand,
                                              context: EchoRoundContext) -> [EchoYaku] {
        var out: [EchoYaku] = []
        let suitsUsed = (0..<3).filter { suitIdx in
            (0..<9).contains(where: { bucket[suitIdx * 9 + $0] > 0 })
        }
        let honorsUsed = (27..<34).contains(where: { bucket[$0] > 0 })
        if suitsUsed.count == 1 && !honorsUsed {
            out.append(.init(id: .chinitsu, han: context.isMenzen ? 6 : 5))
        } else if suitsUsed.count == 1 && honorsUsed {
            out.append(.init(id: .honitsu, han: context.isMenzen ? 3 : 2))
        }
        return out
    }

    private static func dedupe(_ list: [EchoYaku]) -> [EchoYaku] {
        var seen: [EchoYakuId: EchoYaku] = [:]
        for y in list {
            if let prev = seen[y.id] {
                if y.han > prev.han { seen[y.id] = y }
            } else {
                seen[y.id] = y
            }
        }
        return Array(seen.values)
    }
}

// 符数计算
struct EchoFuCalculator {

    static func computeFu(hand: EchoWinningHand,
                          decomp: EchoHandDecomposition?,
                          context: EchoRoundContext,
                          yaku: [EchoYaku]) -> Int {
        // 七对子固定 25 符
        if yaku.contains(where: { $0.id == .chiitoitsu }) { return 25 }
        // 平和荣和 30，平和自摸 20
        if yaku.contains(where: { $0.id == .pinfu }) {
            return hand.isTsumo ? 20 : 30
        }

        var fu = 20

        // 副底
        if hand.isTsumo { fu += 2 }
        if context.isMenzen && !hand.isTsumo { fu += 10 }

        // 副露：每杠 +8/+16/+32 等。简化处理
        if let d = decomp {
            for code in d.triplets {
                let isYaochuu = isYao(code: code)
                let isConcealed = d.originIsConcealedTriplet[(d.triplets.firstIndex(of: code) ?? 0)]
                let base = isYaochuu ? 4 : 2
                fu += isConcealed ? base * 2 : base
            }
            for code in d.openKongs {
                fu += isYao(code: code) ? 16 : 8
            }
            for code in d.concealedKongs {
                fu += isYao(code: code) ? 32 : 16
            }
            // 雀头
            if d.pair == 31 || d.pair == 32 || d.pair == 33 { fu += 2 }
            if d.pair == context.seatWind.rank.rawValue - 11 + 27 { fu += 2 }
            if d.pair == context.roundWind.rank.rawValue - 11 + 27 { fu += 2 }
            // 听牌型：嵌张/边张/单骑 +2 — 这里粗略加 2
            fu += 2
        }
        // 上向 10 符
        let rounded = Int(ceil(Double(fu) / 10.0)) * 10
        return rounded
    }

    private static func isYao(code: Int) -> Bool {
        let yao: Set<Int> = [0,8,9,17,18,26,27,28,29,30,31,32,33]
        return yao.contains(code)
    }
}

// 总点数与分配
struct EchoScoreEngine {

    static func compute(hand: EchoWinningHand,
                        context: EchoRoundContext,
                        winnerSeat: Int,
                        loserSeat: Int?,
                        seatWinds: [EchoWind]) -> EchoScoreResult {

        var yakuList = EchoYakuCalculator.evaluate(hand: hand, context: context)

        if hand.isTsumo && context.isMenzen {
            yakuList.append(.init(id: .menzenTsumo, han: 1))
        }
        // 岭上/海底/河底/抢杠 加 1 番
        if context.isRinshan { yakuList.append(.init(id: .ippatsu, han: 0)) /* 用 ippatsu id 仅作占位避免新 id; 实际另算 */ }

        let isYakuman = yakuList.contains(where: { $0.isYakuman })
        let yakumanCount = yakuList.filter { $0.isYakuman }.map { _ in 1 }.reduce(0, +)

        // dora 计算
        let bucket = hand.bucket34()
        let doraCount = context.doraIndicators.reduce(0) { acc, ind in
            let d = EchoWallService.doraTile(forIndicator: ind)
            return acc + bucket[d.code]
        }
        let kandoraCount = context.kandoraIndicators.reduce(0) { acc, ind in
            let d = EchoWallService.doraTile(forIndicator: ind)
            return acc + bucket[d.code]
        }
        let useUra = context.isRiichi || context.isDoubleRiichi
        let uraCount = useUra ? context.uraIndicators.reduce(0) { acc, ind in
            let d = EchoWallService.doraTile(forIndicator: ind)
            return acc + bucket[d.code]
        } : 0
        let akaCount = hand.allTiles.filter { $0.isAka }.count

        // 处理：役满不算 dora
        let han: Int = {
            if isYakuman { return 13 * max(1, yakumanCount) }
            let base = yakuList.reduce(0) { $0 + $1.han }
            return base + doraCount + kandoraCount + uraCount + akaCount
        }()

        // 没役直接 0
        if !isYakuman && yakuList.filter({ !$0.isYakuman && $0.han > 0 }).isEmpty {
            return EchoScoreResult(yaku: [], dora: 0, uradora: 0, aka: 0,
                                   totalHan: 0, fu: 0, basePoints: 0,
                                   payment: [:], title: "No Yaku",
                                   summary: [])
        }

        let decomps = EchoDecomposer.enumerate(bucket: handBucketForDecomp(hand: hand), openMelds: hand.melds)
        let fu: Int = decomps.first.map { EchoFuCalculator.computeFu(hand: hand, decomp: $0, context: context, yaku: yakuList) } ?? 30

        let basePoints = computeBasePoints(han: han, fu: fu, isYakuman: isYakuman, yakumanCount: max(1, yakumanCount))
        let title = scoreTitle(han: han, fu: fu, isYakuman: isYakuman, yakumanCount: yakumanCount)

        let isDealer = (winnerSeat == 0 && seatWinds.first == .east) || seatWinds[winnerSeat] == .east
        let pay = distribute(base: basePoints,
                             isTsumo: hand.isTsumo,
                             winner: winnerSeat,
                             loser: loserSeat,
                             dealerSeat: seatWinds.firstIndex(of: .east) ?? 0,
                             isDealer: isDealer,
                             honba: context.honba,
                             riichiSticks: context.riichiSticks)

        let summary = yakuList.map { EchoScoreLineItem(label: $0.id.displayName, han: $0.han, isYakuman: $0.isYakuman) }
        return EchoScoreResult(yaku: yakuList,
                               dora: doraCount + kandoraCount,
                               uradora: uraCount,
                               aka: akaCount,
                               totalHan: han, fu: fu,
                               basePoints: basePoints,
                               payment: pay,
                               title: title,
                               summary: summary)
    }

    private static func handBucketForDecomp(hand: EchoWinningHand) -> [Int] {
        var b = [Int](repeating: 0, count: 34)
        for t in hand.concealed { b[t.code] += 1 }
        return b
    }

    private static func computeBasePoints(han: Int, fu: Int, isYakuman: Bool, yakumanCount: Int) -> Int {
        if isYakuman { return 8000 * yakumanCount }
        if han >= 13 { return 8000 }
        if han >= 11 { return 6000 }
        if han >= 8  { return 4000 }
        if han >= 6  { return 3000 }
        if han >= 5  { return 2000 }
        // base = fu * 2^(han+2)，上限 mangan 2000
        let raw = Double(fu) * pow(2.0, Double(han + 2))
        return min(2000, Int(raw))
    }

    private static func scoreTitle(han: Int, fu: Int, isYakuman: Bool, yakumanCount: Int) -> String {
        if isYakuman { return yakumanCount > 1 ? "Multiple Yakuman" : "Yakuman" }
        if han >= 13 { return "Kazoe Yakuman" }
        if han >= 11 { return "Sanbaiman" }
        if han >= 8  { return "Baiman" }
        if han >= 6  { return "Haneman" }
        if han >= 5  { return "Mangan" }
        if han >= 4 && fu >= 40 { return "Mangan" }
        return "\(han) han \(fu) fu"
    }

    private static func distribute(base: Int,
                                   isTsumo: Bool,
                                   winner: Int,
                                   loser: Int?,
                                   dealerSeat: Int,
                                   isDealer: Bool,
                                   honba: Int,
                                   riichiSticks: Int) -> [Int: Int] {
        var pay: [Int: Int] = [:]
        let ceil100: (Double) -> Int = { Int(ceil($0 / 100.0)) * 100 }

        if isTsumo {
            if isDealer {
                let each = ceil100(Double(base) * 2.0)
                let total = each * 3
                pay[winner] = total + 100 * honba * 3 + riichiSticks * EchoConstants.riichiStickValue
                for s in 0..<4 where s != winner {
                    pay[s, default: 0] -= each + 100 * honba
                }
            } else {
                let dealerPay = ceil100(Double(base) * 2.0)
                let othersPay = ceil100(Double(base) * 1.0)
                let total = dealerPay + othersPay * 2
                pay[winner] = total + 100 * honba * 3 + riichiSticks * EchoConstants.riichiStickValue
                for s in 0..<4 where s != winner {
                    if s == dealerSeat { pay[s, default: 0] -= dealerPay + 100 * honba }
                    else                { pay[s, default: 0] -= othersPay + 100 * honba }
                }
            }
        } else if let loser = loser {
            let mul = isDealer ? 6.0 : 4.0
            let amount = ceil100(Double(base) * mul)
            pay[winner] = amount + 300 * honba + riichiSticks * EchoConstants.riichiStickValue
            pay[loser, default: 0] -= amount + 300 * honba
        }
        return pay
    }
}
