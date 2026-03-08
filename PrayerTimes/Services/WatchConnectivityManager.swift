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
            print("⚠️ WatchConnectivityManager: Session not ready for sync")
            return
        }
        
        let shared = SharedDataManager.shared
        guard shared.isAppGroupAvailable() else {
            print("⚠️ WatchConnectivityManager: App Group unavailable, cannot sync")
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
        userInfo["payloadVersion"] = Date().timeIntervalSince1970
        
        // Prayer times
        if let prayers = shared.loadPrayerTimes() {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let encoded = try? encoder.encode(prayers) {
                userInfo["dailyPrayers"] = encoded
            } else {
                print("⚠️ WatchConnectivityManager: Failed to encode daily prayers")
            }
        }
        
        guard !userInfo.isEmpty else { return }
        
        // transferUserInfo: guaranteed delivery, queued if Watch is asleep
        let transfer = session.transferUserInfo(userInfo)
        print("✅ WatchConnectivityManager: Queued transferUserInfo (\(transfer))")
        
        // updateApplicationContext: immediate state when Watch wakes (replaces previous)
        do {
            try session.updateApplicationContext(userInfo)
            print("✅ WatchConnectivityManager: Updated application context")
        } catch {
            print("⚠️ WatchConnectivityManager: Failed updateApplicationContext: \(error.localizedDescription)")
        }
        
        // transferCurrentComplicationUserInfo: high priority for complication updates
        if session.remainingComplicationUserInfoTransfers > 0 {
            let complicationTransfer = session.transferCurrentComplicationUserInfo(userInfo)
            print("✅ WatchConnectivityManager: Queued complication transfer (\(complicationTransfer))")
        } else {
            print("⚠️ WatchConnectivityManager: Complication transfer budget exhausted")
        }
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
