import UIKit
import SwiftUI
import AppTrackingTransparency

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {

        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        

        let hostingController = EclipseMainController()

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        self.window = window
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            ATTrackingManager.requestTrackingAuthorization {_ in }
        }
    }
}
