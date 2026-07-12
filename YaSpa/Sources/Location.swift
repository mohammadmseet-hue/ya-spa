import Foundation
import CoreLocation

/// One-shot location capture for the booking address: asks permission, grabs a
/// single fix, and reverse-geocodes it to prefill the street/district. The
/// coordinate travels with the order so the therapist can navigate straight to
/// the customer. Entirely optional — booking works with a typed address too.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var resolvedAddress = ""
    @Published var isResolving = false
    @Published var denied = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var hasPin: Bool { coordinate != nil }

    func request() {
        geocoder.cancelGeocode()   // drop any pending geocode from a prior tap
        isResolving = true
        denied = false
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            denied = true; isResolving = false
        }
    }

    func clear() { coordinate = nil; resolvedAddress = ""; denied = false; isResolving = false }

    // MARK: CLLocationManagerDelegate (delivered on the main run loop)

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            denied = false   // reset a stale "denied" hint once access is granted
            if isResolving { m.requestLocation() }
        case .denied, .restricted:
            denied = true; isResolving = false
        default:
            break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { isResolving = false; return }
        coordinate = loc.coordinate
        // The pin is what matters — stop the spinner the moment we have a fix. The reverse
        // geocode is best-effort enrichment that only fills resolvedAddress, so a slow or
        // failed geocode can never strand the spinner.
        isResolving = false
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let p = placemarks?.first else { return }
            let parts = [p.subThoroughfare, p.thoroughfare, p.subLocality, p.locality].compactMap { $0 }
            self?.resolvedAddress = parts.joined(separator: ", ")
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        isResolving = false
    }
}
