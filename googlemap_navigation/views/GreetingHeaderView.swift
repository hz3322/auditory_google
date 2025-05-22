import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class GreetingHeaderView: UIView {
    init(name: String, time: String) {
        super.init(frame: .zero)
        let logo = UIImageView(image: UIImage(named: "ontimego_logo"))
        logo.contentMode = .scaleAspectFit
        logo.widthAnchor.constraint(equalToConstant: 44).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        let label = UILabel()
        label.text = "Hi, \(name)! 👋\n\(time)"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor(red: 41/255, green: 56/255, blue: 80/255, alpha: 1)
        label.numberOfLines = 2
        
        let stack = UIStackView(arrangedSubviews: [logo, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
