import UIKit
import GoogleMaps
import CoreLocation

class ViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        // Initialize Google Maps
        GMSServices.provideAPIKey("AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE")
        
        // Set up Home
        let homeVC = HomeViewController()
        homeVC.title = "Home"
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        
 
    
    
        // Add them to the tab bar
        viewControllers = [homeNav] // Add profileNav if you want
        
        // Style the tab bar (optional but ✨ nice ✨)
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = UIColor.systemBackground
    }
    
 
}

