//
//  PrayerTimesApp.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import SwiftUI

@main
struct PrayerTimesApp: App {
    init() {
        #if DEBUG
        // Override \"now\" for debugging at 10:00 AM local time
        DateProvider.now = {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 10
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? Date()
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
