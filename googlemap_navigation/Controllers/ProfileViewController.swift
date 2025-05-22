import UIKit
struct UserProfile {
    var name: String
    // You can add more fields here as needed, e.g., email, preferences, etc.
}

class ProfileViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Profile"
    }
} 
