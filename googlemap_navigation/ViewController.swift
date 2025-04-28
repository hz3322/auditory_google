import UIKit
import GoogleMaps
import CoreLocation

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Google Maps
        GMSServices.provideAPIKey("AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE")
        
        // Create and set up navigation controller with HomeViewController
        let homeVC = HomeViewController()
        let navController = UINavigationController(rootViewController: homeVC)
        
        // Add navigation controller as child
        addChild(navController)
        view.addSubview(navController.view)
        navController.view.frame = view.bounds
        navController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navController.didMove(toParent: self)
    }
}

