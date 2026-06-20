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
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        locationError = nil
        cityName = "Getting location..."
        locationManager.requestLocation()
    }

    func startUpdatingLocation() {
        locationError = nil
        cityName = "Getting location..."
        locationManager.startUpdatingLocation()
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
