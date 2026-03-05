//
//  PrayerTimesWidgetTimelineProvider.swift
//  PrayerTimesWidget
//
//  Created by Tarek Sakakini on 11/24/25.
//

import WidgetKit
import SwiftUI
import CoreLocation

struct PrayerTimesEntry: TimelineEntry {
    let date: Date
    let prayers: DailyPrayers?
    let nextPrayer: Prayer?
    let timeUntil: String?
    let cityName: String
    let dateString: String
    let hijriDate: String
}

struct PrayerTimesTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimesEntry
    
    func placeholder(in context: Context) -> PrayerTimesEntry {
        let samplePrayers = createSamplePrayers()
        return PrayerTimesEntry(
            date: DateProvider.now(),
            prayers: samplePrayers,
            nextPrayer: samplePrayers.nextPrayer,
            timeUntil: "2h 30m",
            cityName: "San Francisco",
            dateString: "Monday, November 24",
            hijriDate: "9 Ramadan 1447 AH"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimesEntry) -> Void) {
        #if os(watchOS)
        WatchConnectivityReceiver.shared.activate()
        #endif
        let entry = createEntry(for: DateProvider.now())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimesEntry>) -> Void) {
        #if os(watchOS)
        WatchConnectivityReceiver.shared.activate()
        #endif
        let currentDate = DateProvider.now()
        let calendar = Calendar.current
        
        // Create an entry for each minute boundary so the countdown updates in sync with the clock
        var entries: [PrayerTimesEntry] = []
        let maxEntries = 100
        var entryDate = startOfMinute(for: currentDate, calendar: calendar)
        
        for _ in 0..<maxEntries {
            let entry = createEntry(for: entryDate)
            entries.append(entry)
            // Move to next minute boundary
            guard let nextMinute = calendar.date(byAdding: .minute, value: 1, to: entryDate) else { break }
            entryDate = nextMinute
        }
        
        // Request next timeline refresh after our last entry
        let nextUpdateDate = entryDate
        let timeline = Timeline(entries: entries, policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    private func startOfMinute(for date: Date, calendar: Calendar) -> Date {
        calendar.date(bySetting: .second, value: 0, of: date) ?? date
    }
    
    private func createEntry(for date: Date) -> PrayerTimesEntry {
        let sharedData = SharedDataManager.shared
        
        var dailyPrayers = sharedData.loadPrayerTimes()
        let cityName = sharedData.loadCityName()
        let location = sharedData.loadLocation()
        
        let calendar = Calendar.current
        if dailyPrayers == nil || !calendar.isDate(dailyPrayers!.date, inSameDayAs: date) {
            if let location = location {
                let calculationMethod = sharedData.loadCalculationMethod()
                let asrMethod = sharedData.loadAsrMethod()
                
                let calculator = PrayerTimeCalculator(
                    calculationMethod: calculationMethod,
                    asrMethod: asrMethod
                )
                dailyPrayers = calculator.calculatePrayerTimes(for: date, at: location)
                
                if let prayers = dailyPrayers {
                    sharedData.savePrayerTimes(prayers)
                }
            }
        }
        
        var nextPrayer = nextPrayerRelative(to: date, prayers: dailyPrayers?.prayers)
        // After last prayer (e.g. Isha), use tomorrow's prayers
        if nextPrayer == nil, let location = location, let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            let calculationMethod = sharedData.loadCalculationMethod()
            let asrMethod = sharedData.loadAsrMethod()
            let calculator = PrayerTimeCalculator(
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
            )
            let tomorrowPrayers = calculator.calculatePrayerTimes(for: tomorrow, at: location)
            dailyPrayers = tomorrowPrayers
            nextPrayer = nextPrayerRelative(to: date, prayers: tomorrowPrayers.prayers)
        }
        let timeUntil = calculateTimeUntil(nextPrayer: nextPrayer, asOf: date)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let dateString = dateFormatter.string(from: date)
        
        let islamic = Calendar(identifier: .islamicUmmAlQura)
        let hijriFormatter = DateFormatter()
        hijriFormatter.calendar = islamic
        hijriFormatter.dateFormat = "d MMMM yyyy"
        let hijriDate = hijriFormatter.string(from: date) + " AH"
        
        return PrayerTimesEntry(
            date: date,
            prayers: dailyPrayers,
            nextPrayer: nextPrayer,
            timeUntil: timeUntil,
            cityName: cityName,
            dateString: dateString,
            hijriDate: hijriDate
        )
    }
    
    private func nextPrayerRelative(to date: Date, prayers: [Prayer]?) -> Prayer? {
        guard let prayers = prayers else { return nil }
        return prayers.first { $0.time > date }
    }
    
    private func calculateTimeUntil(nextPrayer: Prayer?, asOf date: Date) -> String? {
        guard let nextPrayer = nextPrayer else { return nil }
        
        let difference = nextPrayer.time.timeIntervalSince(date)
        
        if difference <= 0 {
            return nil
        }
        
        let hours = Int(difference) / 3600
        let minutes = (Int(difference) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func createSamplePrayers() -> DailyPrayers {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let prayers = [
            Prayer(name: .fajr, time: calendar.date(byAdding: .hour, value: 5, to: today)!),
            Prayer(name: .sunrise, time: calendar.date(byAdding: .hour, value: 6, to: today)!),
            Prayer(name: .dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: today)!),
            Prayer(name: .asr, time: calendar.date(byAdding: .hour, value: 15, to: today)!),
            Prayer(name: .maghrib, time: calendar.date(byAdding: .hour, value: 18, to: today)!),
            Prayer(name: .isha, time: calendar.date(byAdding: .hour, value: 19, to: today)!)
        ]
        
        return DailyPrayers(date: Date(), prayers: prayers)
    }
}
