import UIKit
import GoogleMaps
import GooglePlaces
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth

struct APIKeys {
    static let googleMaps = "AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
    static let tflAppKey = "0bc9522b0b77427eb20e858550d6a072"
    static let openWeather = "5d62e37dfd0d091bdff855ad92030830"
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("🚀 Starting app initialization...")
        
        // Configure Firebase
        do {
            #if DEBUG
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            print("ℹ️ Firebase App Check: Using DebugProviderFactory for DEBUG builds.")
            #endif
            
            // Print current bundle identifier
            print("ℹ️ Current Bundle ID: \(Bundle.main.bundleIdentifier ?? "Not found")")
            
            // Configure Firebase
            FirebaseApp.configure()
            print("✅ Firebase configured successfully")
            
            // Verify Firebase configuration
            if let firebaseApp = FirebaseApp.app() {
                print("✅ Firebase app instance created successfully")
                print("ℹ️ Firebase options:")
                print("- Project ID: \(firebaseApp.options.projectID ?? "Not set")")
                print("- Bundle ID: \(firebaseApp.options.bundleID ?? "Not set")")
                print("- API Key: \(firebaseApp.options.apiKey ?? "Not set")")
                print("- Client ID: \(firebaseApp.options.clientID ?? "Not set")")
                print("- Database URL: \(firebaseApp.options.databaseURL ?? "Not set")")
                print("- Storage Bucket: \(firebaseApp.options.storageBucket ?? "Not set")")
                print("- GCMSenderID: \(firebaseApp.options.gcmSenderID ?? "Not set")")
                
                // Check if Email/Password auth is enabled
                Auth.auth().fetchSignInMethods(forEmail: "test@example.com") { methods, error in
                    if let error = error {
                        print("❌ Error checking auth methods: \(error.localizedDescription)")
                    } else {
                        print("ℹ️ Available auth methods: \(methods ?? [])")
                    }
                }
            } else {
                print("❌ Failed to create Firebase app instance")
            }
            
        } catch {
            print("❌ Error configuring Firebase: \(error.localizedDescription)")
        }
        
        // Configure Google Maps
        GMSServices.provideAPIKey(APIKeys.googleMaps)
        GMSPlacesClient.provideAPIKey(APIKeys.googleMaps)
        print("✅ Google Maps configured successfully")
        
        return true
    }
    

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

