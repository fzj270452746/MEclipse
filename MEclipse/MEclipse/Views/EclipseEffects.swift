import SwiftUI

// 星空背景：多层星点 + 偶发流星 + 月食圆环
struct EclipseStarfield: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                Self.drawLayered(gc, size: size, t: t)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private static func drawLayered(_ gc: GraphicsContext, size: CGSize, t: TimeInterval) {
        let starColors: [Color] = [
            EclipseStyle.current.glint.opacity(0.65),
            EclipseStyle.current.pulseA.opacity(0.55),
            EclipseStyle.current.pulseB.opacity(0.55),
            EclipseStyle.current.halo.opacity(0.65),
            .white.opacity(0.7)
        ]

        // 远景小星 (静)
        for i in 0..<140 {
            let seed = Double(i)
            let x = Self.fract(sin(seed * 12.9898) * 43758.5453) * Double(size.width)
            let y = Self.fract(cos(seed * 78.233)  * 43758.5453) * Double(size.height)
            let blink = (sin(t * 1.6 + seed) * 0.5 + 0.5) * 0.7
            let r = 0.6 + blink * 0.6
            let color = starColors[i % starColors.count]
            gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(color))
        }

        // 中景星
        for i in 0..<46 {
            let seed = Double(i) * 1.7
            let x = Self.fract(sin(seed * 92.18) * 11357.91) * Double(size.width)
            let y0 = Self.fract(cos(seed * 33.71) * 60913.77) * Double(size.height)
            let drift = (t * 6.0).truncatingRemainder(dividingBy: Double(size.height))
            let y = (y0 + drift).truncatingRemainder(dividingBy: Double(size.height))
            let r = 1.2 + (sin(t * 0.8 + seed) * 0.5 + 0.5) * 1.4
            let color = starColors[i % starColors.count]
            gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                    with: .color(color))
        }

        // 月食圆环（偏右上角）
        let ringCx = Double(size.width) * 0.78
        let ringCy = Double(size.height) * 0.16
        let ringR  = 70.0 + sin(t * 0.4) * 6.0
        let ringRect = CGRect(x: ringCx - ringR, y: ringCy - ringR,
                              width: ringR * 2, height: ringR * 2)
        gc.stroke(Path(ellipseIn: ringRect),
                  with: .color(EclipseStyle.current.halo.opacity(0.16)),
                  lineWidth: 1.4)
        gc.stroke(Path(ellipseIn: ringRect.insetBy(dx: 6, dy: 6)),
                  with: .color(EclipseStyle.current.pulseA.opacity(0.10)),
                  lineWidth: 1.0)
    }

    private static func fract(_ x: Double) -> Double {
        x - floor(x)
    }
}

// 烟花粒子层（胡牌时触发）
struct EclipseFireworkLayer: View {
    let trigger: UUID?

    @State private var bursts: [Burst] = []

    struct Burst: Identifiable {
        let id = UUID()
        let center: CGPoint
        let palette: [Color]
        let createdAt: Date
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let now = ctx.date
                Canvas { gc, _ in
                    Self.renderBursts(gc, bursts: bursts, now: now)
                }
            }
            .onChange(of: trigger) { newVal in
                guard newVal != nil else { return }
                let palette: [Color] = [
                    EclipseStyle.current.halo,
                    EclipseStyle.current.pulseA,
                    EclipseStyle.current.pulseB,
                    EclipseStyle.current.glint
                ]
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                bursts.append(Burst(center: center,
                                    palette: palette,
                                    createdAt: Date()))
                if bursts.count > 6 { bursts.removeFirst() }
            }
        }
        .allowsHitTesting(false)
    }

    private static func renderBursts(_ gc: GraphicsContext, bursts: [Burst], now: Date) {
        for b in bursts {
            let elapsed = now.timeIntervalSince(b.createdAt)
            if elapsed > 1.6 { continue }
            let alpha = max(0, 1 - elapsed / 1.6)
            for i in 0..<28 {
                let angle: Double = Double(i) / 28.0 * .pi * 2
                let dist:  Double = elapsed * 220
                let cx: Double = Double(b.center.x)
                let cy: Double = Double(b.center.y)
                let x: Double = cx + cos(angle) * dist
                let yBase: Double = cy + sin(angle) * dist
                let yDrop: Double = (elapsed * elapsed) * 80
                let y: Double = yBase + yDrop
                let r: Double = 2.5 * (1 - elapsed / 1.6)
                let color: Color = b.palette[i % b.palette.count].opacity(alpha)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                gc.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

// 役满龙形粒子（更夸张）
struct EclipseDragonRibbon: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                Canvas { gc, size in
                    guard isActive else { return }
                    let mid = Double(size.height) / 2
                    let amp = Double(size.height) * 0.22
                    var p = Path()
                    let segs = 80
                    let dx = Double(size.width) / Double(segs)
                    for i in 0...segs {
                        let x = Double(i) * dx
                        let phase = x * 0.025 + t * 1.4
                        let y = mid + sin(phase) * amp
                        if i == 0 { p.move(to: .init(x: x, y: y)) }
                        else { p.addLine(to: .init(x: x, y: y)) }
                    }
                    gc.stroke(p, with: .linearGradient(
                                Gradient(colors: [
                                    EclipseStyle.current.halo,
                                    EclipseStyle.current.bloodRed,
                                    EclipseStyle.current.pulseA
                                ]),
                                startPoint: .zero,
                                endPoint: .init(x: size.width, y: 0)),
                              lineWidth: 6)
                    // dot scales
                    for i in 0...segs {
                        let x = Double(i) * dx
                        let phase = x * 0.025 + t * 1.4
                        let y = mid + sin(phase) * amp
                        gc.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3,
                                                       width: 6, height: 6)),
                                with: .color(EclipseStyle.current.halo))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// 立直暗闪：全屏淡入淡出红色蒙版
struct EclipseRiichiFlash: View {
    @Binding var trigger: Bool

    var body: some View {
        Rectangle()
            .fill(EclipseStyle.current.bloodRed.opacity(trigger ? 0.4 : 0))
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.6), value: trigger)
            .onChange(of: trigger) { newVal in
                if newVal {
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await MainActor.run { trigger = false }
                    }
                }
            }
    }
}

// 呼吸光（AI 思考时）
struct EclipseBreathFrame: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let pulse = sin(t * 2.4) * 0.5 + 0.5
                RoundedRectangle(cornerRadius: 24)
                    .stroke(EclipseStyle.current.pulseA.opacity(isActive ? 0.4 + pulse * 0.4 : 0),
                             lineWidth: 2)
                    .blur(radius: 1.4)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .shadow(color: EclipseStyle.current.pulseA.opacity(isActive ? 0.5 : 0), radius: 14)
            }
        }
        .allowsHitTesting(false)
    }
}

// 分数飘字（+/- ）
struct EclipseFloatingNumber: View {
    let amount: Int
    @State private var offset: CGFloat = 0
    @State private var alpha: Double = 1

    var body: some View {
        Text(amount > 0 ? "+\(amount)" : "\(amount)")
            .font(EclipseStyle.Typography.neon(20))
            .foregroundStyle(amount > 0 ? EclipseStyle.current.halo : EclipseStyle.current.bloodRed)
            .offset(y: offset)
            .opacity(alpha)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    offset = -36
                    alpha = 0
                }
            }
    }
}

// 简单音效占位（真实工程可用 AVAudioEngine；这里用 nop）
final class EchoEffectManager {
    static let shared = EchoEffectManager()
    private init() {}

    @discardableResult
    func cue(_ kind: Cue) -> Bool {
        // 真机里这里可触发 haptic / sfx
        return true
    }

    enum Cue { case discard, claim, riichi, agari, yakuman, button }
}
