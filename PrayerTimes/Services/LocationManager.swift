//
//  LocationManager.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation
import CoreLocation
import Combine
import WidgetKit

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var location: CLLocationCoordinate2D?
    @Published var cityName: String = "Loading..."
    @Published var countryName: String = ""
    @Published var isoCountryCode: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update if moved more than 100 meters

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDebugSimulatedCityChanged),
            name: .debugSimulatedCityChanged,
            object: nil
        )
        applyDebugOverrideIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        if applyDebugOverrideIfNeeded() { return }
        locationError = nil
        cityName = "Getting location..."
        locationManager.requestLocation()
    }

    func startUpdatingLocation() {
        if applyDebugOverrideIfNeeded() { return }
        locationError = nil
        cityName = "Getting location..."
        locationManager.startUpdatingLocation()
    }

    @objc private func handleDebugSimulatedCityChanged() {
        if !applyDebugOverrideIfNeeded() {
            // Override was just cleared — restart real GPS.
            startUpdatingLocation()
        }
    }

    /// Publishes the simulated city as if it were the device location.
    /// Returns true when an override is active so callers can skip real GPS.
    @discardableResult
    private func applyDebugOverrideIfNeeded() -> Bool {
        guard let city = DebugLocationOverride.shared.simulatedCity else { return false }

        DispatchQueue.main.async {
            self.locationError = nil
            self.location = city.coordinate
            self.cityName = city.name
            self.countryName = city.country
            self.isoCountryCode = city.countryCode
            // Intentionally do NOT write to the shared app group — the widget
            // and watch should keep showing the real device's data.
        }
        return true
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    private func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    self?.cityName = "Unknown Location"
                    return
                }
                
                if let placemark = placemarks?.first {
                    self?.cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                    self?.countryName = placemark.country ?? ""
                    self?.isoCountryCode = placemark.isoCountryCode

                    // Save to shared storage for widget
                    SharedDataManager.shared.saveCityName(self?.cityName ?? "Unknown")
                    // Push city updates after reverse geocode finishes.
                    WatchConnectivityManager.shared.syncToWatch()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Ignore real GPS updates while the debug simulator is active.
        if DebugLocationOverride.shared.isActive {
            locationManager.stopUpdatingLocation()
            return
        }

        guard let location = locations.last else { return }

        // Check location accuracy - reject if accuracy is too poor
        if location.horizontalAccuracy < 0 {
            print("Invalid location accuracy: \(location.horizontalAccuracy)")
            return
        }
        
        // Stop updating after getting a good location
        if location.horizontalAccuracy <= 1000 { // Within 1km accuracy
            locationManager.stopUpdatingLocation()
        }
        
        DispatchQueue.main.async {
            self.location = location.coordinate
            self.reverseGeocode(location: location)
            
            // Save to shared storage for widget
            SharedDataManager.shared.saveLocation(location.coordinate)
            // Sync to Watch (ViewModel will recalculate prayers; this pushes location immediately)
            WatchConnectivityManager.shared.syncToWatch()
            WidgetCenter.shared.reloadAllTimelines()
            
            // Debug: Print coordinates
            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            print("Accuracy: \(location.horizontalAccuracy) meters")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Suppress GPS errors while the debug simulator is active.
        if DebugLocationOverride.shared.isActive { return }

        DispatchQueue.main.async {
            if let clError = error as? CLError, clError.code == .denied {
                self.locationError = "Location access denied. Please enable in Settings."
            } else {
                self.locationError = error.localizedDescription
            }
            print("Location error: \(error.localizedDescription)")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            // Debug simulator overrides authorization-driven flows.
            if self.applyDebugOverrideIfNeeded() { return }

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Start updating location for better accuracy
                self.startUpdatingLocation()
            case .denied, .restricted:
                self.locationError = "Location access denied. Please enable in Settings."
                self.cityName = "Location Unavailable"
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
