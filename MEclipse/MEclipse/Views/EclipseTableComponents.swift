import SwiftUI

// 玩家手牌（弧形排列 — 用 .rotation3DEffect + 中心偏移模拟）
struct EclipseHandRow: View {
    @ObservedObject var player: EchoPlayer
    let canTap: Bool
    let onTap: (EchoTile) -> Void

    var body: some View {
        let tiles = player.sortedHand()
        return GeometryReader { geo in
            let count = max(1, tiles.count)
            // 留 16pt 给左右内边距，按可用宽度反推单牌尺寸，封顶用 Metric 设计值
            let available = geo.size.width - 16
            let gap = EclipseStyle.Metric.gap
            let widthByFit = (available - gap * CGFloat(count - 1)) / CGFloat(count)
            let tileW = max(20, min(EclipseStyle.Metric.tileWidth, widthByFit))
            let tileH = tileW * (EclipseStyle.Metric.tileHeight / EclipseStyle.Metric.tileWidth)

            HStack(spacing: gap) {
                ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tile in
                    let center = CGFloat(count - 1) / 2
                    let dx = CGFloat(idx) - center
                    Button {
                        if canTap { onTap(tile) }
                    } label: {
                        EclipseTileFace(tile: tile,
                                        width: tileW,
                                        height: tileH,
                                        isGlowing: tile.id == player.lastDrawnId)
                            .rotationEffect(.degrees(Double(dx) * 1.2))
                            .offset(y: abs(dx) * 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTap)
                }
            }
            .frame(width: geo.size.width, alignment: .center)
        }
        .frame(height: EclipseStyle.Metric.tileHeight + 14)
    }
}

// 对家 / 上下家手牌（背面）
enum EclipseSeatOrientation { case top, left, right }

struct EclipseOpponentRow: View {
    @ObservedObject var player: EchoPlayer
    let orientation: EclipseSeatOrientation
    var maxExtent: CGFloat = 220   // 横向时的可用宽度，纵向时的可用高度

    var body: some View {
        let count = max(1, player.hand.count)
        let gap: CGFloat = 1
        // 反推 small 尺寸：尽量贴近设计值，但保证 13 张能塞下
        let baseW = EclipseStyle.Metric.smallW
        let baseH = EclipseStyle.Metric.smallH
        let fitW = (maxExtent - gap * CGFloat(count - 1)) / CGFloat(count)
        let w = max(10, min(baseW, fitW))
        let h = w * (baseH / baseW)

        return Group {
            switch orientation {
            case .top:
                HStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        EclipseTileBack(width: w, height: h)
                    }
                }
            case .left:
                VStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        EclipseTileBack(width: w, height: h)
                            .rotationEffect(.degrees(90))
                            .frame(width: h, height: w)
                    }
                }
            case .right:
                VStack(spacing: gap) {
                    ForEach(0..<count, id: \.self) { _ in
                        EclipseTileBack(width: w, height: h)
                            .rotationEffect(.degrees(-90))
                            .frame(width: h, height: w)
                    }
                }
            }
        }
    }
}

// 副露区
struct EclipseMeldRow: View {
    let melds: [EchoMeld]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(melds) { m in
                HStack(spacing: 1) {
                    ForEach(Array(m.tiles.enumerated()), id: \.element.id) { i, t in
                        if m.kind == .ankan && (i == 0 || i == 3) {
                            EclipseTileBack(width: EclipseStyle.Metric.smallW + 2,
                                            height: EclipseStyle.Metric.smallH + 2)
                        } else {
                            EclipseTileFace(tile: t,
                                            width: EclipseStyle.Metric.smallW + 2,
                                            height: EclipseStyle.Metric.smallH + 2)
                        }
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.white.opacity(0.05))
                )
            }
        }
    }
}

// 牌河（每行 6 张，立直牌横置）
struct EclipsePondView: View {
    let pond: [EchoTile]
    let riichiTurn: Int?

    var body: some View {
        let cols = 6
        let chunks: [[(Int, EchoTile)]] = stride(from: 0, to: pond.count, by: cols).map {
            Array(zip($0..<min($0 + cols, pond.count), pond[$0..<min($0 + cols, pond.count)]))
        }
        VStack(alignment: .leading, spacing: EclipseStyle.Metric.pondGap) {
            ForEach(0..<chunks.count, id: \.self) { row in
                HStack(spacing: EclipseStyle.Metric.pondGap) {
                    ForEach(chunks[row], id: \.1.id) { idx, tile in
                        EclipseTileFace(tile: tile,
                                        width: EclipseStyle.Metric.smallW,
                                        height: EclipseStyle.Metric.smallH,
                                        rotated: riichiTurn == idx)
                            .frame(width: riichiTurn == idx ? EclipseStyle.Metric.smallH : EclipseStyle.Metric.smallW,
                                   height: riichiTurn == idx ? EclipseStyle.Metric.smallW : EclipseStyle.Metric.smallH)
                    }
                }
            }
        }
    }
}

// 圆环操作菜单
struct EclipseClaimRing: View {
    let actions: [EchoAction]
    let countdown: Double
    let onPick: (EchoAction) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(actions) { act in
                    Button {
                        onPick(act)
                        EchoEffectManager.shared.cue(.button)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: iconFor(act.kind))
                                .font(.system(size: 18, weight: .black))
                            Text(label(for: act.kind))
                                .font(EclipseStyle.Typography.neon(11))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 56)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [
                                    color(for: act.kind),
                                    color(for: act.kind).opacity(0.4)
                                ], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            Circle().stroke(.white.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: color(for: act.kind).opacity(0.7), radius: 10)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onSkip) {
                    Text("Skip")
                        .font(EclipseStyle.Typography.neon(13))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 56)
                        .background(Circle().fill(.white.opacity(0.18)))
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            // 进度条
            GeometryReader { geo in
                let pct = max(0, min(1, countdown / EchoConstants.claimTimeoutSeconds))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(LinearGradient(colors: [
                        EclipseStyle.current.pulseA, EclipseStyle.current.pulseB
                    ], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * pct)
                }
                .frame(height: 4)
            }
            .frame(height: 4)
        }
    }

    private func iconFor(_ k: EchoActionKind) -> String {
        switch k {
        case .ron, .tsumo:    return "flame.fill"
        case .pon:            return "circle.grid.2x2.fill"
        case .chi:            return "arrow.up.left.and.arrow.down.right"
        case .ankan:          return "rectangle.stack.badge.plus"
        case .minkan:         return "rectangle.stack.fill"
        case .kakan:          return "plus.rectangle.on.rectangle"
        case .riichi:         return "bolt.fill"
        case .skip:           return "forward.fill"
        }
    }

    private func label(for k: EchoActionKind) -> String {
        switch k {
        case .ron:    return "Ron"
        case .tsumo:  return "Tsumo"
        case .pon:    return "Pon"
        case .chi:    return "Chi"
        case .ankan:  return "Ankan"
        case .minkan: return "Minkan"
        case .kakan:  return "Kakan"
        case .riichi: return "Riichi"
        case .skip:   return "Skip"
        }
    }

    private func color(for k: EchoActionKind) -> Color {
        switch k {
        case .ron, .tsumo: return EclipseStyle.current.bloodRed
        case .riichi:      return EclipseStyle.current.halo
        case .pon, .minkan, .kakan, .ankan: return EclipseStyle.current.pulseA
        case .chi:         return EclipseStyle.current.pulseB
        case .skip:        return .gray
        }
    }
}

// 宝牌指示器面板
struct EclipseDoraPanel: View {
    let indicators: [EchoTile]
    let kandoraIndicators: [EchoTile]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DORA")
                .font(EclipseStyle.Typography.neon(10))
                .foregroundStyle(EclipseStyle.current.halo)
            HStack(spacing: 2) {
                ForEach(indicators) { t in
                    EclipseTileFace(tile: t,
                                    width: EclipseStyle.Metric.smallW,
                                    height: EclipseStyle.Metric.smallH)
                }
                ForEach(0..<(EchoConstants.maxDoraIndicators - indicators.count), id: \.self) { _ in
                    EclipseTileBack(width: EclipseStyle.Metric.smallW,
                                    height: EclipseStyle.Metric.smallH)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EclipseStyle.current.halo.opacity(0.45), lineWidth: 0.8)
        )
    }
}

// 中央立直棒
struct EclipseRiichiSticks: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule()
                    .fill(LinearGradient(colors: [
                        Color(red: 0.97, green: 0.95, blue: 0.86),
                        Color(red: 0.74, green: 0.66, blue: 0.46)
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 38, height: 5)
                    .overlay(
                        Capsule()
                            .fill(EclipseStyle.current.bloodRed)
                            .frame(width: 4, height: 4)
                    )
                    .shadow(color: EclipseStyle.current.halo.opacity(0.5), radius: 3)
            }
        }
    }
}

// 玩家信息条（座位、风、点数、立直）
struct EclipseSeatTag: View {
    let name: String
    let wind: EchoWind
    let score: Int
    let riichi: EchoRiichiStatus
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(wind.nameJP)
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundStyle(EclipseStyle.current.halo)
                Text(name)
                    .font(EclipseStyle.Typography.label(11))
                    .foregroundStyle(.white.opacity(0.92))
                if riichi == .active || riichi == .doubleRiichi {
                    Text("R")
                        .font(EclipseStyle.Typography.neon(10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(EclipseStyle.current.bloodRed))
                }
            }
            Text("\(score)")
                .font(EclipseStyle.Typography.neon(13))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(isCurrent ? 0.6 : 0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? EclipseStyle.current.pulseA : .white.opacity(0.18),
                         lineWidth: isCurrent ? 1.2 : 0.6)
        )
    }
}
