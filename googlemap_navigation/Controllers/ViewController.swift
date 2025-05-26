import UIKit
import GoogleMaps
import CoreLocation

class ViewController: UITabBarController {
    
    var currentUserProfile: UserProfile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        // Initialize Google Maps
        GMSServices.provideAPIKey("AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE")
        
        // Set up Home
        let homeVC = HomeViewController()
        homeVC.title = "Home"
        
        if let profile = currentUserProfile {
                   homeVC.userProfile = profile
               } else {
                   // 如果没有 profile 传递过来，HomeVC 的 userProfile 依然是 nil
                   // 这可能意味着用户未登录就到达了这里，或者传递逻辑有误
                   print("ViewController (TabBarController): currentUserProfile was not set. HomeVC will have a nil profile.")
                   // 你可能需要一个默认的 UserProfile，或者在这里处理未登录状态
                    homeVC.userProfile = UserProfile(name: "Guest") // 示例默认值
               }

        
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        
         let profileVC = ProfileViewController()
                profileVC.title = "Profile"
                if let profile = currentUserProfile { // 同样可以传递给 ProfileVC
                    profileVC.userProfile = profile
                }
                let profileNav = UINavigationController(rootViewController: profileVC)
                profileNav.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person.crop.circle"), tag: 1)

 
    
    
        // Add them to the tab bar
        viewControllers = [homeNav, profileVC] // Add profileNav if you want
        
        // Style the tab bar (optional but ✨ nice ✨)
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = UIColor.systemBackground
    }
    
 
}

