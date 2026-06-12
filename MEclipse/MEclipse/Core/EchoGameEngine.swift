import Foundation
import SwiftUI
import Combine

// 游戏引擎：服务组合，非传统 .shared 单例（注入式）
@MainActor
final class EchoGameEngine: ObservableObject {

    // 依赖
    private let wall = EchoWallService()
    private(set) var ai: EchoAIStrategy
    let dataStore: EchoDataStore

    // 发布的状态
    @Published private(set) var players: [EchoPlayer] = []
    @Published private(set) var currentPlayerIndex: Int = 0
    @Published private(set) var gamePhase: EchoGamePhase = .bootstrap
    @Published private(set) var lastDiscard: EchoTile?
    @Published private(set) var lastDiscardSeat: Int = -1
    @Published private(set) var doraIndicators: [EchoTile] = []
    @Published private(set) var uraIndicators:  [EchoTile] = []
    @Published private(set) var kandoraIndicators:[EchoTile] = []
    @Published private(set) var roundWind: EchoWind = .east
    @Published private(set) var honba: Int = 0
    @Published private(set) var riichiSticks: Int = 0

    // 玩家可选动作
    @Published var humanOptions: [EchoAction] = []

    // 倒计时
    @Published var claimCountdown: Double = 0

    // 结算
    @Published var scoreResult: EchoScoreResult?
    @Published var resultBanner: String = ""

    // 计时器/挂起任务
    private var claimTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?

    // 标记
    private var rinshanFlag = false
    private var ippatsuFlags: [Bool] = [false, false, false, false]
    private var furiten: [Bool] = [false, false, false, false]

    init(dataStore: EchoDataStore = EchoDataStore(), difficulty: EchoDifficulty = .balanced) {
        self.dataStore = dataStore
        self.ai = EchoAIStrategy(difficulty: difficulty)
        prepareSeats()
    }

    // MARK: 准备

    private func prepareSeats() {
        players = [
            EchoPlayer(seat: 0, isHuman: true,  name: "You",        wind: .east),
            EchoPlayer(seat: 1, isHuman: false, name: "Houshou",    wind: .south),
            EchoPlayer(seat: 2, isHuman: false, name: "Sazanka",    wind: .west),
            EchoPlayer(seat: 3, isHuman: false, name: "Kuroyuri",   wind: .north)
        ]
    }

    func startNewGame() {
        cancelAll()
        for p in players {
            p.hand.removeAll()
            p.melds.removeAll()
            p.pond.removeAll()
            p.riichi = .none
            p.ippatsuLive = false
            p.lastDrawnId = nil
        }
        wall.reset()
        doraIndicators = wall.doraIndicators
        uraIndicators  = wall.uraIndicators
        kandoraIndicators = wall.kandoraIndicators
        ippatsuFlags = [false, false, false, false]
        furiten = [false, false, false, false]
        rinshanFlag = false
        humanOptions.removeAll()
        scoreResult = nil
        resultBanner = ""

        // 配牌
        gamePhase = .dealing
        for round in 0..<3 {
            for seat in 0..<4 {
                for _ in 0..<4 {
                    if let t = wall.drawNormal() { players[seat].hand.append(t) }
                }
            }
            _ = round
        }
        for seat in 0..<4 {
            if let t = wall.drawNormal() { players[seat].hand.append(t) }
        }
        // 庄家额外摸 1
        if let t = wall.drawNormal() {
            players[0].hand.append(t)
            players[0].lastDrawnId = t.id
        }

        currentPlayerIndex = 0
        gamePhase = .discard
        evaluateHumanAfterDraw()
    }

    // MARK: 人类打牌

    func humanDiscard(_ tile: EchoTile) {
        guard gamePhase == .discard, currentPlayerIndex == 0 else { return }
        // 立直后不能换牌
        if players[0].riichi == .active {
            if tile.id != players[0].lastDrawnId { return }
        }
        commitDiscard(seat: 0, tile: tile)
    }

    func humanPerform(_ action: EchoAction) {
        cancelClaimTimer()
        humanOptions.removeAll()
        switch action.kind {
        case .ron:
            if let target = action.target {
                resolveAgari(winnerSeat: 0, winTile: target, isTsumo: false, loserSeat: lastDiscardSeat)
            }
        case .tsumo:
            if let last = players[0].hand.last {
                resolveAgari(winnerSeat: 0, winTile: last, isTsumo: true, loserSeat: nil)
            }
        case .pon:
            performPon(seat: 0, target: action.target!)
        case .chi:
            performChi(seat: 0, target: action.target!, usingCodes: action.usingCodes)
        case .minkan:
            performMinkan(seat: 0, target: action.target!)
        case .ankan:
            if let code = action.usingCodes.first { performAnkan(seat: 0, code: code) }
        case .kakan:
            if let code = action.usingCodes.first { performKakan(seat: 0, code: code) }
        case .riichi:
            performRiichiDeclaration()
        case .skip:
            advanceAfterClaim()
        }
    }

    // MARK: 立直

    private func performRiichiDeclaration() {
        guard players[0].riichi == .none else { return }
        guard players[0].melds.isEmpty else { return }
        guard players[0].score >= EchoConstants.riichiStickValue else { return }
        players[0].riichi = .declaring
        resultBanner = "Riichi declared!"
        dataStore.recordRiichi()
    }

    private func finalizeRiichiOnDiscard(seat: Int) {
        guard players[seat].riichi == .declaring else { return }
        players[seat].riichi = .active
        players[seat].score -= EchoConstants.riichiStickValue
        riichiSticks += 1
        ippatsuFlags[seat] = true
        players[seat].ippatsuLive = true
    }

    // MARK: 公共打牌流

    private func commitDiscard(seat: Int, tile: EchoTile) {
        let p = players[seat]
        guard let idx = p.hand.firstIndex(of: tile) else { return }
        p.hand.remove(at: idx)
        p.pond.append(tile)
        lastDiscard = tile
        lastDiscardSeat = seat
        finalizeRiichiOnDiscard(seat: seat)
        // 任何人打牌都打破一发
        for i in 0..<4 where i != seat {
            ippatsuFlags[i] = false
            players[i].ippatsuLive = false
        }
        if seat == 0 { players[0].lastDrawnId = nil }

        resolveDiscardClaims()
    }

    private func resolveDiscardClaims() {
        guard let target = lastDiscard else { return }
        let claimants = (0..<4).filter { $0 != lastDiscardSeat }

        // Ron 检查 — 任意非弃牌者
        var ronCandidates: [Int] = []
        for s in claimants {
            if canRon(seat: s, winTile: target) {
                ronCandidates.append(s)
            }
        }

        if !ronCandidates.isEmpty {
            // 玩家优先弹按钮
            if ronCandidates.contains(0) {
                humanOptions.append(EchoAction(kind: .ron, target: target))
                scheduleClaimTimer()
                return
            }
            // AI 直接和（取最靠近弃牌者的一位）
            let winner = ronCandidates.first!
            resolveAgari(winnerSeat: winner, winTile: target, isTsumo: false, loserSeat: lastDiscardSeat)
            return
        }

        // Pon / Kan / Chi
        let target0Code = target.code
        var humanCanPon  = false
        var humanCanKan  = false
        var humanChi: [[Int]] = []

        for s in claimants {
            let bucket = countsOf(seat: s)
            let myCount = bucket[target0Code]
            if myCount >= 3 {
                if s == 0 { humanCanKan = true; continue }
                if ai.wantsCallKan(hand: players[s].hand, target: target) {
                    performMinkan(seat: s, target: target)
                    return
                }
            } else if myCount >= 2 {
                if s == 0 { humanCanPon = true; continue }
                if ai.wantsCallPon(hand: players[s].hand, target: target, dora: doraIndicators) {
                    performPon(seat: s, target: target)
                    return
                }
            }
        }

        // Chi 只能下家
        let chiSeat = (lastDiscardSeat + 1) % 4
        if chiSeat != lastDiscardSeat {
            humanChi = chiSeat == 0 ? possibleChi(seat: chiSeat, target: target) : []
            if chiSeat != 0 {
                let opts = possibleChi(seat: chiSeat, target: target)
                if let _ = opts.first, ai.wantsCallChi(hand: players[chiSeat].hand, target: target) {
                    performChi(seat: chiSeat, target: target, usingCodes: opts.first!)
                    return
                }
            }
        }

        // 拼装玩家选项
        var opts: [EchoAction] = []
        if humanCanPon { opts.append(.init(kind: .pon, target: target)) }
        if humanCanKan { opts.append(.init(kind: .minkan, target: target)) }
        for chi in humanChi {
            opts.append(.init(kind: .chi, target: target, usingCodes: chi))
        }
        if !opts.isEmpty {
            humanOptions = opts
            scheduleClaimTimer()
            return
        }
        advanceAfterClaim()
    }

    private func scheduleClaimTimer() {
        cancelClaimTimer()
        claimCountdown = EchoConstants.claimTimeoutSeconds
        claimTask = Task { [weak self] in
            while !(Task.isCancelled) {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    guard let self else { return }
                    self.claimCountdown -= 0.1
                    if self.claimCountdown <= 0 {
                        self.humanOptions.removeAll()
                        self.cancelClaimTimer()
                        self.advanceAfterClaim()
                    }
                }
            }
        }
    }

    private func cancelClaimTimer() {
        claimTask?.cancel()
        claimTask = nil
        claimCountdown = 0
    }

    private func cancelAll() {
        cancelClaimTimer()
        aiTask?.cancel()
        aiTask = nil
    }

    private func advanceAfterClaim() {
        currentPlayerIndex = (lastDiscardSeat + 1) % 4
        proceedTurn()
    }

    private func proceedTurn() {
        if wall.liveCount == 0 {
            // 流局
            endInExhaustiveDraw()
            return
        }
        let seat = currentPlayerIndex
        guard let drew = (rinshanFlag ? wall.drawRinshan() : wall.drawNormal()) else {
            endInExhaustiveDraw()
            return
        }
        rinshanFlag = false
        players[seat].hand.append(drew)
        players[seat].lastDrawnId = drew.id

        // 自摸检查
        if canTsumo(seat: seat, drawn: drew) {
            if seat == 0 {
                humanOptions.append(.init(kind: .tsumo, target: drew))
                appendHumanDiscardOptions()
                return
            }
            resolveAgari(winnerSeat: seat, winTile: drew, isTsumo: true, loserSeat: nil)
            return
        }
        if seat == 0 {
            evaluateHumanAfterDraw()
            return
        }
        scheduleAIDiscard(seat: seat)
    }

    private func evaluateHumanAfterDraw() {
        humanOptions.removeAll()
        let me = players[0]
        // 暗杠 / 加杠
        var bucket = [Int](repeating: 0, count: 34)
        for t in me.hand { bucket[t.code] += 1 }
        for code in 0..<34 where bucket[code] == 4 {
            humanOptions.append(.init(kind: .ankan, usingCodes: [code]))
        }
        for m in me.melds where m.kind == .pon {
            let mc = m.tiles.first?.code ?? -1
            if bucket[mc] >= 1 {
                humanOptions.append(.init(kind: .kakan, usingCodes: [mc]))
            }
        }
        if me.riichi == .none && me.melds.isEmpty && me.score >= EchoConstants.riichiStickValue {
            var b = bucket
            // 找到能立直的弃牌（牌打出去之后听牌）
            for code in 0..<34 where b[code] > 0 {
                b[code] -= 1
                if EchoShantenCounter.shanten(bucket: b, openMelds: 0) == 0 {
                    humanOptions.append(.init(kind: .riichi))
                    b[code] += 1
                    break
                }
                b[code] += 1
            }
        }
    }

    private func appendHumanDiscardOptions() {
        // 自摸/暗杠后玩家还要决定怎么处理
    }

    private func scheduleAIDiscard(seat: Int) {
        aiTask?.cancel()
        aiTask = Task { [weak self] in
            let delay = UInt64.random(in: EchoConstants.aiThinkingMillis) * 1_000_000
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                guard let self else { return }
                if self.players[seat].riichi == .active {
                    // 立直后只能打出刚摸的
                    if let drawnId = self.players[seat].lastDrawnId,
                       let drawn = self.players[seat].hand.first(where: { $0.id == drawnId }) {
                        self.commitDiscard(seat: seat, tile: drawn)
                        return
                    }
                }
                let opponentDiscards = (0..<4).filter { $0 != seat }.map { self.players[$0].pond }
                let tile = self.ai.bestDiscard(hand: self.players[seat].hand,
                                               openMelds: self.players[seat].melds,
                                               visibleDiscards: opponentDiscards,
                                               dora: self.doraIndicators)
                // 立直机会
                if self.ai.wantsRiichi(hand: self.players[seat].hand,
                                       openMelds: self.players[seat].melds,
                                       score: self.players[seat].score) {
                    self.players[seat].riichi = .declaring
                }
                self.commitDiscard(seat: seat, tile: tile)
            }
        }
    }

    // MARK: 副露 / 杠

    private func possibleChi(seat: Int, target: EchoTile) -> [[Int]] {
        guard target.suit.isNumeric, let n = target.rank.numeric else { return [] }
        let suitBase = (target.code / 9) * 9
        let pos = target.code - suitBase
        var bucket = [Int](repeating: 0, count: 34)
        for t in players[seat].hand { bucket[t.code] += 1 }

        var combos: [[Int]] = []
        if pos >= 2, bucket[target.code - 2] > 0, bucket[target.code - 1] > 0 {
            combos.append([target.code - 2, target.code - 1])
        }
        if pos >= 1 && pos <= 7, bucket[target.code - 1] > 0, bucket[target.code + 1] > 0 {
            combos.append([target.code - 1, target.code + 1])
        }
        if pos <= 6, bucket[target.code + 1] > 0, bucket[target.code + 2] > 0 {
            combos.append([target.code + 1, target.code + 2])
        }
        return combos
        _ = n
    }

    private func performPon(seat: Int, target: EchoTile) {
        let matches = players[seat].hand.filter { $0.sameKind(as: target) }
        let used = Array(matches.prefix(2))
        for t in used {
            if let i = players[seat].hand.firstIndex(of: t) {
                players[seat].hand.remove(at: i)
            }
        }
        let meld = EchoMeld(kind: .pon, tiles: used + [target],
                            claimedFrom: lastDiscardSeat, claimedTileCode: target.code)
        players[seat].melds.append(meld)
        consumeDiscard()
        currentPlayerIndex = seat
        if seat == 0 {
            humanOptions.removeAll()
            evaluateHumanAfterDraw()
        } else {
            scheduleAIDiscard(seat: seat)
        }
    }

    private func performChi(seat: Int, target: EchoTile, usingCodes: [Int]) {
        var used: [EchoTile] = []
        for code in usingCodes {
            if let i = players[seat].hand.firstIndex(where: { $0.code == code }) {
                used.append(players[seat].hand.remove(at: i))
            }
        }
        let meld = EchoMeld(kind: .chi, tiles: (used + [target]).sorted(),
                            claimedFrom: lastDiscardSeat, claimedTileCode: target.code)
        players[seat].melds.append(meld)
        consumeDiscard()
        currentPlayerIndex = seat
        if seat == 0 {
            humanOptions.removeAll()
            evaluateHumanAfterDraw()
        } else {
            scheduleAIDiscard(seat: seat)
        }
    }

    private func performMinkan(seat: Int, target: EchoTile) {
        let matches = players[seat].hand.filter { $0.sameKind(as: target) }
        let used = Array(matches.prefix(3))
        for t in used {
            if let i = players[seat].hand.firstIndex(of: t) {
                players[seat].hand.remove(at: i)
            }
        }
        let meld = EchoMeld(kind: .minkan, tiles: used + [target],
                            claimedFrom: lastDiscardSeat, claimedTileCode: target.code)
        players[seat].melds.append(meld)
        consumeDiscard()
        currentPlayerIndex = seat
        wall.revealNextDora()
        doraIndicators = wall.doraIndicators
        kandoraIndicators = wall.kandoraIndicators
        rinshanFlag = true
        proceedTurn()
    }

    private func performAnkan(seat: Int, code: Int) {
        let matches = players[seat].hand.filter { $0.code == code }
        let used = Array(matches.prefix(4))
        for t in used {
            if let i = players[seat].hand.firstIndex(of: t) {
                players[seat].hand.remove(at: i)
            }
        }
        let meld = EchoMeld(kind: .ankan, tiles: used)
        players[seat].melds.append(meld)
        wall.revealNextDora()
        doraIndicators = wall.doraIndicators
        kandoraIndicators = wall.kandoraIndicators
        rinshanFlag = true
        if seat == 0 { humanOptions.removeAll(); evaluateHumanAfterDraw() }
        proceedTurn()
    }

    private func performKakan(seat: Int, code: Int) {
        guard let mIdx = players[seat].melds.firstIndex(where: { $0.kind == .pon && $0.tiles.first?.code == code }) else { return }
        guard let idx = players[seat].hand.firstIndex(where: { $0.code == code }) else { return }
        let added = players[seat].hand.remove(at: idx)
        let oldMeld = players[seat].melds[mIdx]
        let newMeld = EchoMeld(kind: .kakan, tiles: oldMeld.tiles + [added],
                               claimedFrom: oldMeld.claimedFrom, claimedTileCode: oldMeld.claimedTileCode)
        players[seat].melds[mIdx] = newMeld
        wall.revealNextDora()
        doraIndicators = wall.doraIndicators
        kandoraIndicators = wall.kandoraIndicators
        rinshanFlag = true
        if seat == 0 { humanOptions.removeAll(); evaluateHumanAfterDraw() }
        proceedTurn()
    }

    private func consumeDiscard() {
        guard let last = lastDiscard, lastDiscardSeat >= 0 else { return }
        if let i = players[lastDiscardSeat].pond.firstIndex(of: last) {
            players[lastDiscardSeat].pond.remove(at: i)
        }
        lastDiscard = nil
        lastDiscardSeat = -1
    }

    // MARK: 胡牌

    private func canRon(seat: Int, winTile: EchoTile) -> Bool {
        guard !furiten[seat] else { return false }
        var bucket = countsOf(seat: seat)
        bucket[winTile.code] += 1
        return EchoAgariChecker.canAgari(bucket: bucket, openMelds: players[seat].melds.count)
            && hasYaku(seat: seat, winTile: winTile, isTsumo: false)
    }

    private func canTsumo(seat: Int, drawn: EchoTile) -> Bool {
        let bucket = countsOf(seat: seat)
        return EchoAgariChecker.canAgari(bucket: bucket, openMelds: players[seat].melds.count)
            && hasYaku(seat: seat, winTile: drawn, isTsumo: true)
    }

    private func hasYaku(seat: Int, winTile: EchoTile, isTsumo: Bool) -> Bool {
        let ctx = buildContext(forSeat: seat, isTsumo: isTsumo)
        let hand = winningHand(forSeat: seat, winTile: winTile, isTsumo: isTsumo)
        let yk = EchoYakuCalculator.evaluate(hand: hand, context: ctx)
        if yk.contains(where: { $0.isYakuman }) { return true }
        let yakuOnly = yk.filter { $0.id != .ippatsu && $0.id != .riichi && $0.id != .doubleRiichi }
        // riichi/ippatsu 也算役，这里实际只要 yk 非空即可
        return !yk.isEmpty
    }

    private func resolveAgari(winnerSeat: Int, winTile: EchoTile, isTsumo: Bool, loserSeat: Int?) {
        cancelAll()
        humanOptions.removeAll()

        let ctx = buildContext(forSeat: winnerSeat, isTsumo: isTsumo)
        let hand = winningHand(forSeat: winnerSeat, winTile: winTile, isTsumo: isTsumo)
        let seatWinds = players.map { $0.seatWind }
        let result = EchoScoreEngine.compute(hand: hand,
                                              context: ctx,
                                              winnerSeat: winnerSeat,
                                              loserSeat: loserSeat,
                                              seatWinds: seatWinds)
        for (seat, delta) in result.payment {
            players[seat].score += delta
        }
        scoreResult = result
        resultBanner = isTsumo ? "Tsumo!" : "Ron!"
        gamePhase = .roundOver

        // 持久化
        let snap = EchoReplaySnapshot(roundWind: roundWind,
                                      seatWind: players[winnerSeat].seatWind,
                                      resultTitle: result.title,
                                      resultHan: result.totalHan,
                                      resultFu: result.fu,
                                      yakuLabels: result.yaku.map { $0.id.displayName },
                                      winnerName: players[winnerSeat].displayName)
        dataStore.appendReplay(snap)
        dataStore.recordMatchResult(won: winnerSeat == 0,
                                    gainedPoints: winnerSeat == 0 ? result.basePoints : -200)
    }

    private func endInExhaustiveDraw() {
        cancelAll()
        humanOptions.removeAll()
        gamePhase = .roundOver
        resultBanner = "Exhaustive Draw"
    }

    // MARK: 上下文构造

    private func buildContext(forSeat seat: Int, isTsumo: Bool) -> EchoRoundContext {
        let p = players[seat]
        return EchoRoundContext(
            roundWind: roundWind,
            seatWind:  p.seatWind,
            isRiichi:  p.riichi == .active,
            isDoubleRiichi: p.riichi == .doubleRiichi,
            isIppatsu: ippatsuFlags[seat],
            isRinshan: rinshanFlag && isTsumo,
            isHaitei:  wall.liveCount == 0 && isTsumo,
            isHoutei:  wall.liveCount == 0 && !isTsumo,
            isChankan: false,
            isTenhou:  false,
            isChiihou: false,
            doraIndicators:   doraIndicators,
            uraIndicators:    uraIndicators,
            kandoraIndicators:kandoraIndicators,
            isMenzen:  p.melds.allSatisfy { $0.kind == .ankan },
            honba: honba,
            riichiSticks: riichiSticks)
    }

    private func winningHand(forSeat seat: Int, winTile: EchoTile, isTsumo: Bool) -> EchoWinningHand {
        var concealed = players[seat].hand
        if !isTsumo { concealed.append(winTile) }
        return EchoWinningHand(concealed: concealed,
                                melds: players[seat].melds,
                                winTile: winTile,
                                isTsumo: isTsumo)
    }

    private func countsOf(seat: Int) -> [Int] {
        var b = [Int](repeating: 0, count: 34)
        for t in players[seat].hand { b[t.code] += 1 }
        return b
    }

    // 给上层（视图）用
    func currentSeatWind(seat: Int) -> EchoWind { players[seat].seatWind }
    var wallLiveCount: Int { wall.liveCount }
}
