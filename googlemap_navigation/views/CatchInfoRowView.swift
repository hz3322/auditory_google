import UIKit

class CatchInfoRowView: UIView {
    // Thresholds for coloring, if you still want them:
    private let missedThreshold = 0
    private let yellowThreshold = 15
    private let greenThreshold = 30

    init(info: CatchInfo) {
        super.init(frame: .zero)
        setupUI(info: info)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI(info: CatchInfo) {
            let personLabel = UILabel()
            personLabel.text = "🧑"
            personLabel.font = .systemFont(ofSize: 22)

            let expectedArrival = UILabel()
            expectedArrival.text = "Train: \(info.expectedArrival)"
            expectedArrival.font = .systemFont(ofSize: 16)
            expectedArrival.textColor = .darkGray

            // 显示 timeLeftToCatch
            let timeLeftLabel = UILabel()
            let timeLeft = Int(round(info.timeLeftToCatch))
            if timeLeft > 0 {
                timeLeftLabel.text = "\(timeLeft) sec left"
                timeLeftLabel.textColor = .systemGreen
            } else {
                timeLeftLabel.text = "Missed"
                timeLeftLabel.textColor = .systemRed
            }
            timeLeftLabel.font = .systemFont(ofSize: 16)
            timeLeftLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true

            let resultIcon = UILabel()
            resultIcon.text = info.canCatch ? "✅" : "❌"
            resultIcon.font = .systemFont(ofSize: 22)
            resultIcon.textColor = info.canCatch ? .systemGreen : .systemRed
            resultIcon.textAlignment = .center
            resultIcon.widthAnchor.constraint(equalToConstant: 32).isActive = true

            let hourglass = UILabel()
            hourglass.text = "⏳"
            hourglass.font = .systemFont(ofSize: 18)

            let hStack = UIStackView(arrangedSubviews: [
                personLabel,
                expectedArrival,
                timeLeftLabel,
                hourglass,
                resultIcon
            ])
            hStack.axis = .horizontal
            hStack.spacing = 18
            hStack.alignment = .center
            hStack.distribution = .fill
            hStack.isLayoutMarginsRelativeArrangement = true
            hStack.layoutMargins = UIEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)

            addSubview(hStack)
            hStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hStack.topAnchor.constraint(equalTo: self.topAnchor),
                hStack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                hStack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                hStack.trailingAnchor.constraint(equalTo: self.trailingAnchor)
            ])
            self.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
            self.layer.cornerRadius = 8
    }
}
