import UIKit

class SplashViewController: UIViewController {
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "ontimego_logo"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let sloganLabel: UILabel = {
        let label = UILabel()
        label.text = "All the catch info here!"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .black
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        view.addSubview(logoImageView)
                NSLayoutConstraint.activate([
                    logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -90),
                    logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
                    logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor, multiplier: 0.4)
                ])
        
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
        UIView.animate(withDuration: 1.5, delay: 0, options: .curveEaseIn, animations: {
            self.sloganLabel.alpha = 1
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.goToHome()
            }
        })
    }

    private func goToHome() {
        let homeVC = HomeViewController()
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UINavigationController(rootViewController: homeVC)
            window.makeKeyAndVisible()
        }
    }
}
