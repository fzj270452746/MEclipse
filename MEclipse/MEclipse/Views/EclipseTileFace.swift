import SwiftUI

// 牌正面 — 风格：象牙底色 + 哥特墨边 + 颜色按花色区分
struct EclipseTileFace: View {
    let tile: EchoTile
    var width:  CGFloat = EclipseStyle.Metric.tileWidth
    var height: CGFloat = EclipseStyle.Metric.tileHeight
    var isGlowing: Bool = false
    var isAka: Bool = false
    var rotated: Bool = false   // 横置（立直牌）

    var body: some View {
        let frame = CGSize(width: width, height: height)
        return Group {
            ZStack {
                base
                content
                if isAka { redOverlay }
                if isGlowing { glowOverlay }
            }
            .frame(width: frame.width, height: frame.height)
            .rotationEffect(.degrees(rotated ? -90 : 0))
        }
    }

    private var base: some View {
        ZStack {
            // 厚度
            RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius + 1.5)
                .fill(LinearGradient(colors: [
                    Color(red: 0.86, green: 0.78, blue: 0.55),
                    Color(red: 0.58, green: 0.50, blue: 0.27)
                ], startPoint: .top, endPoint: .bottom))
                .offset(y: 2.6)
                .blur(radius: 0.4)

            // 表面
            RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius)
                .fill(EclipseStyle.ivorySurface)
                .overlay(
                    RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius)
                        .stroke(EclipseStyle.current.bambooEdge, lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 2)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tile.suit {
        case .man:    manFace
        case .pin:    pinFace
        case .sou:    souFace
        case .wind:   windFace
        case .dragon: dragonFace
        }
    }

    // 万字
    @ViewBuilder
    private var manFace: some View {
        VStack(spacing: 0) {
            Text(numericKanji)
                .font(EclipseStyle.Typography.tile(width * 0.40))
                .foregroundStyle(EclipseStyle.current.bloodRed)
            Text("萬")
                .font(.system(size: width * 0.34, weight: .black, design: .serif))
                .foregroundStyle(EclipseStyle.current.inkBlack)
                .padding(.bottom, 2)
        }
    }

    // 筒：n 个嵌套圆
    @ViewBuilder
    private var pinFace: some View {
        let n = tile.rank.numeric ?? 0
        EclipsePinCluster(count: n)
            .frame(width: width * 0.78, height: height * 0.78)
    }

    // 索：竹节阵列；1s 用螃蟹/孔雀简化造型
    @ViewBuilder
    private var souFace: some View {
        let n = tile.rank.numeric ?? 0
        if n == 1 {
            EclipsePeacockShape()
                .fill(LinearGradient(colors: [
                    EclipseStyle.current.leafGreen,
                    EclipseStyle.current.skyBlue
                ], startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(width: width * 0.65, height: height * 0.72)
        } else {
            EclipseSouLattice(count: n)
                .frame(width: width * 0.78, height: height * 0.82)
        }
    }

    // 风牌
    @ViewBuilder
    private var windFace: some View {
        let kanji: String = {
            switch tile.rank {
            case .east:  return "東"
            case .south: return "南"
            case .west:  return "西"
            case .north: return "北"
            default: return "?"
            }
        }()
        Text(kanji)
            .font(.system(size: width * 0.62, weight: .black, design: .serif))
            .foregroundStyle(EclipseStyle.current.inkBlack)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(EclipseStyle.current.inkBlack.opacity(0.4), lineWidth: 0.6)
                    .padding(width * 0.10)
            )
    }

    // 三元
    @ViewBuilder
    private var dragonFace: some View {
        switch tile.rank {
        case .haku:
            // 白：双框
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(EclipseStyle.current.skyBlue, lineWidth: 1.4)
                    .padding(width * 0.18)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(EclipseStyle.current.skyBlue.opacity(0.4), lineWidth: 0.6)
                    .padding(width * 0.10)
            }
        case .hatsu:
            Text("發")
                .font(.system(size: width * 0.62, weight: .black, design: .serif))
                .foregroundStyle(EclipseStyle.current.leafGreen)
        case .chun:
            Text("中")
                .font(.system(size: width * 0.62, weight: .black, design: .serif))
                .foregroundStyle(EclipseStyle.current.bloodRed)
        default:
            EmptyView()
        }
    }

    private var redOverlay: some View {
        RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius)
            .stroke(EclipseStyle.current.bloodRed, lineWidth: 1.8)
            .shadow(color: EclipseStyle.current.bloodRed, radius: 4)
    }

    private var glowOverlay: some View {
        RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius)
            .stroke(LinearGradient(colors: [
                EclipseStyle.current.pulseB,
                EclipseStyle.current.pulseA
            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.2)
            .shadow(color: EclipseStyle.current.pulseA.opacity(0.7), radius: 6)
    }

    private var numericKanji: String {
        let n = tile.rank.numeric ?? 0
        let arr = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        return arr[n]
    }
}

struct EclipsePinCluster: View {
    let count: Int

    var body: some View {
        GeometryReader { geo in
            let pts = positions(count: count, in: geo.size)
            ZStack {
                ForEach(pts.indices, id: \.self) { i in
                    let p = pts[i]
                    pinDot(index: i)
                        .frame(width: geo.size.width * 0.22,
                               height: geo.size.width * 0.22)
                        .position(p)
                }
            }
        }
    }

    @ViewBuilder
    private func pinDot(index: Int) -> some View {
        let pal: [[Color]] = [
            [EclipseStyle.current.bloodRed,  Color(red: 0.62, green: 0.07, blue: 0.10)],
            [EclipseStyle.current.skyBlue,   Color(red: 0.04, green: 0.18, blue: 0.42)],
            [EclipseStyle.current.leafGreen, Color(red: 0.04, green: 0.32, blue: 0.18)],
            [EclipseStyle.current.halo,      Color(red: 0.66, green: 0.42, blue: 0.06)]
        ]
        let colors = pal[index % pal.count]
        ZStack {
            Circle().fill(RadialGradient(colors: colors,
                                         center: .topLeading,
                                         startRadius: 1, endRadius: 14))
            Circle().stroke(.white.opacity(0.6), lineWidth: 0.8)
            Circle().fill(.white.opacity(0.3)).scaleEffect(0.36).offset(x: -3, y: -3)
        }
    }

    private func positions(count: Int, in s: CGSize) -> [CGPoint] {
        let w = s.width, h = s.height
        switch count {
        case 1: return [.init(x: w/2, y: h/2)]
        case 2: return [.init(x: w/2, y: h*0.30), .init(x: w/2, y: h*0.70)]
        case 3: return [
            .init(x: w*0.25, y: h*0.25),
            .init(x: w/2,    y: h/2),
            .init(x: w*0.75, y: h*0.75)]
        case 4: return [
            .init(x: w*0.30, y: h*0.30), .init(x: w*0.70, y: h*0.30),
            .init(x: w*0.30, y: h*0.70), .init(x: w*0.70, y: h*0.70)]
        case 5: return [
            .init(x: w*0.28, y: h*0.28), .init(x: w*0.72, y: h*0.28),
            .init(x: w/2,    y: h/2),
            .init(x: w*0.28, y: h*0.72), .init(x: w*0.72, y: h*0.72)]
        case 6: return [
            .init(x: w*0.28, y: h*0.18), .init(x: w*0.72, y: h*0.18),
            .init(x: w*0.28, y: h*0.50), .init(x: w*0.72, y: h*0.50),
            .init(x: w*0.28, y: h*0.82), .init(x: w*0.72, y: h*0.82)]
        case 7: return [
            .init(x: w*0.20, y: h*0.18), .init(x: w*0.50, y: h*0.18), .init(x: w*0.80, y: h*0.18),
            .init(x: w*0.32, y: h*0.50), .init(x: w*0.68, y: h*0.50),
            .init(x: w*0.30, y: h*0.82), .init(x: w*0.70, y: h*0.82)]
        case 8: return [
            .init(x: w*0.22, y: h*0.18), .init(x: w*0.78, y: h*0.18),
            .init(x: w*0.22, y: h*0.42), .init(x: w*0.78, y: h*0.42),
            .init(x: w*0.22, y: h*0.62), .init(x: w*0.78, y: h*0.62),
            .init(x: w*0.22, y: h*0.86), .init(x: w*0.78, y: h*0.86)]
        case 9: return [
            .init(x: w*0.22, y: h*0.20), .init(x: w*0.50, y: h*0.20), .init(x: w*0.78, y: h*0.20),
            .init(x: w*0.22, y: h*0.50), .init(x: w*0.50, y: h*0.50), .init(x: w*0.78, y: h*0.50),
            .init(x: w*0.22, y: h*0.80), .init(x: w*0.50, y: h*0.80), .init(x: w*0.78, y: h*0.80)]
        default: return []
        }
    }
}

struct EclipseSouLattice: View {
    let count: Int

    var body: some View {
        GeometryReader { geo in
            let cols = (count <= 4) ? 2 : 3
            let rows = Int(ceil(Double(count) / Double(cols)))
            let cellW = geo.size.width / CGFloat(cols)
            let cellH = geo.size.height / CGFloat(rows)
            let stickW = cellW * 0.34
            let stickH = cellH * 0.78
            ForEach(0..<count, id: \.self) { i in
                let col = i % cols
                let row = i / cols
                EclipseBambooNode()
                    .fill(LinearGradient(colors: [
                        EclipseStyle.current.leafGreen,
                        Color(red: 0.04, green: 0.30, blue: 0.16)
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(width: stickW, height: stickH)
                    .position(x: (CGFloat(col) + 0.5) * cellW,
                              y: (CGFloat(row) + 0.5) * cellH)
            }
        }
    }
}

struct EclipseBambooNode: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width / 2, height: rect.width / 2))
        // 三个节
        let segments = 3
        for i in 1..<segments {
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(segments)
            p.move(to: .init(x: rect.minX + rect.width * 0.18, y: y))
            p.addLine(to: .init(x: rect.maxX - rect.width * 0.18, y: y))
        }
        return p
    }
}

// 1s：孔雀／鸟形（与 Spark 的小鸟轮廓不同：尾羽更长、立姿）
struct EclipsePeacockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // 身体
        p.addEllipse(in: CGRect(x: rect.minX + w*0.30, y: rect.minY + h*0.42,
                                 width: w*0.34, height: h*0.32))
        // 头
        p.addEllipse(in: CGRect(x: rect.minX + w*0.50, y: rect.minY + h*0.18,
                                 width: w*0.18, height: h*0.18))
        // 嘴
        p.move(to: .init(x: rect.minX + w*0.66, y: rect.minY + h*0.27))
        p.addLine(to: .init(x: rect.minX + w*0.84, y: rect.minY + h*0.30))
        p.addLine(to: .init(x: rect.minX + w*0.66, y: rect.minY + h*0.34))
        p.closeSubpath()
        // 尾巴 (上扬 3 根)
        for i in 0..<3 {
            let baseX = rect.minX + w * (0.30 - CGFloat(i) * 0.06)
            let baseY = rect.minY + h * (0.50 + CGFloat(i) * 0.04)
            p.move(to: .init(x: baseX, y: baseY))
            p.addQuadCurve(to: .init(x: rect.minX + w * (0.06 - CGFloat(i) * 0.02),
                                     y: rect.minY + h * (0.20 + CGFloat(i) * 0.10)),
                           control: .init(x: rect.minX + w*0.10,
                                          y: rect.minY + h*(0.10 + CGFloat(i)*0.04)))
        }
        // 脚
        p.move(to: .init(x: rect.minX + w*0.42, y: rect.minY + h*0.74))
        p.addLine(to: .init(x: rect.minX + w*0.40, y: rect.minY + h*0.92))
        p.move(to: .init(x: rect.minX + w*0.54, y: rect.minY + h*0.74))
        p.addLine(to: .init(x: rect.minX + w*0.56, y: rect.minY + h*0.92))
        return p
    }
}

// 牌背 — 黑紫菱形格 + 霓虹线条（区别于 Spark 的对角条纹）
struct EclipseTileBack: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius + 1.4)
                .fill(LinearGradient(colors: [
                    Color(red: 0.16, green: 0.08, blue: 0.30),
                    Color(red: 0.04, green: 0.02, blue: 0.10)
                ], startPoint: .top, endPoint: .bottom))
                .offset(y: 2.4)

            RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius)
                .fill(LinearGradient(colors: [
                    Color(red: 0.20, green: 0.10, blue: 0.42),
                    Color(red: 0.06, green: 0.03, blue: 0.18)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))

            EclipseDiamondLattice()
                .stroke(EclipseStyle.current.halo.opacity(0.16), lineWidth: 0.6)

            RoundedRectangle(cornerRadius: EclipseStyle.Metric.radius)
                .stroke(LinearGradient(colors: [
                    EclipseStyle.current.pulseB.opacity(0.85),
                    EclipseStyle.current.pulseA.opacity(0.5)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1.0)
                .shadow(color: EclipseStyle.current.pulseA.opacity(0.4), radius: 3)
        }
        .frame(width: width, height: height)
    }
}

struct EclipseDiamondLattice: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 8
        var x: CGFloat = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            p.move(to: .init(x: x, y: rect.minY))
            p.addLine(to: .init(x: x + rect.height, y: rect.maxY))
            p.move(to: .init(x: x, y: rect.maxY))
            p.addLine(to: .init(x: x + rect.height, y: rect.minY))
            x += step
        }
        return p
    }
}
