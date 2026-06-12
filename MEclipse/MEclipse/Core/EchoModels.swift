import Foundation
import Combine

// 牌用 struct，包含一个紧凑整数 code，便于排序与桶计数
struct EchoTile: Identifiable, Hashable, Codable {
    let id: UUID
    let suit: EchoSuit
    let rank: EchoRank
    let isAka: Bool

    init(suit: EchoSuit, rank: EchoRank, isAka: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.suit = suit
        self.rank = rank
        self.isAka = isAka
    }

    // 0..33 紧凑编码：m1-m9 = 0..8, p1-p9 = 9..17, s1-s9 = 18..26,
    // E S W N = 27..30, 白发中 = 31..33
    var code: Int {
        switch suit {
        case .man:    return (rank.rawValue - 1)
        case .pin:    return 9 + (rank.rawValue - 1)
        case .sou:    return 18 + (rank.rawValue - 1)
        case .wind:   return 27 + (rank.rawValue - 11)
        case .dragon: return 31 + (rank.rawValue - 21)
        }
    }

    var isHonor:    Bool { suit == .wind || suit == .dragon }
    var isTerminal: Bool {
        guard let n = rank.numeric else { return false }
        return n == 1 || n == 9
    }
    var isYaochuu:  Bool { isHonor || isTerminal }     // 幺九
    var isGreen:    Bool {
        // 绿一色用：s2 s3 s4 s6 s8 + 发
        if suit == .sou, let n = rank.numeric {
            return [2,3,4,6,8].contains(n)
        }
        return suit == .dragon && rank == .hatsu
    }

    func sameKind(as other: EchoTile) -> Bool {
        suit == other.suit && rank == other.rank
    }

    static func decode(_ code: Int) -> (EchoSuit, EchoRank)? {
        switch code {
        case 0...8:   return (.man, EchoRank(rawValue: code + 1)!)
        case 9...17:  return (.pin, EchoRank(rawValue: code - 9 + 1)!)
        case 18...26: return (.sou, EchoRank(rawValue: code - 18 + 1)!)
        case 27:      return (.wind, .east)
        case 28:      return (.wind, .south)
        case 29:      return (.wind, .west)
        case 30:      return (.wind, .north)
        case 31:      return (.dragon, .haku)
        case 32:      return (.dragon, .hatsu)
        case 33:      return (.dragon, .chun)
        default: return nil
        }
    }

    static func make(code: Int, isAka: Bool = false) -> EchoTile {
        let (s, r) = decode(code)!
        return EchoTile(suit: s, rank: r, isAka: isAka)
    }

    // 排序键
    static func < (lhs: EchoTile, rhs: EchoTile) -> Bool { lhs.code < rhs.code }
}

extension EchoTile: Comparable {}

struct EchoMeld: Identifiable, Codable {
    let id: UUID
    let kind: EchoMeldKind
    let tiles: [EchoTile]
    let claimedFrom: Int?           // 副露的来源（相对座位）-1=暗
    let claimedTileCode: Int?       // 副露牌的 code

    init(id: UUID = UUID(),
         kind: EchoMeldKind,
         tiles: [EchoTile],
         claimedFrom: Int? = nil,
         claimedTileCode: Int? = nil) {
        self.id = id
        self.kind = kind
        self.tiles = tiles
        self.claimedFrom = claimedFrom
        self.claimedTileCode = claimedTileCode
    }

    var isConcealed: Bool {
        switch kind {
        case .ankan, .pair, .triplet, .run: return true
        default: return false
        }
    }
}

// 玩家持有：手牌 / 副露 / 牌河 / 立直状态等
final class EchoPlayer: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let seat: Int
    let isHuman: Bool
    var displayName: String

    @Published var seatWind: EchoWind
    @Published var hand: [EchoTile] = []
    @Published var melds: [EchoMeld] = []
    @Published var pond:  [EchoTile] = []          // 牌河（按打出顺序）
    @Published var riichi: EchoRiichiStatus = .none
    @Published var ippatsuLive: Bool = false
    @Published var score: Int = EchoConstants.baseStartingScore
    @Published var lastDrawnId: UUID? = nil
    @Published var hasDeclaredFuriten: Bool = false

    init(seat: Int, isHuman: Bool, name: String, wind: EchoWind) {
        self.seat = seat
        self.isHuman = isHuman
        self.displayName = name
        self.seatWind = wind
    }

    func sortedHand() -> [EchoTile] {
        // 把刚摸的牌放最右，其它升序
        guard let lastId = lastDrawnId,
              let drawn = hand.first(where: { $0.id == lastId }) else {
            return hand.sorted()
        }
        let rest = hand.filter { $0.id != lastId }.sorted()
        return rest + [drawn]
    }

    func tilesByCode() -> [Int] {
        // 4 个面子最多 4 张，用 vector 表示
        var bucket = [Int](repeating: 0, count: 34)
        for t in hand { bucket[t.code] += 1 }
        return bucket
    }
}

// 用户在某次局面下选择的动作
struct EchoAction: Identifiable, Hashable {
    let id: UUID
    let kind: EchoActionKind
    let target: EchoTile?              // 触发牌（来自他家弃牌）
    let usingCodes: [Int]              // 副露所使用的本家手牌的 code 序列

    init(id: UUID = UUID(),
         kind: EchoActionKind,
         target: EchoTile? = nil,
         usingCodes: [Int] = []) {
        self.id = id
        self.kind = kind
        self.target = target
        self.usingCodes = usingCodes
    }
}

// 一个役条目，输出给 UI
struct EchoYaku: Identifiable, Hashable {
    let id: EchoYakuId
    let han: Int                       // 番数；役满记 13
    let isYakuman: Bool

    init(id: EchoYakuId, han: Int, isYakuman: Bool? = nil) {
        self.id = id
        self.han = han
        self.isYakuman = isYakuman ?? id.isYakuman
    }
}

struct EchoWinningHand {
    let concealed: [EchoTile]          // 暗手（含和牌）
    let melds:     [EchoMeld]
    let winTile:   EchoTile
    let isTsumo:   Bool

    var allTiles: [EchoTile] {
        concealed + melds.flatMap { $0.tiles }
    }

    func bucket34() -> [Int] {
        var b = [Int](repeating: 0, count: 34)
        for t in concealed { b[t.code] += 1 }
        for m in melds { for t in m.tiles { b[t.code] += 1 } }
        return b
    }
}

struct EchoRoundContext {
    let roundWind: EchoWind
    let seatWind:  EchoWind
    let isRiichi:  Bool
    let isDoubleRiichi: Bool
    let isIppatsu: Bool
    let isRinshan: Bool                // 岭上开花
    let isHaitei:  Bool                // 海底
    let isHoutei:  Bool                // 河底
    let isChankan: Bool                // 抢杠
    let isTenhou:  Bool
    let isChiihou: Bool
    let doraIndicators:   [EchoTile]
    let uraIndicators:    [EchoTile]
    let kandoraIndicators:[EchoTile]
    let isMenzen:  Bool                // 门清
    let honba:     Int
    let riichiSticks: Int
}

struct EchoScoreLineItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let label: String
    let han:   Int
    let isYakuman: Bool
}

struct EchoScoreResult {
    let yaku:        [EchoYaku]
    let dora:        Int
    let uradora:     Int
    let aka:         Int
    let totalHan:    Int
    let fu:          Int
    let basePoints:  Int
    let payment:     [Int: Int]        // seat -> delta
    let title:       String            // "Mangan", "Haneman", ...
    let summary:     [EchoScoreLineItem]
}
