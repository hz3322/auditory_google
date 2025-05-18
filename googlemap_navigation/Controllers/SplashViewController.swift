import UIKit

class SplashViewController: UIViewController {
    private let sloganLabel: UILabel = {
        let label = UILabel()
        label.text = "All the info, none of the stress. Always catch your tube, your way."
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .systemBlue
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(sloganLabel)
        NSLayoutConstraint.activate([
            sloganLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sloganLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            sloganLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showSloganAndProceed()
    }

    private func showSloganAndProceed() {
        UIView.animate(withDuration: 0.9, delay: 0, options: .curveEaseIn, animations: {
            self.sloganLabel.alpha = 1
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.goToHome()
            }
        })
    }

    private func goToHome() {
        let homeVC = HomeViewController()
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UINavigationController(rootViewController: homeVC)
            window.makeKeyAndVisible()
        }
    }
}
