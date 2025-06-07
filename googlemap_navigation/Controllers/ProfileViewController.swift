import UIKit
struct UserProfile {
    var name: String
}

class ProfileViewController: UIViewController {

    var userProfile: UserProfile?

    @IBOutlet weak var nameLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Profile"

        if let profile = userProfile {
            print("ProfileViewController: Received profile for \(profile.name)")
            nameLabel?.text = profile.name // 使用可选链以防 IBOutlet 未连接
            // emailLabel?.text = profile.email // 如果有 email 字段
        } else {
            print("ProfileViewController: UserProfile was not set.")
            nameLabel?.text = "N/A"
            // emailLabel?.text = "N/A"
        }
    }
}
