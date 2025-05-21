import UIKit
class LogoTitleHeaderView: UIView {
    init(title: String) {
        super.init(frame: .zero)
        setupUI(title: title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI(title: String) {
        let imageView = UIImageView(image: UIImage(named: "ontimego_logo"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

    
        let hStack = UIStackView(arrangedSubviews: [imageView, titleLabel])
        hStack.axis = .horizontal
        hStack.spacing = 12
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            hStack.topAnchor.constraint(equalTo: self.topAnchor, constant: 6),
            hStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -6)
        ])
    }
}
extension UIViewController {
    func addLogoTitleHeader(title: String, height: CGFloat = 66) -> LogoTitleHeaderView {
        let header = LogoTitleHeaderView(title: title)
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            header.heightAnchor.constraint(equalToConstant: height)
        ])
        return header
    }
}
