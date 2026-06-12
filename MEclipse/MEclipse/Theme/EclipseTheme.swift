import SwiftUI

// 哥特霓虹主题。Theme 用 struct + protocol 驱动，方便后续切日间/夜间皮肤
protocol EchoSkin {
    var background: [Color]      { get }
    var feltCore:    Color       { get }
    var feltOuter:   Color       { get }
    var ivoryFront:  Color       { get }
    var ivoryShadow: Color       { get }
    var bambooEdge:  Color       { get }
    var inkBlack:    Color       { get }
    var bloodRed:    Color       { get }
    var leafGreen:   Color       { get }
    var skyBlue:     Color       { get }

    var halo:        Color       { get }
    var pulseA:      Color       { get }
    var pulseB:      Color       { get }
    var glint:       Color       { get }
}

struct EclipseDarkSkin: EchoSkin {
    let background: [Color] = [
        Color(red: 0.05, green: 0.02, blue: 0.13),
        Color(red: 0.10, green: 0.03, blue: 0.20),
        Color(red: 0.02, green: 0.01, blue: 0.07)
    ]
    let feltCore:    Color = .init(red: 0.10, green: 0.06, blue: 0.18)
    let feltOuter:   Color = .init(red: 0.02, green: 0.01, blue: 0.05)
    let ivoryFront:  Color = .init(red: 0.97, green: 0.94, blue: 0.86)
    let ivoryShadow: Color = .init(red: 0.78, green: 0.72, blue: 0.59)
    let bambooEdge:  Color = .init(red: 0.46, green: 0.40, blue: 0.27)
    let inkBlack:    Color = .init(red: 0.08, green: 0.07, blue: 0.06)
    let bloodRed:    Color = .init(red: 0.85, green: 0.10, blue: 0.18)
    let leafGreen:   Color = .init(red: 0.07, green: 0.50, blue: 0.22)
    let skyBlue:     Color = .init(red: 0.10, green: 0.30, blue: 0.66)

    let halo:        Color = .init(red: 1.00, green: 0.78, blue: 0.40)
    let pulseA:      Color = .init(red: 0.72, green: 0.30, blue: 1.00)
    let pulseB:      Color = .init(red: 0.30, green: 0.95, blue: 1.00)
    let glint:       Color = .init(red: 1.00, green: 0.46, blue: 0.78)
}

// 单例不是 .shared 而是 .current，且类型是 protocol
enum EclipseStyle {
    static let current: EchoSkin = EclipseDarkSkin()

    enum Metric {
        static let tileWidth:  CGFloat = 46
        static let tileHeight: CGFloat = 64
        static let smallW:     CGFloat = 24
        static let smallH:     CGFloat = 32
        static let radius:     CGFloat = 7
        static let radiusSm:   CGFloat = 4.5
        static let gap:        CGFloat = 3
        static let pondGap:    CGFloat = 1.5
    }

    enum Typography {
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .black, design: .serif)
        }
        static func tile(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .serif)
        }
        static func label(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        static func neon(_ size: CGFloat) -> Font {
            .system(size: size, weight: .black, design: .rounded)
        }
    }

    static var screenGradient: LinearGradient {
        LinearGradient(colors: current.background,
                       startPoint: .top,
                       endPoint:   .bottom)
    }

    static var feltVignette: RadialGradient {
        RadialGradient(colors: [current.feltCore, current.feltOuter],
                       center: .center,
                       startRadius: 50,
                       endRadius: 460)
    }

    static var ivorySurface: LinearGradient {
        LinearGradient(colors: [current.ivoryFront, current.ivoryShadow],
                       startPoint: .top, endPoint: .bottom)
    }
}

// 全局常量。设置项独立命名，不与 EclipseStyle 混
struct EchoConstants {
    static let totalTiles = 136
    static let initialHandSize = 13
    static let dealerExtraTile = 1
    static let maxDoraIndicators = 5
    static let riichiStickValue = 1000
    static let baseStartingScore = 25_000

    static let aiThinkingMillis: ClosedRange<UInt64> = 600...1100
    static let claimTimeoutSeconds: Double = 2.4
}
