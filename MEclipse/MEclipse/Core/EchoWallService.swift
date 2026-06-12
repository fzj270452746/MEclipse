import Foundation

// 牌墙服务对象。按职责拆分：洗牌 / 抽牌 / 王牌区 / 宝牌指示
final class EchoWallService {

    private(set) var liveWall:    [EchoTile] = []
    private(set) var deadWall:    [EchoTile] = []
    private(set) var doraIndicators:   [EchoTile] = []
    private(set) var uraIndicators:    [EchoTile] = []
    private(set) var kandoraIndicators:[EchoTile] = []

    private var rinshanIdx: Int = 0
    private var doraReveal: Int = 0

    var liveCount: Int { liveWall.count }
    var canDrawRinshan: Bool { rinshanIdx < 4 }

    func reset(seed: UInt64? = nil) {
        var pool: [EchoTile] = []
        // 0..33 的 code，每个 4 张
        for code in 0..<34 {
            for _ in 0..<4 {
                pool.append(EchoTile.make(code: code))
            }
        }
        var rng: any RandomNumberGenerator = seed.map { LCGRandom(seed: $0) } ?? SystemRandomNumberGenerator()
        for i in stride(from: pool.count - 1, through: 1, by: -1) {
            let j = Int(rng.next(upperBound: UInt64(i + 1)))
            pool.swapAt(i, j)
        }

        // 王牌区固定 14 张
        deadWall = Array(pool.suffix(14))
        liveWall = Array(pool.prefix(pool.count - 14))

        // 宝牌指示：deadWall 第 5 张（index 4）
        doraReveal = 0
        rinshanIdx = 0
        revealNextDora()
    }

    func drawNormal() -> EchoTile? {
        guard !liveWall.isEmpty else { return nil }
        return liveWall.removeFirst()
    }

    func drawRinshan() -> EchoTile? {
        guard canDrawRinshan else { return nil }
        let t = deadWall[rinshanIdx]
        rinshanIdx += 1
        return t
    }

    @discardableResult
    func revealNextDora() -> EchoTile? {
        // 把已揭示的索引下移：5 7 9 11 13
        let positions = [4, 6, 8, 10, 12]
        guard doraReveal < positions.count else { return nil }
        let p = positions[doraReveal]
        let dora = deadWall[p]
        let ura  = deadWall[p + 1]
        if doraReveal == 0 {
            doraIndicators.append(dora)
            uraIndicators.append(ura)
        } else {
            kandoraIndicators.append(dora)
            uraIndicators.append(ura)
            doraIndicators.append(dora)
        }
        doraReveal += 1
        return dora
    }

    static func doraTile(forIndicator t: EchoTile) -> EchoTile {
        // 数牌：1->2, 2->3 ... 9->1
        // 风  ：东->南->西->北->东
        // 三元：白->发->中->白
        switch t.suit {
        case .man, .pin, .sou:
            let n = t.rank.numeric ?? 0
            let next = (n % 9) + 1
            let r = EchoRank(rawValue: next)!
            return EchoTile(suit: t.suit, rank: r)
        case .wind:
            let order: [EchoRank] = [.east, .south, .west, .north]
            let i = order.firstIndex(of: t.rank) ?? 0
            return EchoTile(suit: .wind, rank: order[(i + 1) % 4])
        case .dragon:
            let order: [EchoRank] = [.haku, .hatsu, .chun]
            let i = order.firstIndex(of: t.rank) ?? 0
            return EchoTile(suit: .dragon, rank: order[(i + 1) % 3])
        }
    }
}

// LCG，给重放/确定性洗牌用。系统 RNG 的子集替代品
struct LCGRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xC1A0_BABE_F00D : seed }

    mutating func next() -> UInt64 {
        state = state &* 2862933555777941757 &+ 3037000493
        return state
    }
}
