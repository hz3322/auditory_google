import UIKit
import GoogleMaps
import CoreLocation
class ViewController: UIViewController, CLLocationManagerDelegate{
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    
        // Do any additional setup after loading the view.
        GMSServices.provideAPIKey("AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE")
      
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            return
        }
        let coordinate = location.coordinate
        let camera = GMSCameraPosition.camera(withLatitude: coordinate.latitude, longitude: coordinate.longitude, zoom: 6)
        let mapView = GMSMapView.map(withFrame: view.bounds, camera: camera)
        view.addSubview(mapView)
        
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        marker.title = "London"
        marker.snippet = "UK"
        marker.map = mapView
    }
    
    


}

