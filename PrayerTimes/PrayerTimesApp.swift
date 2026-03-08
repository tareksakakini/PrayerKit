//
//  PrayerTimesApp.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import SwiftUI

@main
struct PrayerKitApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        WatchConnectivityManager.shared.activate()
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WatchConnectivityManager.shared.syncToWatch()
            }
        }
    }
}
