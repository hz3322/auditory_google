import UIKit

class RouteSummaryViewController: UIViewController {

    var totalEstimatedTime: String?
    var walkToStationTime: String?
    var walkToDestinationTime: String?
    var transitInfos: [TransitInfo] = []  // Changed to array to support transfers

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        print("RouteSummaryVC created successfully")
        view.backgroundColor = .white
        title = "Route Summary"
        setupLayout()
        populateSummary()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func populateSummary() {
        let totalLabel = makeLabel(text: "⏱️ Total Estimated Time: \(totalEstimatedTime ?? "--")", font: .boldSystemFont(ofSize: 18))
        stackView.addArrangedSubview(totalLabel)

        if let walkStart = walkToStationTime {
            let walkCard = makeCard(title: "🚶 Walk to Station", subtitle: walkStart)
            stackView.addArrangedSubview(walkCard)
        }

        // Add all transit segments
        for (index, info) in transitInfos.enumerated() {
            let transitCard = makeTransitCard(info: info, isTransfer: index > 0)
            stackView.addArrangedSubview(transitCard)
            
            // Add transfer walk card if not the last segment
            if index < transitInfos.count - 1 {
                let transferWalkCard = makeCard(title: "🚶 Transfer Walk", subtitle: "Walk to next station")
                stackView.addArrangedSubview(transferWalkCard)
            }
        }

        if let walkEnd = walkToDestinationTime {
            let walkCard = makeCard(title: "🚶 Walk to Destination", subtitle: walkEnd)
            stackView.addArrangedSubview(walkCard)
        }

        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        startButton.backgroundColor = .systemGreen
        startButton.layer.cornerRadius = 8
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        startButton.addTarget(self, action: #selector(startNavigationTapped), for: .touchUpInside)

        stackView.addArrangedSubview(startButton)
    }

    @objc private func startNavigationTapped() {
        print("🧭 Navigation started!")
        // TODO: Present turn-by-turn or audio guidance view
    }

    private func makeLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.numberOfLines = 0
        return label
    }

    private func makeCard(title: String, subtitle: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemGray6
        card.layer.cornerRadius = 10

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 16)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .gray

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        return card
    }

    private func makeTransitCard(info: TransitInfo, isTransfer: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(hex: info.lineColorHex ?? "#DADADA")
        card.layer.cornerRadius = 10

        let lineLabel = UILabel()
        lineLabel.text = "🚇 \(info.lineName) Line"
        lineLabel.font = .boldSystemFont(ofSize: 16)
        lineLabel.textColor = .white

        let stationLabel = UILabel()
        stationLabel.text = "From \(info.departureStation) → \(info.arrivalStation)"
        stationLabel.font = .systemFont(ofSize: 14)
        stationLabel.textColor = .white

        let durationLabel = UILabel()
        durationLabel.text = "⏱️ \(info.durationText)"
        durationLabel.font = .systemFont(ofSize: 14)
        durationLabel.textColor = .white

        let stopsLabel = UILabel()
        stopsLabel.font = .systemFont(ofSize: 12)
        stopsLabel.textColor = .white
        stopsLabel.numberOfLines = 0
        stopsLabel.text = info.stopNames.joined(separator: " → ")
        stopsLabel.isHidden = true

        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle("Show Stops ⬇️", for: .normal)
        toggleButton.tintColor = .white
        toggleButton.addAction(UIAction { _ in
            stopsLabel.isHidden.toggle()
            toggleButton.setTitle(stopsLabel.isHidden ? "Show Stops ⬇️" : "Hide Stops ⬆️", for: .normal)
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [lineLabel, stationLabel, durationLabel, toggleButton, stopsLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        return card
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexFormatted.hasPrefix("#") { hexFormatted.removeFirst() }

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
