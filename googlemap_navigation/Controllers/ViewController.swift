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
        
        // Set up Past Trips
        let pastTripsVC = PastTripsViewController()
        pastTripsVC.title = "Past Trips"
        let pastTripsNav = UINavigationController(rootViewController: pastTripsVC)
        pastTripsNav.tabBarItem = UITabBarItem(title: "Past Trips", image: UIImage(systemName: "clock"), tag: 1)
        
    
        // Add them to the tab bar
        viewControllers = [homeNav, pastTripsNav] // Add profileNav if you want
        
        // Style the tab bar (optional but ✨ nice ✨)
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = .white
    }
}

