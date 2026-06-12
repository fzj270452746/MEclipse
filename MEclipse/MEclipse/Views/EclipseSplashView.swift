import SwiftUI

// Mahjong Eclipse 启动画面
// 使用 Assets 中的 "luchimg" 图片 + 哥特霓虹粒子 + 标题渐显
struct EclipseSplashView: View {

    let onFinish: () -> Void

    @State private var imageScale: CGFloat = 1.10
    @State private var imageOpacity: Double = 0
    @State private var vignetteShown: Bool = false
    @State private var titleVisible: Bool = false
    @State private var subtitleVisible: Bool = false
    @State private var ringRotation: Double = 0
    @State private var titleGlow: Bool = false
    @State private var fading: Bool = false

    var body: some View {
        ZStack {
            // 底色（万一图片加载失败也有兜底）
            EclipseStyle.screenGradient.ignoresSafeArea()

            // 启动图：充满，逐渐拉近
            Image("luchimg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(imageScale)
                .opacity(imageOpacity)
                .ignoresSafeArea()

            // 上下黑色暗角，突出标题区
            LinearGradient(colors: [
                Color.black.opacity(vignetteShown ? 0.55 : 0),
                Color.black.opacity(0),
                Color.black.opacity(vignetteShown ? 0.65 : 0)
            ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // 星空粒子（淡薄一层，复用现有 starfield）
            EclipseStarfield()
                .opacity(0.65)

            VStack {
                Spacer()

                // 标题
                Text("MAHJONG ECLIPSE")
                    .font(.system(size: 38, weight: .black, design: .serif))
                    .kerning(2.5)
                    .foregroundStyle(LinearGradient(colors: [
                        EclipseStyle.current.halo,
                        EclipseStyle.current.bloodRed,
                        EclipseStyle.current.pulseA
                    ], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: EclipseStyle.current.pulseA.opacity(titleGlow ? 0.85 : 0.3),
                            radius: titleGlow ? 18 : 6)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 24)

                // 月食圆环装饰（标题上方）
                ZStack {
                    Circle()
                        .stroke(EclipseStyle.current.halo.opacity(0.6), lineWidth: 1.2)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(EclipseStyle.current.pulseA.opacity(0.7), lineWidth: 1.4)
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(ringRotation))
                }
                .opacity(titleVisible ? 0.7 : 0)
                .padding(.top, 12)

                Text("Riichi · Dora · Yakuman")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(subtitleVisible ? 1 : 0)
                    .padding(.top, 6)

                Spacer()

                Text("Tap anywhere to begin")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(subtitleVisible ? 1 : 0)
                    .padding(.bottom, 32)
            }
        }
        .opacity(fading ? 0 : 1)
        .onAppear { runIntro() }
        .onTapGesture { skipToHome() }
    }

    private func runIntro() {
        // 0.0s 图片淡入并轻微缩放回 1.0
        withAnimation(.easeOut(duration: 0.9)) {
            imageOpacity = 1.0
            imageScale = 1.0
        }
        // 0.2s 暗角浮现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.5)) { vignetteShown = true }
        }
        // 0.55s 标题渐现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                titleVisible = true
            }
        }
        // 1.0s 副标题 / 提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.45)) { subtitleVisible = true }
        }
        // 圆环旋转 + 标题呼吸光
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                titleGlow.toggle()
            }
        }
        // 2.6s 自动进主菜单
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            skipToHome()
        }
    }

    private func skipToHome() {
        guard !fading else { return }
        withAnimation(.easeInOut(duration: 0.4)) { fading = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            onFinish()
        }
    }
}
