import SwiftUI

// 桌面主视图（横屏布局）
struct EclipseGameView: View {
    @ObservedObject var engine: EchoGameEngine
    let onExit: () -> Void

    @State private var tableYaw: Double = 0
    @State private var lastDragX: CGFloat = 0
    @State private var riichiFlash: Bool = false

    // 区域高度比例（按总高度切分）
    private let topBarRatio:    CGFloat = 0.10
    private let topPlayerRatio: CGFloat = 0.16
    private let bottomRatio:    CGFloat = 0.32

    var body: some View {
        ZStack {
            EclipseStyle.screenGradient.ignoresSafeArea()
            EclipseStarfield()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let topBarH    = max(36, h * topBarRatio)
                let topPlayerH = max(60, h * topPlayerRatio)
                let bottomH    = max(110, h * bottomRatio)
                let middleH    = max(80, h - topBarH - topPlayerH - bottomH)

                VStack(spacing: 4) {
                    topBar
                        .frame(height: topBarH)
                    seatRow(seatIndex: 2, width: w * 0.66)
                        .frame(height: topPlayerH)
                    middleRow(height: middleH, width: w)
                        .frame(height: middleH)
                    bottomRow(width: w)
                        .frame(height: bottomH)
                }
                .padding(.horizontal, 8)
            }

            EclipseRiichiFlash(trigger: $riichiFlash)
        }
        .onAppear {
            EclipseOrientationGate.lockLandscape()
        }
        .onDisappear {
            EclipseOrientationGate.lockPortrait()
        }
        .onChange(of: engine.players[0].riichi) { newVal in
            if newVal == .active || newVal == .doubleRiichi { riichiFlash = true }
        }
        .sheet(isPresented: Binding(
            get: { engine.gamePhase == .roundOver && engine.scoreResult != nil },
            set: { _ in })
        ) {
            if let result = engine.scoreResult {
                EclipseScoreSheetView(banner: engine.resultBanner,
                                      result: result,
                                      onNext: { engine.startNewGame() },
                                      onHome: { onExit() })
            }
        }
    }

    // MARK: 顶部栏
    private var topBar: some View {
        HStack(spacing: 8) {
            Button(action: onExit) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text("\(engine.players[0].seatWind.nameEN) Round")
                    .font(EclipseStyle.Typography.neon(11))
                    .foregroundStyle(.white)
                Text("Wall: \(engine.wallLiveCount)")
                    .font(EclipseStyle.Typography.label(9))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            EclipseDoraPanel(indicators: engine.doraIndicators,
                             kandoraIndicators: engine.kandoraIndicators)
        }
    }

    // MARK: 顶部 AI（座位 2）— 牌横向铺开，居中
    private func seatRow(seatIndex: Int, width: CGFloat) -> some View {
        let p = engine.players[seatIndex]
        return VStack(spacing: 2) {
            EclipseSeatTag(name: p.displayName,
                            wind: p.seatWind,
                            score: p.score,
                            riichi: p.riichi,
                            isCurrent: engine.currentPlayerIndex == seatIndex)
            EclipseOpponentRow(player: p, orientation: .top, maxExtent: width)
                .scaleEffect(x: -1, y: -1)
            EclipseMeldRow(melds: p.melds)
                .scaleEffect(0.85)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 中间行：左 AI + 桌面 + 右 AI
    private func middleRow(height: CGFloat, width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 4) {
            sideSeat(seatIndex: 1, orientation: .left, available: height)
            tableCenter
            sideSeat(seatIndex: 3, orientation: .right, available: height)
        }
        .frame(width: width)
    }

    private func sideSeat(seatIndex: Int, orientation: EclipseSeatOrientation, available: CGFloat) -> some View {
        let p = engine.players[seatIndex]
        // 减去座位 tag 和副露区高度
        let handArea = max(40, available - 56)
        return VStack(spacing: 4) {
            EclipseSeatTag(name: p.displayName,
                            wind: p.seatWind,
                            score: p.score,
                            riichi: p.riichi,
                            isCurrent: engine.currentPlayerIndex == seatIndex)
            EclipseOpponentRow(player: p, orientation: orientation, maxExtent: handArea)
            EclipseMeldRow(melds: p.melds)
                .scaleEffect(0.7)
        }
    }

    private var tableCenter: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(EclipseStyle.feltVignette)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(LinearGradient(colors: [
                            EclipseStyle.current.halo,
                            EclipseStyle.current.pulseA,
                            EclipseStyle.current.pulseB
                        ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.0)
                )
                .shadow(color: EclipseStyle.current.pulseA.opacity(0.5), radius: 12)

            EclipseBreathFrame(isActive: !engine.players[engine.currentPlayerIndex].isHuman)

            VStack(spacing: 4) {
                EclipsePondView(pond: engine.players[2].pond, riichiTurn: nil)
                    .scaleEffect(x: -1, y: -1)
                HStack(alignment: .top, spacing: 8) {
                    EclipsePondView(pond: engine.players[1].pond, riichiTurn: nil)
                        .rotationEffect(.degrees(90))
                    Spacer(minLength: 0)
                    VStack(spacing: 4) {
                        EclipseRiichiSticks(count: engine.riichiSticks)
                        if let last = engine.lastDiscard {
                            EclipseTileFace(tile: last,
                                            width: EclipseStyle.Metric.smallW + 6,
                                            height: EclipseStyle.Metric.smallH + 8,
                                            isGlowing: true)
                        } else {
                            Text("—")
                                .font(EclipseStyle.Typography.display(20))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer(minLength: 0)
                    EclipsePondView(pond: engine.players[3].pond, riichiTurn: nil)
                        .rotationEffect(.degrees(-90))
                }
                EclipsePondView(pond: engine.players[0].pond, riichiTurn: nil)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rotation3DEffect(.degrees(tableYaw), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { g in
                    let dx = g.translation.width - lastDragX
                    tableYaw = max(-18, min(18, tableYaw + Double(dx) * 0.08))
                    lastDragX = g.translation.width
                }
                .onEnded { _ in
                    lastDragX = 0
                    withAnimation(.spring()) { tableYaw = 0 }
                }
        )
    }

    // MARK: 玩家区
    private func bottomRow(width: CGFloat) -> some View {
        VStack(spacing: 4) {
            HStack {
                EclipseSeatTag(name: engine.players[0].displayName,
                                wind: engine.players[0].seatWind,
                                score: engine.players[0].score,
                                riichi: engine.players[0].riichi,
                                isCurrent: engine.currentPlayerIndex == 0)
                Spacer()
                if !engine.humanOptions.isEmpty {
                    EclipseClaimRing(actions: engine.humanOptions,
                                     countdown: engine.claimCountdown,
                                     onPick: { engine.humanPerform($0) },
                                     onSkip: { engine.humanPerform(.init(kind: .skip)) })
                }
            }

            EclipseMeldRow(melds: engine.players[0].melds)

            EclipseHandRow(player: engine.players[0],
                           canTap: engine.gamePhase == .discard && engine.currentPlayerIndex == 0,
                           onTap: { engine.humanDiscard($0); EchoEffectManager.shared.cue(.discard) })
        }
        .padding(.bottom, 4)
    }
}

// 根视图：splash → 大厅 / 教学 / 统计 / 回放 / 游戏
struct EclipseRootView: View {
    @StateObject private var dataStore = EchoDataStore()
    @StateObject private var engine = EchoGameEngine()

    @State private var scene: EclipseScene = .home

    enum EclipseScene { case splash, home, tutorial, stats, replay, game }

    var body: some View {
        ZStack {
            switch scene {
            case .splash:
                EclipseSplashView(onFinish: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        scene = .home
                    }
                })
                .transition(.opacity)
            case .home:
                EclipseHomeView(engine: engine,
                                onStart: { engine.startNewGame(); scene = .game },
                                onTutorial: { scene = .tutorial },
                                onStats: { scene = .stats },
                                onReplay: { scene = .replay })
                .transition(.opacity)
            case .tutorial:
                EclipseTutorialView(onClose: { scene = .home })
            case .stats:
                EclipseStatsView(dataStore: dataStore, onClose: { scene = .home })
            case .replay:
                EclipseReplayView(dataStore: dataStore, onClose: { scene = .home })
            case .game:
                EclipseGameView(engine: engine, onExit: { scene = .home })
            }
        }
        .preferredColorScheme(.dark)
    }
}
