//
//  ContentView.swift
//  PrayerTimesWatch Watch App
//
//  Created by Tarek Sakakini on 3/4/26.
//

import SwiftUI

struct ContentView: View {
    @State private var prayers: DailyPrayers?
    @State private var cityName: String = ""
    @State private var hijriDate: String = ""
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if let prayers = prayers {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let next = prayers.nextPrayer {
                            HStack {
                                Image(systemName: next.name.icon)
                                    .font(.caption)
                                Text(next.name.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text(next.formattedTime)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider()
                        
                        ForEach(prayers.prayers) { prayer in
                            HStack {
                                Image(systemName: prayer.name.icon)
                                    .font(.caption2)
                                    .frame(width: 20, alignment: .leading)
                                Text(prayer.name.rawValue)
                                    .font(.caption)
                                Spacer()
                                Text(prayer.formattedTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !hijriDate.isEmpty {
                            Text(hijriDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                    Text("Open iPhone app")
                        .font(.caption)
                    Text("to set location")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(cityName.isEmpty ? "Prayer Kit" : cityName)
        .onAppear {
            loadData()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                loadData()
            }
        }
    }
    
    private func loadData() {
        let shared = SharedDataManager.shared
        prayers = resolvePrayers(shared: shared, asOf: DateProvider.now())
        cityName = shared.loadCityName()
        
        let islamic = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamic
        formatter.dateFormat = "d MMMM yyyy"
        hijriDate = formatter.string(
            from: hijriReferenceDate(asOf: DateProvider.now(), shared: shared, prayers: prayers)
        ) + " AH"
    }
    
    private func resolvePrayers(shared: SharedDataManager, asOf date: Date) -> DailyPrayers? {
        var dailyPrayers = shared.loadPrayerTimes()
        let calendar = Calendar.current
        let location = shared.loadLocation()
        
        // Recalculate if missing or from another day, to avoid stale next-prayer values.
        if dailyPrayers == nil || !calendar.isDate(dailyPrayers!.date, inSameDayAs: date) {
            if let location = location {
                let calculator = PrayerTimeCalculator(
                    calculationMethod: shared.loadCalculationMethod(),
                    asrMethod: shared.loadAsrMethod()
                )
                dailyPrayers = calculator.calculatePrayerTimes(for: date, at: location)
                if let dailyPrayers {
                    shared.savePrayerTimes(dailyPrayers)
                }
            }
        }
        
        // After the last prayer, show tomorrow's Fajr as next.
        if dailyPrayers?.nextPrayer == nil,
           let location = location,
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            let calculator = PrayerTimeCalculator(
                calculationMethod: shared.loadCalculationMethod(),
                asrMethod: shared.loadAsrMethod()
            )
            let tomorrowPrayers = calculator.calculatePrayerTimes(for: tomorrow, at: location)
            dailyPrayers = tomorrowPrayers
            shared.savePrayerTimes(tomorrowPrayers)
        }
        
        return dailyPrayers
    }
    
    private func hijriReferenceDate(asOf date: Date, shared: SharedDataManager, prayers: DailyPrayers?) -> Date {
        let calendar = Calendar.current
        let maghribTime: Date?
        
        if let prayers, calendar.isDate(prayers.date, inSameDayAs: date) {
            maghribTime = prayers.prayers.first(where: { $0.name == .maghrib })?.time
        } else if let location = shared.loadLocation() {
            let calculator = PrayerTimeCalculator(
                calculationMethod: shared.loadCalculationMethod(),
                asrMethod: shared.loadAsrMethod()
            )
            let todayPrayers = calculator.calculatePrayerTimes(for: date, at: location)
            maghribTime = todayPrayers.prayers.first(where: { $0.name == .maghrib })?.time
        } else {
            maghribTime = nil
        }
        
        guard let maghribTime, date >= maghribTime,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else {
            return date
        }
        
        return nextDay
    }
}

#Preview {
    ContentView()
}
