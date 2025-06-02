import UIKit
import FirebaseFirestore

class StationToPlatformCardView: UIView {
    // MARK: - UI Components
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.10
        v.layer.shadowRadius = 12
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Station to Platform"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timeAndSourceLabel: UILabel = {
        let label = UILabel()
        label.text = "Est. --:-- (Default)"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let recordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Start Recording", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        btn.backgroundColor = UIColor(red: 34/255, green: 127/255, blue: 255/255, alpha: 1) // 主题蓝
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return btn
    }()

    private let statsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("View Stats", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.backgroundColor = UIColor.systemGray6
        btn.layer.cornerRadius = 10
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return btn
    }()

    // MARK: - State
    private var currentStation: String?
    private var isRecording = false
    private var startTime: Date?
    private let db = Firestore.firestore()
    private var durations: [TimeInterval] = []

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - UI Layout
    private func setupUI() {
        backgroundColor = .clear
        addSubview(containerView)
        let vStack = UIStackView(arrangedSubviews: [titleLabel, timeAndSourceLabel, recordButton, statsButton])
        vStack.axis = .vertical
        vStack.spacing = 8
        vStack.alignment = .fill
        vStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(vStack)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: self.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            vStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            vStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            vStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        statsButton.addTarget(self, action: #selector(statsButtonTapped), for: .touchUpInside)
    }

    // MARK: - Public API
    func configure(with station: String) {
        currentStation = station
        timeAndSourceLabel.text = "Est. --:-- (Default)"
        timeAndSourceLabel.textColor = .secondaryLabel
        durations = []
        fetchEstimatedTime()
        fetchStats()
        recordButton.isEnabled = true
        recordButton.alpha = 1.0
        recordButton.backgroundColor = UIColor(red: 34/255, green: 127/255, blue: 255/255, alpha: 1)
        recordButton.setTitle("Start Recording", for: .normal)
    }

    // MARK: - Firestore
    private func fetchEstimatedTime() {
        guard let station = currentStation else { return }
        db.collection("stationToPlatformTimes").document(sanitizedStationKey(station)).collection("records")
            .order(by: "timestamp", descending: true).limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let doc = snapshot?.documents.first, let time = doc.data()["duration"] as? TimeInterval {
                    self.setTimeUI(time: time, source: "Crowdsourced")
                } else {
                    self.setTimeUI(time: 120, source: "Default")
                }
            }
    }

    private func fetchStats() {
        guard let station = currentStation else { return }
        db.collection("stationToPlatformTimes").document(sanitizedStationKey(station)).collection("records")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.durations = snapshot?.documents.compactMap { $0.data()["duration"] as? TimeInterval } ?? []
                let count = self.durations.count
                self.statsButton.setTitle("View Stats (\(count))", for: .normal)
            }
    }

    private func uploadNewRecord(duration: TimeInterval) {
        guard let station = currentStation else { return }
        let record: [String: Any] = [
            "duration": duration,
            "timestamp": Timestamp(date: Date())
        ]
        db.collection("stationToPlatformTimes").document(sanitizedStationKey(station)).collection("records")
            .addDocument(data: record) { [weak self] error in
                guard let self = self else { return }
                self.setTimeUI(time: duration, source: "You")
                self.fetchStats()
            }
    }

    // MARK: - UI State Logic
    private func setTimeUI(time: TimeInterval, source: String) {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        let sourceDesc: String
        switch source {
            case "You":      sourceDesc = "You"
            case "Crowdsourced": sourceDesc = "Crowdsourced"
            case "Default":  sourceDesc = "Default"
            default:         sourceDesc = source
        }
        timeAndSourceLabel.text = String(format: "Est. %d:%02d  (%@)", min, sec, sourceDesc)
        if source == "You" {
            timeAndSourceLabel.textColor = .systemGreen
        } else if source == "Default" {
            timeAndSourceLabel.textColor = .secondaryLabel
        } else {
            timeAndSourceLabel.textColor = .systemBlue
        }
    }

    private func setRecordingUI() {
        timeAndSourceLabel.text = "Recording..."
        timeAndSourceLabel.textColor = .systemOrange
    }

    // MARK: - Actions
    @objc private func recordButtonTapped() {
        if !isRecording {
            isRecording = true
            startTime = Date()
            setRecordingUI()
            recordButton.setTitle("Stop Recording", for: .normal)
            recordButton.backgroundColor = .systemRed
            statsButton.isEnabled = false
            statsButton.alpha = 0.5
        } else {
            guard let startTime = startTime else { return }
            isRecording = false
            recordButton.setTitle("Start Recording", for: .normal)
            recordButton.backgroundColor = UIColor(red: 34/255, green: 127/255, blue: 255/255, alpha: 1)
            statsButton.isEnabled = true
            statsButton.alpha = 1.0
            let duration = Date().timeIntervalSince(startTime)
            uploadNewRecord(duration: duration)
        }
    }

    @objc private func statsButtonTapped() {
        guard !durations.isEmpty else {
            showAlert(title: "No Data", message: "No records available for this station")
            return
        }
        let avg = durations.reduce(0, +) / Double(durations.count)
        let minV = durations.min() ?? 0
        let maxV = durations.max() ?? 0
        let msg = """
        Total Records: \(durations.count)
        Average Time: \(formatTime(avg))
        Fastest: \(formatTime(minV))
        Slowest: \(formatTime(maxV))
        """
        showAlert(title: "Station Statistics", message: msg)
    }

    // MARK: - Helpers
    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
    private func showAlert(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            vc.present(alert, animated: true)
        }
    }

    private func sanitizedStationKey(_ station: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/.#$[]")
        var safe = station
        safe = safe.components(separatedBy: invalidChars).joined(separator: "-")
        safe = safe.replacingOccurrences(of: " ", with: "_")
        return safe
    }
}
