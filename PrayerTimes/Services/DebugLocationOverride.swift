//
//  DebugLocationOverride.swift
//  PrayerTimes
//
//  Holds the optional debug city used to simulate prayer times at other
//  locations + time zones. Persistence is intentionally `UserDefaults.standard`
//  (NOT the shared app group) so the widget and watch keep real-device data.
//

import Foundation
import CoreLocation

extension Notification.Name {
    static let debugSimulatedCityChanged = Notification.Name("debugSimulatedCityChanged")
}

final class DebugLocationOverride: ObservableObject {
    static let shared = DebugLocationOverride()

    private let storageKey = "debugSimulatedCityID"

    @Published private(set) var simulatedCity: DebugCity?

    private init() {
        if let id = UserDefaults.standard.string(forKey: storageKey),
           let city = DebugCity.city(withID: id) {
            self.simulatedCity = city
            installTimeZoneProvider(for: city)
        }
    }

    var isActive: Bool { simulatedCity != nil }

    var effectiveTimeZone: TimeZone {
        simulatedCity?.timeZone ?? TimeZone.current
    }

    func setSimulatedCity(_ city: DebugCity?) {
        guard simulatedCity != city else { return }
        simulatedCity = city

        if let city {
            UserDefaults.standard.set(city.id, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }

        installTimeZoneProvider(for: city)
        NotificationCenter.default.post(name: .debugSimulatedCityChanged, object: nil)
    }

    private func installTimeZoneProvider(for city: DebugCity?) {
        if let city {
            DateProvider.timeZone = { city.timeZone }
        } else {
            DateProvider.timeZone = { TimeZone.current }
        }
    }
}
