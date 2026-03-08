//
//  WatchConnectivityReceiver.swift
//  PrayerTimesWidget
//
//  Receives prayer times from iPhone and stores in Watch App Group.
//  The Watch complication cannot access iPhone's App Group (different device).
//

import Foundation
import CoreLocation
import WatchConnectivity
import WidgetKit

final class WatchConnectivityReceiver: NSObject {
    static let shared = WatchConnectivityReceiver()
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    private func applyReceivedData(_ userInfo: [String: Any]) {
        let shared = SharedDataManager.shared
        guard shared.isAppGroupAvailable() else {
            print("⚠️ WatchConnectivityReceiver: App Group unavailable, dropping payload")
            return
        }
        
        // Location
        if let lat = userInfo["latitude"] as? Double, let lon = userInfo["longitude"] as? Double {
            shared.saveLocation(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // City name
        if let city = userInfo["cityName"] as? String {
            shared.saveCityName(city)
        }
        
        // Calculation method
        if let raw = userInfo["calculationMethod"] as? String,
           let method = CalculationMethod.allCases.first(where: { $0.rawValue == raw }) {
            shared.saveCalculationMethod(method)
        }
        
        // Asr method
        if let raw = userInfo["asrMethod"] as? String,
           let method = AsrJuristicMethod.allCases.first(where: { $0.rawValue == raw }) {
            shared.saveAsrMethod(method)
        }
        
        // Prayer times
        if let data = userInfo["dailyPrayers"] as? Data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let prayers = try decoder.decode(DailyPrayers.self, from: data)
                shared.savePrayerTimes(prayers)
                print("✅ WatchConnectivityReceiver: Decoded and saved prayer times")
            } catch {
                print("⚠️ WatchConnectivityReceiver: Failed to decode prayer payload: \(error.localizedDescription)")
            }
        }
        
        if let version = userInfo["payloadVersion"] as? Double {
            shared.saveLastPayloadVersion(version)
        }
        shared.saveLastWatchSyncAt(Date())
        print("✅ WatchConnectivityReceiver: Applied payload and requested timeline reload")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Apply any existing application context (latest state from iPhone)
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                applyReceivedData(context)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        applyReceivedData(userInfo)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyReceivedData(applicationContext)
    }
}
