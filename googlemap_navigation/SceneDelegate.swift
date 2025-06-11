
import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Initialize CoreData
        _ = CoreDataManager.shared.persistentContainer
        
        // 设置 Firebase 同步间隔为一周
        WalkingDataManager.shared.setSyncIntervalInDays(7)
        
        // 初始化步行数据管理器
        _ = WalkingDataManager.shared
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 设置窗口
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // 根据用户登录状态设置根视图控制器
        if Auth.auth().currentUser != nil {
            // 用户已登录，显示主页
            let homeVC = HomeViewController()
            let navigationController = UINavigationController(rootViewController: homeVC)
            window.rootViewController = navigationController
        } else {
            // 用户未登录，显示启动页
            let splashVC = SplashViewController()
            let navigationController = UINavigationController(rootViewController: splashVC)
            window.rootViewController = navigationController
        }
        
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
   
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let locationDidUpdate = Notification.Name("locationDidUpdate")
}

