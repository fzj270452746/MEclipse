import SwiftUI
import UIKit

@main
final class EclipseAppDelegate: NSObject, UIApplicationDelegate {

    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return Self.orientationLock
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        Self.orientationLock = .portrait
        _ = EchoNumericNoise.warmTuning()
        return true
    }

    func application(
            _ application: UIApplication,
            configurationForConnecting connectingSceneSession: UISceneSession,
            options: UIScene.ConnectionOptions
        ) -> UISceneConfiguration {

            UISceneConfiguration(
                name: "Default Configuration",
                sessionRole: connectingSceneSession.role
            )
        }
    
}

// 切换允许的方向并请求系统应用
enum EclipseOrientationGate {
    static func lockPortrait() {
        EclipseAppDelegate.orientationLock = .portrait
        applyGeometry(mask: .portrait)
    }
    static func lockLandscape() {
        EclipseAppDelegate.orientationLock = .landscape
        applyGeometry(mask: .landscape)
    }

    private static func applyGeometry(mask: UIInterfaceOrientationMask) {
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes.compactMap({ $0 as? UIWindowScene }) {
            if #available(iOS 16.0, *) {
                let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
                scene.requestGeometryUpdate(prefs) { _ in }
            } else {
                UIDevice.current.setValue(mask.fallbackOrientation.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
            for vc in scene.windows.compactMap({ $0.rootViewController }) {
                if #available(iOS 16.0, *) {
                    vc.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }
    }
}

private extension UIInterfaceOrientationMask {
    var fallbackOrientation: UIInterfaceOrientation {
        contains(.landscapeRight) ? .landscapeRight : .portrait
    }
}
