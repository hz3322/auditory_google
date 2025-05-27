import UIKit
import FirebaseAuth
import FirebaseCore

class LoginViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "ontimego_logo"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let usernameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Username"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Password"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Login", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Register", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupKeyboardDismissal()
        
        // Check if the user is already signed in with Firebase
        if let currentUser = Auth.auth().currentUser {
            print("User already signed in with UID: \(currentUser.uid)")
            self.enterMainApp(username: currentUser.displayName)
        } else {
            print("No user signed in. Waiting for user action.")
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add scroll view
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Add logo
        scrollView.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 40),
            logoImageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        // Add stack view
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        // Add text fields and buttons to stack view
        [usernameTextField, emailTextField, passwordTextField, loginButton, registerButton].forEach {
            stackView.addArrangedSubview($0)
            $0.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }
    }
    
    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardDismissal() {
        // Add tap gesture recognizer to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Add keyboard observers
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // If active text field is hidden by keyboard, scroll to it
        if let activeField = view.findFirstResponder() as? UITextField {
            let rect = activeField.convert(activeField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    @objc private func registerButtonTapped() {
        // Dismiss keyboard first
        view.endEditing(true)
        
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let username = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            showAlert(title: "Missing Information", message: "Please fill in all fields.")
            return
        }
        
        // Validate email format
        if !isValidEmail(email) {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }
        
        // Validate password strength
        if password.count < 6 {
            showAlert(title: "Weak Password", message: "Password must be at least 6 characters long.")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Creating Account", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                print("📝 Starting registration process for email: \(email)")
                
                // Verify Firebase configuration
                guard let firebaseApp = FirebaseApp.app() else {
                    throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not properly configured"])
                }
                
                print("ℹ️ Firebase configuration:")
                print("- Project ID: \(firebaseApp.options.projectID ?? "Not set")")
                print("- Bundle ID: \(firebaseApp.options.bundleID ?? "Not set")")
                
                // Create user with email and password
                let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
                print("✅ User created successfully with UID: \(authResult.user.uid)")
                
                // Update display name
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = username
                try await changeRequest.commitChanges()
                print("✅ User profile updated with username: \(username)")
                
                // Dismiss loading alert
                await MainActor.run {
                    loadingAlert.dismiss(animated: true)
                }
                
                // Enter main app
                await MainActor.run {
                    self.enterMainApp(username: username)
                }
            } catch let error as NSError {
                print("❌ Registration error details:")
                print("- Error domain: \(error.domain)")
                print("- Error code: \(error.code)")
                print("- Error description: \(error.localizedDescription)")
                print("- Error user info: \(error.userInfo)")
                
                // Dismiss loading alert
                await MainActor.run {
                    loadingAlert.dismiss(animated: true)
                }
                
                // Show appropriate error message
                let errorMessage: String
                switch error.code {
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    errorMessage = "This email is already registered. Please try logging in instead."
                case AuthErrorCode.invalidEmail.rawValue:
                    errorMessage = "Please enter a valid email address."
                case AuthErrorCode.weakPassword.rawValue:
                    errorMessage = "Password is too weak. Please use a stronger password."
                case AuthErrorCode.networkError.rawValue:
                    errorMessage = "Network error. Please check your internet connection."
                case -1: // Our custom error for Firebase configuration
                    errorMessage = "App configuration error. Please try again later."
                default:
                    if error.domain == "FIRAuthErrorDomain" {
                        errorMessage = "Authentication error. Please try again later."
                    } else {
                        errorMessage = "Registration failed: \(error.localizedDescription)"
                    }
                }
                
                await MainActor.run {
                    showAlert(title: "Registration Failed", message: errorMessage)
                }
            }
        }
    }
    
    // Helper method to validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    @objc private func loginButtonTapped() {
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty, !password.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter email and password.")
            return
        }
        
        Task {
            do {
                let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
                print("✅ User signed in successfully with UID: \(authResult.user.uid)")
                
                await MainActor.run {
                    self.enterMainApp(username: authResult.user.displayName)
                }
            } catch {
                print("❌ Login error: \(error.localizedDescription)")
                await MainActor.run {
                    showAlert(title: "Login Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    // Helper to switch to the main app, passing username
    func enterMainApp(username: String?) {
        let homeVC = HomeViewController()
        
        // Always create a valid UserProfile
        let profileName = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Guest User"
        let userProfile = UserProfile(name: profileName)
        homeVC.userProfile = userProfile
        
        print("Setting up HomeViewController with UserProfile: \(profileName)")
        
        // Set HomeViewController as the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UINavigationController(rootViewController: homeVC)
            window.makeKeyAndVisible()
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: nil,
                              completion: nil)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
    }
}

// MARK: - UITextField Extension
extension UITextField {
    func paddingLeft(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
}

// MARK: - UIView Extension
extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder {
            return self
        }
        for subview in subviews {
            if let firstResponder = subview.findFirstResponder() {
                return firstResponder
            }
        }
        return nil
    }
}
