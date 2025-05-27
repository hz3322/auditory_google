import UIKit

class CatchInfoRowView: UIView {
    init(info: CatchInfo) {
           super.init(frame: .zero)
           setupUI(info: info)
       }

       required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

       private func setupUI(info: CatchInfo) {
           // 1. Expected Arrival Time Label
           let expectedArrivalLabel = UILabel() // Renamed for clarity
           expectedArrivalLabel.text = "Train: \(info.expectedArrival)"
           expectedArrivalLabel.font = .systemFont(ofSize: 16, weight: .medium) // Slightly bolder
           expectedArrivalLabel.textColor = .label // Adapts to light/dark mode

           // 2. Time Left / Status Label
           let statusAndTimeLabel = UILabel()
           let timeLeftRounded = Int(round(info.timeLeftToCatch))
           
           var statusText = "\(info.catchStatus.displayText)"
           if info.catchStatus != .missed {
               statusText += " · \(abs(timeLeftRounded))s" // Show seconds for non-missed
           } else if timeLeftRounded < 0 {
               statusText += " (by \(abs(timeLeftRounded))s)" // Show how much it was missed by
           }

           statusAndTimeLabel.text = statusText
           statusAndTimeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
           statusAndTimeLabel.textColor = info.catchStatus.displayColor // Use color from CatchStatus
           statusAndTimeLabel.textAlignment = .left // Or .right if preferred next to icon

           // 3. Result Icon
           let resultIconLabel = UILabel()
           resultIconLabel.font = .systemFont(ofSize: 20)
           resultIconLabel.textAlignment = .center
           if let iconName = info.catchStatus.systemIconName {
               resultIconLabel.text = UIImage(systemName: iconName)?.withRenderingMode(.alwaysTemplate).description

                let iconImageView = UIImageView()
                if let iconName = info.catchStatus.systemIconName {
                    iconImageView.image = UIImage(systemName: iconName)?.withTintColor(info.catchStatus.displayColor, renderingMode: .alwaysOriginal)
                }
                iconImageView.contentMode = .scaleAspectFit
               // For UILabel, we'll try setting the text and tinting.
               if let iconName = info.catchStatus.systemIconName { // Assuming this gives an emoji or simple symbol char
                   resultIconLabel.text = iconName
               }
           }
           // The resultIcon label will primarily show the color via text.
           // For an actual icon, an UIImageView is better.
           // Let's change resultIcon to display the status text briefly or an emoji.
           // For this example, let's use the status text as the icon placeholder for simplicity for now.
           // A dedicated icon is better.
           if let iconName = info.catchStatus.systemIconName, let sfImage = UIImage(systemName: iconName) {
                let attachment = NSTextAttachment()
                attachment.image = sfImage.withTintColor(info.catchStatus.displayColor)
                attachment.bounds = CGRect(x: 0, y: -3, width: resultIconLabel.font.pointSize, height: resultIconLabel.font.pointSize)
                let attributedString = NSAttributedString(attachment: attachment)
                resultIconLabel.attributedText = attributedString
           } else {
               resultIconLabel.text = "" // Fallback
           }

           // 4. Horizontal Stack View
           let hStack = UIStackView(arrangedSubviews: [
               expectedArrivalLabel,
               statusAndTimeLabel, // This now combines status and time
               resultIconLabel       // This will be our status icon
           ])
           hStack.axis = .horizontal
           hStack.spacing = 12 // Adjusted spacing
           hStack.alignment = .center
           hStack.distribution = .fill // Let labels size naturally, icon fixed.

           // Give more room to text labels, fix icon size
           expectedArrivalLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
           statusAndTimeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
           resultIconLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
           resultIconLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
           NSLayoutConstraint.activate([
               resultIconLabel.widthAnchor.constraint(equalToConstant: 24), // Fixed width for icon
               resultIconLabel.heightAnchor.constraint(equalToConstant: 24) // Fixed height for icon
           ])


           hStack.isLayoutMarginsRelativeArrangement = true
           hStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16) // Adjusted margins

           addSubview(hStack)
           hStack.translatesAutoresizingMaskIntoConstraints = false
           NSLayoutConstraint.activate([
               hStack.topAnchor.constraint(equalTo: self.topAnchor),
               hStack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
               hStack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
               hStack.trailingAnchor.constraint(equalTo: self.trailingAnchor)
           ])
           
           self.backgroundColor = info.catchStatus.displayColor.withAlphaComponent(0.1)
//           self.backgroundColor = .secondarySystemBackground // Keep it neutral for now
           self.layer.cornerRadius = 10 // Consistent corner radius
       }
   }
