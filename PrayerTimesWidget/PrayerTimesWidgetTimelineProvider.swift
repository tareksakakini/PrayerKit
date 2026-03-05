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
}

struct PrayerTimesTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimesEntry
    
    func placeholder(in context: Context) -> PrayerTimesEntry {
        let samplePrayers = createSamplePrayers()
        return PrayerTimesEntry(
            date: Date(),
            prayers: samplePrayers,
            nextPrayer: samplePrayers.nextPrayer,
            timeUntil: "2h 30m",
            cityName: "San Francisco",
            dateString: "Monday, November 24"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimesEntry) -> Void) {
        let entry = createEntry(for: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimesEntry>) -> Void) {
        let currentDate = Date()
        let entry = createEntry(for: currentDate)
        
        var nextUpdateDate: Date
        
        if let nextPrayer = entry.nextPrayer {
            nextUpdateDate = nextPrayer.time.addingTimeInterval(60)
        } else {
            let calendar = Calendar.current
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                nextUpdateDate = calendar.startOfDay(for: tomorrow)
            } else {
                nextUpdateDate = currentDate.addingTimeInterval(3600)
            }
        }
        
        let minimumUpdate = currentDate.addingTimeInterval(900)
        if nextUpdateDate < minimumUpdate {
            nextUpdateDate = minimumUpdate
        }
        
        if entry.prayers == nil {
            nextUpdateDate = currentDate.addingTimeInterval(300)
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
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
        
        let nextPrayer = dailyPrayers?.nextPrayer
        let timeUntil = calculateTimeUntil(nextPrayer: nextPrayer)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let dateString = dateFormatter.string(from: date)
        
        return PrayerTimesEntry(
            date: date,
            prayers: dailyPrayers,
            nextPrayer: nextPrayer,
            timeUntil: timeUntil,
            cityName: cityName,
            dateString: dateString
        )
    }
    
    private func calculateTimeUntil(nextPrayer: Prayer?) -> String? {
        guard let nextPrayer = nextPrayer else { return nil }
        
        let now = Date()
        let difference = nextPrayer.time.timeIntervalSince(now)
        
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
