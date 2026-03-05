//
//  WatchConnectivityManager.swift
//  PrayerTimes
//
//  Syncs prayer times and location from iPhone to Watch via WatchConnectivity.
//  The Watch complication runs on a separate device and cannot access the iPhone's App Group.
//

import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    /// Call this when prayer times or location are saved - syncs to Watch
    func syncToWatch() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            return
        }
        
        let shared = SharedDataManager.shared
        guard let userDefaults = shared.isAppGroupAvailable() ? UserDefaults(suiteName: appGroupIdentifier) : nil else {
            return
        }
        
        var userInfo: [String: Any] = [:]
        
        // Location
        if let location = shared.loadLocation() {
            userInfo["latitude"] = location.latitude
            userInfo["longitude"] = location.longitude
        }
        
        // City name
        userInfo["cityName"] = shared.loadCityName()
        userInfo["calculationMethod"] = shared.loadCalculationMethod().rawValue
        userInfo["asrMethod"] = shared.loadAsrMethod().rawValue
        
        // Prayer times
        if let prayers = shared.loadPrayerTimes(),
           let encoded = try? JSONEncoder().encode(prayers) {
            userInfo["dailyPrayers"] = encoded
        }
        
        guard !userInfo.isEmpty else { return }
        
        // transferUserInfo: guaranteed delivery, queued if Watch is asleep
        session.transferUserInfo(userInfo)
        
        // updateApplicationContext: immediate state when Watch wakes (replaces previous)
        try? session.updateApplicationContext(userInfo)
        
        // transferCurrentComplicationUserInfo: high priority for complication updates
        session.transferCurrentComplicationUserInfo(userInfo)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            syncToWatch()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}
