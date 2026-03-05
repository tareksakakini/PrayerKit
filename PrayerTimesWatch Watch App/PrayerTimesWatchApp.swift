//
//  PrayerTimesWatchApp.swift
//  PrayerTimesWatch Watch App
//
//  Created by Tarek Sakakini on 3/4/26.
//

import SwiftUI

@main
struct PrayerTimesWatch_Watch_AppApp: App {
    init() {
        WatchConnectivityReceiver.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
