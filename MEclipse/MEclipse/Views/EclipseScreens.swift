import SwiftUI

// 主菜单
struct EclipseHomeView: View {
    @ObservedObject var engine: EchoGameEngine
    let onStart: () -> Void
    let onTutorial: () -> Void
    let onStats: () -> Void
    let onReplay: () -> Void

    @State private var titleGlow = false
    @State private var tileRotation: Double = 0

    var body: some View {
        ZStack {
            EclipseStyle.screenGradient.ignoresSafeArea()
            EclipseStarfield()

            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(EclipseStyle.current.halo.opacity(0.55), lineWidth: 1.4)
                        .frame(width: 220, height: 220)
                        .blur(radius: 1)
                    Circle()
                        .stroke(EclipseStyle.current.pulseA.opacity(0.45), lineWidth: 1.4)
                        .frame(width: 250, height: 250)
                    floatingShowcase
                }

                Text("MAHJONG ECLIPSE")
                    .font(.system(size: 38, weight: .black, design: .serif))
                    .foregroundStyle(LinearGradient(colors: [
                        EclipseStyle.current.halo,
                        EclipseStyle.current.bloodRed,
                        EclipseStyle.current.pulseA
                    ], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: EclipseStyle.current.pulseA.opacity(titleGlow ? 0.7 : 0.2),
                             radius: titleGlow ? 16 : 6)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            titleGlow.toggle()
                        }
                    }

                Text("Riichi · Dora · Yakuman")
                    .font(EclipseStyle.Typography.label(13))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                VStack(spacing: 12) {
                    primaryButton("Begin Eclipse", icon: "moonphase.first.quarter") {
                        onStart()
                    }
                    HStack(spacing: 12) {
                        secondaryButton("Tutorial", icon: "book.fill", action: onTutorial)
                        secondaryButton("Stats", icon: "chart.bar.xaxis", action: onStats)
                        secondaryButton("Replays", icon: "rectangle.stack.fill", action: onReplay)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
    }

    private var floatingShowcase: some View {
        let demoTiles: [EchoTile] = [
            .init(suit: .man, rank: .n5),
            .init(suit: .pin, rank: .n5),
            .init(suit: .sou, rank: .n5),
            .init(suit: .dragon, rank: .chun)
        ]
        return ZStack {
            ForEach(Array(demoTiles.enumerated()), id: \.element.id) { idx, tile in
                EclipseTileFace(tile: tile, width: 56, height: 78)
                    .rotation3DEffect(.degrees(tileRotation + Double(idx) * 90),
                                       axis: (x: 0, y: 1, z: 0),
                                       perspective: 0.5)
                    .offset(x: cos(Double(idx) * .pi / 2 + tileRotation * .pi / 180) * 50,
                             y: sin(Double(idx) * .pi / 2 + tileRotation * .pi / 180) * 36)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                tileRotation = 360
            }
        }
    }

    private func primaryButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(label)
            }
            .font(EclipseStyle.Typography.neon(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(LinearGradient(colors: [
                    EclipseStyle.current.bloodRed,
                    EclipseStyle.current.pulseA
                ], startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: EclipseStyle.current.bloodRed.opacity(0.6), radius: 14)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(label)
                    .font(EclipseStyle.Typography.label(11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// 教学页（分步介绍）
struct EclipseTutorialView: View {
    let onClose: () -> Void
    @State private var pageIndex = 0

    private let pages: [(String, String, String)] = [
        ("Goal",
         "Form 4 sets and a pair from a 13-tile hand, with at least one Yaku.",
         "sparkles"),
        ("Riichi",
         "When fully concealed and one away from winning, declare Riichi: place a 1000-point stick and lock your hand.",
         "bolt.fill"),
        ("Dora",
         "The tile after each Dora indicator becomes a Dora — every copy you hold adds 1 han at scoring.",
         "star.fill"),
        ("Calls",
         "Pon, Chi and Kan use opponents' discards but break Menzen. Choose carefully — many high-value Yaku require a closed hand.",
         "hand.tap.fill"),
        ("Yakuman",
         "Hands like Suuankou or Daisangen score 8000 base points — the Eclipse triggers a dragon ribbon when one lands.",
         "flame.fill"),
        ("Scoring",
         "Final score = Fu × 2^(Han+2). Mangan caps at 2000 base, Haneman/Baiman/Sanbaiman/Yakuman climb from there.",
         "function")
    ]

    var body: some View {
        ZStack {
            EclipseStyle.screenGradient.ignoresSafeArea()
            EclipseStarfield()

            VStack {
                HStack {
                    Text("Tutorial")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)

                Spacer()

                TabView(selection: $pageIndex) {
                    ForEach(0..<pages.count, id: \.self) { idx in
                        VStack(spacing: 18) {
                            Image(systemName: pages[idx].2)
                                .font(.system(size: 64))
                                .foregroundStyle(LinearGradient(colors: [
                                    EclipseStyle.current.halo,
                                    EclipseStyle.current.pulseA
                                ], startPoint: .top, endPoint: .bottom))
                            Text(pages[idx].0)
                                .font(EclipseStyle.Typography.display(26))
                                .foregroundStyle(.white)
                            Text(pages[idx].1)
                                .multilineTextAlignment(.center)
                                .font(EclipseStyle.Typography.label(15))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 24)
                            Spacer()
                        }
                        .padding(.top, 30)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack {
                    Spacer()
                    Button {
                        if pageIndex < pages.count - 1 { pageIndex += 1 } else { onClose() }
                    } label: {
                        Text(pageIndex < pages.count - 1 ? "Next" : "Done")
                            .font(EclipseStyle.Typography.neon(15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26).padding(.vertical, 10)
                            .background(Capsule().fill(LinearGradient(colors: [
                                EclipseStyle.current.bloodRed,
                                EclipseStyle.current.pulseA
                            ], startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }
}

// 统计页
struct EclipseStatsView: View {
    @ObservedObject var dataStore: EchoDataStore
    let onClose: () -> Void

    var body: some View {
        ZStack {
            EclipseStyle.screenGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                header
                statCard(title: "Rank",
                         primary: "Lv. \(dataStore.profile.rank)",
                         secondary: "\(dataStore.profile.rankPoints) RP")
                statCard(title: "Matches Played",
                         primary: "\(dataStore.profile.matchesPlayed)",
                         secondary: "Wins: \(dataStore.profile.winCount)")
                statCard(title: "Win Rate",
                         primary: dataStore.winRateText,
                         secondary: "Across all matches")
                statCard(title: "Riichi Rate",
                         primary: dataStore.riichiRateText,
                         secondary: "Declarations per match")

                difficultyPicker

                Spacer()
            }
            .padding(.horizontal, 18)
        }
    }

    private var header: some View {
        HStack {
            Text("Statistics")
                .font(.system(size: 22, weight: .black, design: .serif))
                .foregroundStyle(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI Tide")
                .font(EclipseStyle.Typography.label(13))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(EchoDifficulty.allCases, id: \.self) { diff in
                    let isPicked = diff == dataStore.profile.preferredDifficulty
                    Button {
                        dataStore.profile.preferredDifficulty = diff
                        dataStore.saveProfile()
                    } label: {
                        Text(diff.label)
                            .font(EclipseStyle.Typography.neon(13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isPicked ? AnyShapeStyle(LinearGradient(colors: [
                                        EclipseStyle.current.pulseA,
                                        EclipseStyle.current.pulseB
                                    ], startPoint: .leading, endPoint: .trailing))
                                                   : AnyShapeStyle(Color.white.opacity(0.12)))
                            )
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statCard(title: String, primary: String, secondary: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(EclipseStyle.Typography.label(12))
                .foregroundStyle(.white.opacity(0.6))
            Text(primary)
                .font(EclipseStyle.Typography.neon(24))
                .foregroundStyle(.white)
            Text(secondary)
                .font(EclipseStyle.Typography.label(12))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(EclipseStyle.current.pulseA.opacity(0.35), lineWidth: 0.8)
        )
    }
}

// 回放页（只显示元数据）
struct EclipseReplayView: View {
    @ObservedObject var dataStore: EchoDataStore
    let onClose: () -> Void

    var body: some View {
        ZStack {
            EclipseStyle.screenGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recent Eclipses")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                if dataStore.replays.isEmpty {
                    Spacer()
                    Text("No replays yet. Complete a round to record one.")
                        .font(EclipseStyle.Typography.label(14))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(dataStore.replays) { r in
                                replayRow(r)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
    }

    private func replayRow(_ r: EchoReplaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(r.winnerName)
                    .font(EclipseStyle.Typography.neon(14))
                    .foregroundStyle(.white)
                Spacer()
                Text(r.resultTitle)
                    .font(EclipseStyle.Typography.neon(13))
                    .foregroundStyle(EclipseStyle.current.halo)
            }
            Text("\(r.roundWind.nameEN) round · \(r.seatWind.nameEN) seat · \(r.resultHan) han \(r.resultFu) fu")
                .font(EclipseStyle.Typography.label(12))
                .foregroundStyle(.white.opacity(0.7))
            if !r.yakuLabels.isEmpty {
                Text(r.yakuLabels.joined(separator: " · "))
                    .font(EclipseStyle.Typography.label(11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(EclipseStyle.current.pulseA.opacity(0.30), lineWidth: 0.8)
        )
    }
}

// 胡牌结算页
struct EclipseScoreSheetView: View {
    let banner: String
    let result: EchoScoreResult
    let onNext: () -> Void
    let onHome: () -> Void

    @State private var fxTrigger: UUID?

    var body: some View {
        ZStack {
            EclipseStyle.screenGradient.ignoresSafeArea()
            EclipseStarfield()
            if result.yaku.contains(where: { $0.isYakuman }) {
                EclipseDragonRibbon(isActive: true)
            }
            EclipseFireworkLayer(trigger: fxTrigger)

            VStack(spacing: 12) {
                Text(banner)
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(LinearGradient(colors: [
                        EclipseStyle.current.halo,
                        EclipseStyle.current.bloodRed,
                        EclipseStyle.current.pulseA
                    ], startPoint: .leading, endPoint: .trailing))
                    .padding(.top, 36)

                Text(result.title)
                    .font(EclipseStyle.Typography.neon(20))
                    .foregroundStyle(.white)
                Text("\(result.totalHan) han · \(result.fu) fu")
                    .font(EclipseStyle.Typography.label(14))
                    .foregroundStyle(.white.opacity(0.7))

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(result.summary) { s in
                            HStack {
                                Text(s.label)
                                    .font(EclipseStyle.Typography.label(13))
                                    .foregroundStyle(.white)
                                Spacer()
                                if s.isYakuman {
                                    Text("Yakuman")
                                        .font(EclipseStyle.Typography.neon(12))
                                        .foregroundStyle(EclipseStyle.current.bloodRed)
                                } else {
                                    Text("+\(s.han) han")
                                        .font(EclipseStyle.Typography.neon(12))
                                        .foregroundStyle(EclipseStyle.current.pulseB)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.06))
                            )
                        }
                        if result.dora > 0 {
                            extraRow("Dora x\(result.dora)", color: EclipseStyle.current.halo)
                        }
                        if result.uradora > 0 {
                            extraRow("Ura-Dora x\(result.uradora)", color: EclipseStyle.current.pulseA)
                        }
                        if result.aka > 0 {
                            extraRow("Aka-Dora x\(result.aka)", color: EclipseStyle.current.bloodRed)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                HStack(spacing: 14) {
                    Button(action: onHome) {
                        Text("Menu")
                            .font(EclipseStyle.Typography.neon(15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Capsule().fill(.white.opacity(0.20)))
                    }
                    .buttonStyle(.plain)
                    Button(action: onNext) {
                        Text("Next Round")
                            .font(EclipseStyle.Typography.neon(15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Capsule().fill(LinearGradient(colors: [
                                EclipseStyle.current.bloodRed,
                                EclipseStyle.current.pulseA
                            ], startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            fxTrigger = UUID()
        }
    }

    private func extraRow(_ label: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(EclipseStyle.Typography.label(13))
                .foregroundStyle(.white)
            Spacer()
            Text("+1 han / copy")
                .font(EclipseStyle.Typography.neon(12))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.10))
        )
    }
}
