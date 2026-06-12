import Foundation

// 花色用整数 raw 便于后续做位运算 / 桶排序
enum EchoSuit: Int, CaseIterable, Codable {
    case man    = 0   // 万
    case pin    = 1   // 筒
    case sou    = 2   // 索 / 条
    case wind   = 3
    case dragon = 4

    var isNumeric: Bool {
        self == .man || self == .pin || self == .sou
    }

    var letterCode: String {
        switch self {
        case .man:    return "m"
        case .pin:    return "p"
        case .sou:    return "s"
        case .wind:   return "w"
        case .dragon: return "d"
        }
    }
}

// 用 Int rank（1..9 数牌，11..14 风，21..23 三元），方便做向听计算
enum EchoRank: Int, Codable, Hashable {
    case n1 = 1, n2, n3, n4, n5, n6, n7, n8, n9
    case east  = 11, south, west, north
    case haku  = 21   // 白
    case hatsu = 22   // 发
    case chun  = 23   // 中

    var numeric: Int? {
        let raw = rawValue
        return (1...9).contains(raw) ? raw : nil
    }
}

enum EchoWind: Int, CaseIterable, Codable {
    case east  = 0
    case south = 1
    case west  = 2
    case north = 3

    var rank: EchoRank {
        switch self {
        case .east:  return .east
        case .south: return .south
        case .west:  return .west
        case .north: return .north
        }
    }

    var nameEN: String {
        ["East", "South", "West", "North"][rawValue]
    }
    var nameJP: String {
        ["東", "南", "西", "北"][rawValue]
    }
}

enum EchoActionKind: String, CaseIterable, Codable {
    case chi
    case pon
    case ankan         // 暗杠
    case minkan        // 大明杠
    case kakan         // 加杠
    case ron
    case tsumo
    case riichi
    case skip
}

enum EchoMeldKind: String, Codable {
    case chi
    case pon
    case ankan
    case minkan
    case kakan
    case pair
    case run
    case triplet
}

enum EchoGamePhase: String {
    case bootstrap
    case dealing
    case draw           // 玩家刚摸牌
    case discard        // 等待打牌
    case awaitingClaim  // 弃牌后等待副露/和
    case scoring
    case roundOver
    case matchOver
}

enum EchoRiichiStatus: String, Codable {
    case none
    case declaring     // 当前回合宣言中（点棒未落桌）
    case active        // 立直生效
    case doubleRiichi
}

enum EchoDifficulty: String, CaseIterable, Codable {
    case relaxed
    case balanced
    case lethal

    var label: String {
        switch self {
        case .relaxed:  return "Crescent"
        case .balanced: return "Penumbra"
        case .lethal:   return "Totality"
        }
    }
}

// 役 ID 用 enum 而非字符串，便于 switch 完整性检测
enum EchoYakuId: String, CaseIterable, Codable {
    // 1 翻
    case riichi
    case ippatsu
    case menzenTsumo
    case tanyao
    case pinfu
    case yakuhaiSeat
    case yakuhaiRound
    case yakuhaiHaku
    case yakuhaiHatsu
    case yakuhaiChun
    case iipeiko
    // 2 翻
    case doubleRiichi
    case sanshokuDoujun
    case ittsuu
    case chanta
    case toitoi
    case sanankou
    case sanshokuDoukou
    case sankantsu
    case chiitoitsu
    case honroutou
    case shousangen
    // 3 翻 / 6 翻
    case junchan
    case ryanpeikou
    case honitsu
    case chinitsu
    // 役满
    case kokushi
    case suuankou
    case daisangen
    case chinroutou
    case ryuuiisou
    case tsuuiisou
    case shousuushii
    case daisuushii
    case suukantsu
    case chuurenpoutou

    var isYakuman: Bool {
        switch self {
        case .kokushi, .suuankou, .daisangen, .chinroutou, .ryuuiisou, .tsuuiisou,
             .shousuushii, .daisuushii, .suukantsu, .chuurenpoutou:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .riichi:          return "Riichi"
        case .ippatsu:         return "Ippatsu"
        case .menzenTsumo:     return "Menzen Tsumo"
        case .tanyao:          return "Tanyao"
        case .pinfu:           return "Pinfu"
        case .yakuhaiSeat:     return "Yakuhai (Seat)"
        case .yakuhaiRound:    return "Yakuhai (Round)"
        case .yakuhaiHaku:     return "Yakuhai Haku"
        case .yakuhaiHatsu:    return "Yakuhai Hatsu"
        case .yakuhaiChun:     return "Yakuhai Chun"
        case .iipeiko:         return "Iipeiko"
        case .doubleRiichi:    return "Double Riichi"
        case .sanshokuDoujun:  return "Sanshoku Doujun"
        case .ittsuu:          return "Ittsuu"
        case .chanta:          return "Chanta"
        case .toitoi:          return "Toitoi"
        case .sanankou:        return "Sanankou"
        case .sanshokuDoukou:  return "Sanshoku Doukou"
        case .sankantsu:       return "Sankantsu"
        case .chiitoitsu:      return "Chiitoitsu"
        case .honroutou:       return "Honroutou"
        case .shousangen:      return "Shousangen"
        case .junchan:         return "Junchan"
        case .ryanpeikou:      return "Ryanpeikou"
        case .honitsu:         return "Honitsu"
        case .chinitsu:        return "Chinitsu"
        case .kokushi:         return "Kokushi Musou"
        case .suuankou:        return "Suu Ankou"
        case .daisangen:       return "Daisangen"
        case .chinroutou:      return "Chinroutou"
        case .ryuuiisou:       return "Ryuuiisou"
        case .tsuuiisou:       return "Tsuuiisou"
        case .shousuushii:     return "Shousuushii"
        case .daisuushii:      return "Daisuushii"
        case .suukantsu:       return "Suukantsu"
        case .chuurenpoutou:   return "Chuuren Poutou"
        }
    }
}
