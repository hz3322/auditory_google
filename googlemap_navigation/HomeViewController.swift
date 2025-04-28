import UIKit
import GoogleMaps

class PastTripsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Past Trips"
    }
}

class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Settings"
    }
}

class HomeViewController: UIViewController {
    
    private let startNewTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start New Trip", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let pastTripsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Past Trips", for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Settings", for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Navigation App"
        
        view.addSubview(startNewTripButton)
        view.addSubview(pastTripsButton)
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            startNewTripButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startNewTripButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            startNewTripButton.widthAnchor.constraint(equalToConstant: 200),
            startNewTripButton.heightAnchor.constraint(equalToConstant: 50),
            
            pastTripsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pastTripsButton.topAnchor.constraint(equalTo: startNewTripButton.bottomAnchor, constant: 20),
            pastTripsButton.widthAnchor.constraint(equalToConstant: 200),
            pastTripsButton.heightAnchor.constraint(equalToConstant: 50),
            
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.topAnchor.constraint(equalTo: pastTripsButton.bottomAnchor, constant: 20),
            settingsButton.widthAnchor.constraint(equalToConstant: 200),
            settingsButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupActions() {
        startNewTripButton.addTarget(self, action: #selector(startNewTripTapped), for: .touchUpInside)
        pastTripsButton.addTarget(self, action: #selector(pastTripsTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    }
    
    @objc private func startNewTripTapped() {
        let routePreviewVC = RoutePreviewViewController()
        navigationController?.pushViewController(routePreviewVC, animated: true)
    }
    
    @objc private func pastTripsTapped() {
        let pastTripsVC = PastTripsViewController()
        navigationController?.pushViewController(pastTripsVC, animated: true)
    }
    
    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
} 