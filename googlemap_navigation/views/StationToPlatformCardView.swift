import UIKit
import FirebaseFirestore

/// A view that displays and manages station to platform walking time information
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
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        // Initial text will be set in configure
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.text = "Est. --:--"
        label.font = .systemFont(ofSize: 23, weight: .bold)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let recordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Start Recording", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        btn.backgroundColor = UIColor(red: 34/255, green: 127/255, blue: 255/255, alpha: 1) // Theme blue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 14
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        btn.setContentHuggingPriority(.defaultLow, for: .horizontal) // Allow button to compress
        return btn
    }()

    private let elapsedTimeLabel: UILabel = { // New label for elapsed time
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        label.textColor = .systemGray // Or a distinct color for elapsed time
        label.textAlignment = .right // Align right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true // Initially hidden
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal) // Prefer to keep its intrinsic content size
        return label
    }()

    private let statsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("View Stats", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.backgroundColor = UIColor.systemGray6
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return btn
    }()

    // MARK: - State
    private var stationNaptanId: String? // Use naptanId for Firestore
    private var stationDisplayName: String? // Store display name for UI
    private var isRecording = false
    private let db = Firestore.firestore()
    private var startTime: Date?
    private var durations: [TimeInterval] = []
    private var recordingTimer: Timer? // Timer for elapsed time

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

        // Horizontal stack for record button and elapsed time
        let recordStack = UIStackView(arrangedSubviews: [recordButton, elapsedTimeLabel])
        recordStack.axis = .horizontal
        recordStack.spacing = 10 // Space between button and time
        recordStack.alignment = .center
        recordStack.translatesAutoresizingMaskIntoConstraints = false

        // Main Vertical stack
        let vStack = UIStackView(arrangedSubviews: [titleLabel, timeLabel, statusLabel, recordStack, statsButton]) // Added recordStack
        vStack.axis = .vertical
        vStack.spacing = 10
        vStack.alignment = .fill
        vStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(vStack)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: self.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            vStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            vStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            vStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            vStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 20) // Adjusted bottom spacing
        ])

        // Ensure recordStack is constrained correctly within the vStack
        recordStack.leadingAnchor.constraint(equalTo: vStack.leadingAnchor).isActive = true
        recordStack.trailingAnchor.constraint(equalTo: vStack.trailingAnchor).isActive = true

        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        statsButton.addTarget(self, action: #selector(statsButtonTapped), for: .touchUpInside)

        // Initial state of record button
        recordButton.isEnabled = false
        recordButton.alpha = 0.5
    }

    // MARK: - Public API
    func configure(stationName: String) {
//        self.stationNaptanId = naptanId
        self.stationDisplayName = stationName
        self.titleLabel.text = stationName // Set title label text
        self.timeLabel.text = "Est. --:--"
        self.statusLabel.text = ""
        self.durations = []
        fetchEstimatedTime()
        fetchStats()
        recordButton.isEnabled = true
        recordButton.alpha = 1.0
        recordButton.backgroundColor = UIColor(red: 34/255, green: 127/255, blue: 255/255, alpha: 1)
        recordButton.setTitle("Start Recording", for: .normal)
        // Hide elapsed time label
        elapsedTimeLabel.isHidden = true
        elapsedTimeLabel.text = ""
    }

    // MARK: - Firestore
    private func fetchEstimatedTime() {
        guard let naptanId = stationNaptanId else { return } // Use naptanId
        db.collection("stationToPlatformTimes").document(naptanId).collection("records") // Use naptanId
            .order(by: "timestamp", descending: true).limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching estimated time: \(error.localizedDescription)")
                    self.setTimeUI(time: 120, source: "Default")
                    return
                }
                if let doc = snapshot?.documents.first, let time = doc.data()["duration"] as? TimeInterval {
                    self.setTimeUI(time: time, source: "Database")
                } else {
                    self.setTimeUI(time: 120, source: "Default")
                }
            }
    }

    private func fetchStats() {
        guard let naptanId = stationNaptanId else { return } // Use naptanId
        db.collection("stationToPlatformTimes").document(naptanId).collection("records") // Use naptanId
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching stats: \(error.localizedDescription)")
                    return
                }
                self.durations = snapshot?.documents.compactMap { $0.data()["duration"] as? TimeInterval } ?? []
                let count = self.durations.count
                self.statsButton.setTitle("View Stats (\(count))", for: .normal)
            }
    }

    private func uploadNewRecord(duration: TimeInterval) {
        guard let naptanId = stationNaptanId else { return } // Use naptanId
        let record: [String: Any] = [
            "duration": duration,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("stationToPlatformTimes").document(naptanId).collection("records") // Use naptanId
            .addDocument(data: record) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    print("Error uploading record: \(error.localizedDescription)")
                    self.showAlert(title: "Error", message: "Failed to upload record")
                } else {
                    print("Record uploaded successfully")
                    self.setTimeUI(time: duration, source: "You")
                    self.fetchStats()
                }
            }
    }

    // MARK: - UI State Logic
    private func setTimeUI(time: TimeInterval, source: String) {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        timeLabel.text = String(format: "Est. %d:%02d", min, sec)
        statusLabel.text = "Source: \(source)"
        if source == "You" {
            timeLabel.textColor = .systemGreen
            statusLabel.textColor = .systemGreen
        } else if source == "Default" {
            timeLabel.textColor = .secondaryLabel
            statusLabel.textColor = .secondaryLabel
        } else {
            timeLabel.textColor = .systemBlue
            statusLabel.textColor = .systemBlue
        }
        // Ensure timeLabel and statusLabel are visible when displaying time
        timeLabel.isHidden = false
        statusLabel.isHidden = false
        // Hide titleLabel when showing estimated time
        titleLabel.isHidden = true
    }

    private func setInitialUI() {
        titleLabel.text = stationDisplayName ?? "Station to Platform"
        titleLabel.isHidden = false
        timeLabel.isHidden = true
        statusLabel.isHidden = true
        elapsedTimeLabel.isHidden = true // Ensure elapsed time is hidden
    }

    private func updateElapsedTimeLabel() {
        guard let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let formattedTime = formatTime(elapsed)
        elapsedTimeLabel.text = formattedTime
    }

    // MARK: - Actions
    @objc private func recordButtonTapped() {
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        startTime = Date()
        setRecordingUI() // Update UI elements state for recording
        recordButton.setTitle("Stop Recording", for: .normal)
        recordButton.backgroundColor = .systemRed
        statsButton.isEnabled = false
        statsButton.alpha = 0.5

        // Show and start elapsed time timer
        elapsedTimeLabel.isHidden = false
        elapsedTimeLabel.text = "0:00" // Initial time display
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            self?.updateElapsedTimeLabel()
        })
    }

    private func stopRecording() {
        guard let startTime = startTime else { return }
        isRecording = false
        recordButton.setTitle("Start Recording", for: .normal)
        recordButton.backgroundColor = UIColor(red: 34/255, green: 127/255, blue: 255/255, alpha: 1)
        statsButton.isEnabled = true
        statsButton.alpha = 1.0

        // Stop and hide elapsed time timer and label
        recordingTimer?.invalidate()
        recordingTimer = nil
        elapsedTimeLabel.isHidden = true
        elapsedTimeLabel.text = ""

        let duration = Date().timeIntervalSince(startTime)
        uploadNewRecord(duration: duration)
        // UI will be updated by setTimeUI after upload
    }

    private func setRecordingUI() {
        // Hide estimated time and status when recording
        timeLabel.isHidden = true
        statusLabel.isHidden = true
        // Ensure titleLabel is visible, maybe update its text if needed
        titleLabel.isHidden = false
        titleLabel.text = stationDisplayName ?? "Station to Platform" // Revert title to station name or default
        titleLabel.font = .systemFont(ofSize: 19, weight: .semibold) // Revert font
        titleLabel.textAlignment = .left // Revert alignment
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

    // Deinitializer to stop the timer if the view is deallocated
    deinit {
        recordingTimer?.invalidate()
    }
}
