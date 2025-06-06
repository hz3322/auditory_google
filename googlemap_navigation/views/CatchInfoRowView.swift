import UIKit

class CatchInfoRowView: UIView {
    var onMissed: (() -> Void)?
    
    // MARK: - Properties
    private let lineBadgeLabel = PaddingLabel()
    private let arrivalTimeLabel = UILabel()
    private let statusLabel = UILabel()
    private let iconLabel = UILabel()
    
    private var info: CatchInfo
    
    // MARK: - Initialization
    init(info: CatchInfo) {
        self.info = info
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Line Badge
        let accentColor = UIColor(hex: info.lineColorHex)
        lineBadgeLabel.text = info.lineName
        lineBadgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        lineBadgeLabel.textColor = accentColor.isLight ? .black.withAlphaComponent(0.8) : .white
        lineBadgeLabel.backgroundColor = accentColor
        lineBadgeLabel.layer.cornerRadius = 6
        lineBadgeLabel.clipsToBounds = true
        lineBadgeLabel.textAlignment = .center
        
        // Arrival Time
        arrivalTimeLabel.text = info.expectedArrival
        arrivalTimeLabel.font = .systemFont(ofSize: 16, weight: .medium)
        arrivalTimeLabel.textColor = .label
        
        // Status Label
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textAlignment = .right
        
        // Icon Label
        iconLabel.font = .systemFont(ofSize: 16)
        iconLabel.textAlignment = .center
        
        // Main Stack
        let mainStack = UIStackView(arrangedSubviews: [
            lineBadgeLabel,
            arrivalTimeLabel,
            statusLabel,
            iconLabel
        ])
        mainStack.axis = .horizontal
        mainStack.spacing = 8
        mainStack.alignment = .center
        mainStack.distribution = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            lineBadgeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
            iconLabel.widthAnchor.constraint(equalToConstant: 24)
        ])
        
        // Initial UI update
        updateUI(with: info)
    }
    
    // MARK: - UI Updates
    public func update(with info: CatchInfo) {
        self.info = info
        updateUI(with: info)
        
        if info.catchStatus == .missed {
            onMissed?()
        }
    }
    
    private func updateUI(with info: CatchInfo) {
        arrivalTimeLabel.text = info.expectedArrival
        
        let timeLeftRounded = Int(round(info.timeLeftToCatch))
        var statusText = info.catchStatus.displayText
        
        if info.catchStatus != .missed {
            statusText += String(format: " · %ds", timeLeftRounded)
        } else {
            if timeLeftRounded < 0 {
                statusText += " (by \(abs(timeLeftRounded))s)"
            }
        }
        
        statusLabel.text = statusText
        statusLabel.textColor = info.catchStatus.displayColor
        
        // Update icon
        if let iconName = info.catchStatus.systemIconName,
           let iconImage = UIImage(systemName: iconName) {
            let attachment = NSTextAttachment()
            let tintedImage = iconImage.withTintColor(info.catchStatus.displayColor, renderingMode: .alwaysOriginal)
            attachment.image = tintedImage
            let imageSize = iconLabel.font.pointSize
            attachment.bounds = CGRect(x: 0, y: -2, width: imageSize, height: imageSize)
            iconLabel.attributedText = NSAttributedString(attachment: attachment)
        }
        
        // Background color
        UIView.animate(withDuration: 0.3) {
            self.backgroundColor = info
                .catchStatus
                .displayColor
                .withAlphaComponent(0.08)
        }
    }
}
