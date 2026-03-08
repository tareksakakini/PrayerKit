//
//  SharedDataManager.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation
import CoreLocation

// App Group identifier - must match what's configured in Xcode App Groups capability
let appGroupIdentifier = "group.tektechinc.PrayerKit.shared"

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private var userDefaults: UserDefaults? {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        if defaults == nil {
            print("⚠️ SharedDataManager: Failed to create UserDefaults with App Group: \(appGroupIdentifier)")
            print("   Make sure App Groups capability is enabled for both app and widget targets")
        }
        return defaults
    }
    
    private init() {}
    
    // MARK: - Debug
    
    func isAppGroupAvailable() -> Bool {
        return userDefaults != nil
    }
    
    // MARK: - Prayer Times
    
    func savePrayerTimes(_ dailyPrayers: DailyPrayers) {
        guard let userDefaults = userDefaults else {
            print("⚠️ SharedDataManager: Cannot save prayer times - App Group not available")
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(dailyPrayers) {
            userDefaults.set(encoded, forKey: "dailyPrayers")
            userDefaults.set(Date(), forKey: "lastUpdated")
            userDefaults.synchronize()
            print("✅ SharedDataManager: Saved prayer times successfully")
        } else {
            print("⚠️ SharedDataManager: Failed to encode prayer times")
        }
    }
    
    func loadPrayerTimes() -> DailyPrayers? {
        guard let userDefaults = userDefaults else {
            print("⚠️ SharedDataManager: Cannot load prayer times - App Group not available")
            return nil
        }
        
        guard let data = userDefaults.data(forKey: "dailyPrayers") else {
            print("⚠️ SharedDataManager: No prayer times data found in shared storage")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let prayers = try? decoder.decode(DailyPrayers.self, from: data) {
            print("✅ SharedDataManager: Loaded prayer times successfully - date: \(prayers.date), count: \(prayers.prayers.count)")
            return prayers
        } else {
            print("⚠️ SharedDataManager: Failed to decode prayer times data")
            return nil
        }
    }
    
    // MARK: - Location
    
    func saveLocation(_ coordinate: CLLocationCoordinate2D) {
        guard let userDefaults = userDefaults else {
            print("⚠️ SharedDataManager: Cannot save location - App Group not available")
            return
        }
        userDefaults.set(coordinate.latitude, forKey: "latitude")
        userDefaults.set(coordinate.longitude, forKey: "longitude")
        userDefaults.synchronize()
        print("✅ SharedDataManager: Saved location: \(coordinate.latitude), \(coordinate.longitude)")
    }
    
    func loadLocation() -> CLLocationCoordinate2D? {
        guard let userDefaults = userDefaults else { return nil }
        let latitude = userDefaults.double(forKey: "latitude")
        let longitude = userDefaults.double(forKey: "longitude")
        
        guard latitude != 0 && longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Settings
    
    func saveCalculationMethod(_ method: CalculationMethod) {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(method.rawValue, forKey: "calculationMethod")
    }
    
    func loadCalculationMethod() -> CalculationMethod {
        guard let userDefaults = userDefaults,
              let rawValue = userDefaults.string(forKey: "calculationMethod"),
              let method = CalculationMethod.allCases.first(where: { $0.rawValue == rawValue }) else {
            return .northAmerica
        }
        return method
    }
    
    func saveAsrMethod(_ method: AsrJuristicMethod) {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(method.rawValue, forKey: "asrMethod")
    }
    
    func loadAsrMethod() -> AsrJuristicMethod {
        guard let userDefaults = userDefaults,
              let rawValue = userDefaults.string(forKey: "asrMethod"),
              let method = AsrJuristicMethod.allCases.first(where: { $0.rawValue == rawValue }) else {
            return .shafi
        }
        return method
    }
    
    // MARK: - City Name
    
    func saveCityName(_ name: String) {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(name, forKey: "cityName")
    }
    
    func loadCityName() -> String {
        guard let userDefaults = userDefaults else { return "Unknown" }
        return userDefaults.string(forKey: "cityName") ?? "Unknown"
    }
    
    // MARK: - Sync Metadata
    
    func saveLastWatchSyncAt(_ date: Date) {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(date, forKey: "lastWatchSyncAt")
    }
    
    func loadLastWatchSyncAt() -> Date? {
        guard let userDefaults = userDefaults else { return nil }
        return userDefaults.object(forKey: "lastWatchSyncAt") as? Date
    }
    
    func saveLastPayloadVersion(_ version: Double) {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(version, forKey: "lastPayloadVersion")
    }
    
    func loadLastPayloadVersion() -> Double? {
        guard let userDefaults = userDefaults else { return nil }
        let value = userDefaults.double(forKey: "lastPayloadVersion")
        return value > 0 ? value : nil
    }
}

// MARK: - Codable Extensions
// Note: Codable conformance is now in Prayer.swift file
