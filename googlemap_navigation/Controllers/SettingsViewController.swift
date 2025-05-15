import UIKit

struct UserSettings {
    static var enableSound: Bool = true
    static var enableSpeech: Bool = true
    static var enableVisualCue: Bool = true
}

class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        title = "Settings"
    }
}
