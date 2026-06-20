//
//  Prayer.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation

enum DateProvider {
    static var now: () -> Date = { Date() }
    static var timeZone: () -> TimeZone = { TimeZone.current }
}

enum PrayerName: String, CaseIterable, Identifiable, Codable {
    case fajr = "Fajr"
    case sunrise = "Sunrise"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
    
    var id: String { rawValue }
    
    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
    
    var icon: String {
        switch self {
        case .fajr: return "moon.stars.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.fill"
        }
    }
    
    var defaultNotificationEnabled: Bool {
        self != .sunrise
    }
}

struct Prayer: Identifiable, Codable {
    let id: UUID
    let name: PrayerName
    let time: Date
    
    init(name: PrayerName, time: Date) {
        self.id = UUID()
        self.name = name
        self.time = time
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = DateProvider.timeZone()
        return formatter.string(from: time)
    }
    
    var isPast: Bool {
        return time < DateProvider.now()
    }
}

struct DailyPrayers: Codable {
    let date: Date
    let prayers: [Prayer]
    
    var nextPrayer: Prayer? {
        let now = DateProvider.now()
        return prayers.first { $0.time > now }
    }
    
    var currentPrayer: Prayer? {
        let now = DateProvider.now()
        let pastPrayers = prayers.filter { $0.time <= now }
        return pastPrayers.last
    }
}
