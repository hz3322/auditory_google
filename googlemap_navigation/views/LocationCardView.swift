import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class LocationCardView: UIView {
    init(locationText: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 243/255, green: 247/255, blue: 255/255, alpha: 1)
        layer.cornerRadius = 18
        let icon = UIImageView(image: UIImage(systemName: "location.fill"))
        icon.tintColor = .systemBlue
        icon.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = locationText
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        heightAnchor.constraint(equalToConstant: 46).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
