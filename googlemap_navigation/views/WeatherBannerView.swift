import UIKit

/// A rounded weather banner view with two lines of text and gradient background
class WeatherBannerView: UIView {
    
    // MARK: - Subviews
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let conditionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    private var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.cornerRadius = 12
        // Set default light gradient
        layer.colors = [
            UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0).cgColor,
            UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0).cgColor
        ]
        return layer
    }()
    
    private var weatherEffectLayer: CAEmitterLayer?
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        layer.cornerRadius = 12
        clipsToBounds = true
        
        // Add a subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 2
        
        layer.addSublayer(gradientLayer)
        addSubview(stackView)
        
        stackView.addArrangedSubview(conditionLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    /// Update weather content
    func configure(condition: String, suggestion: String, gradient: (start: UIColor, end: UIColor)) {
        // Update text with condition and suggestion in one line
        conditionLabel.text = condition
        
        // Use light gradient for all conditions
        gradientLayer.colors = [
            UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0).cgColor,
            UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0).cgColor
        ]
        
        // Update weather effect
        updateWeatherEffect(for: condition)
    }
    
    /// Returns the current weather condition without emoji
    func getCurrentCondition() -> String? {
        return conditionLabel.text?.components(separatedBy: " ").first
    }
    
    private func getEmoji(for condition: String) -> String {
        switch condition.lowercased() {
        case "clear", "sunny": return "☀️"
        case "clouds": return "☁️"
        case "rain", "drizzle": return "🌧"
        case "snow": return "❄️"
        case "thunderstorm": return "⛈"
        case "mist", "fog", "haze": return "🌫"
        default: return "🌤"
        }
    }
    
    private func updateWeatherEffect(for condition: String) {
        // Remove existing effect
        weatherEffectLayer?.removeFromSuperlayer()
        weatherEffectLayer = nil
        
        // Add new effect based on condition
        switch condition.lowercased() {
        case "rain", "drizzle":
            weatherEffectLayer = makeRainEmitter()
        case "snow":
            weatherEffectLayer = makeSnowEmitter()
        case "thunderstorm":
            weatherEffectLayer = makeThunderstormEmitter()
        default:
            break
        }
        
        if let effectLayer = weatherEffectLayer {
            layer.insertSublayer(effectLayer, at: 0)
        }
    }
    
    private func makeRainEmitter() -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        
        let cell = CAEmitterCell()
        cell.birthRate = 100
        cell.lifetime = 3.0
        cell.velocity = 400
        cell.velocityRange = 100
        cell.emissionLongitude = .pi
        cell.scale = 0.1
        cell.scaleRange = 0.05
        
        // Create a simple raindrop shape
        let size = CGSize(width: 2, height: 10)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        cell.contents = image?.cgImage
        cell.alphaSpeed = -0.1
        cell.color = UIColor.white.cgColor
        
        emitter.emitterCells = [cell]
        return emitter
    }
    
    private func makeSnowEmitter() -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        
        let cell = CAEmitterCell()
        cell.birthRate = 50
        cell.lifetime = 6.0
        cell.velocity = 200
        cell.velocityRange = 50
        cell.emissionLongitude = .pi
        cell.scale = 0.1
        cell.scaleRange = 0.05
        
        // Create a simple snowflake shape
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        cell.contents = image?.cgImage
        cell.alphaSpeed = -0.05
        cell.color = UIColor.white.cgColor
        
        // Add some swaying motion
        cell.yAcceleration = 20
        cell.xAcceleration = 10
        
        emitter.emitterCells = [cell]
        return emitter
    }
    
    private func makeThunderstormEmitter() -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        
        let cell = CAEmitterCell()
        cell.birthRate = 150
        cell.lifetime = 2.0
        cell.velocity = 500
        cell.velocityRange = 150
        cell.emissionLongitude = .pi
        cell.scale = 0.1
        cell.scaleRange = 0.05
        
        // Create a simple raindrop shape
        let size = CGSize(width: 2, height: 12)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        cell.contents = image?.cgImage
        cell.alphaSpeed = -0.2
        cell.color = UIColor.white.cgColor
        
        emitter.emitterCells = [cell]
        return emitter
    }
} 
