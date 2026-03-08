//
//  PrayerTimesWatchApp.swift
//  PrayerTimesWatch Watch App
//
//  Created by Tarek Sakakini on 3/4/26.
//

import SwiftUI

@main
struct PrayerKitWatchApp: App {
    init() {
        WatchConnectivityReceiver.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
