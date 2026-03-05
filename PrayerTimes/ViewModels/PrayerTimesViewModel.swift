//
//  PrayerTimesViewModel.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation
import CoreLocation
import Combine

class PrayerTimesViewModel: ObservableObject {
    @Published var dailyPrayers: DailyPrayers?
    @Published var isLoading: Bool = true
    @Published private(set) var countdownTick: Date = Date()
    @Published var calculationMethod: CalculationMethod = .northAmerica {
        didSet {
            saveCalculationMethod()
            if locationManager.location != nil {
                recalculatePrayerTimes()
            }
        }
    }
    @Published var asrMethod: AsrJuristicMethod = .shafi {
        didSet {
            saveAsrMethod()
            if locationManager.location != nil {
                recalculatePrayerTimes()
            }
        }
    }
    
    private var locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    
    private let calculationMethodKey = "calculationMethod"
    private let asrMethodKey = "asrMethod"
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        loadPreferences()
        setupBindings()
        startCountdownTimer()
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    private func startCountdownTimer() {
        scheduleCountdownTick(atNextMinuteBoundary: true)
    }
    
    private func scheduleCountdownTick(atNextMinuteBoundary: Bool) {
        countdownTimer?.invalidate()
        
        let now = DateProvider.now()
        let calendar = Calendar.current
        
        let interval: TimeInterval
        if atNextMinuteBoundary,
           let startOfNextMinute = calendar.date(bySetting: .second, value: 0, of: now)?.addingTimeInterval(60) {
            let secondsUntilNextMinute = startOfNextMinute.timeIntervalSince(now)
            interval = max(0.1, min(secondsUntilNextMinute, 60))
        } else {
            interval = 60
        }
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.countdownTick = Date()
                // Recalculate when we've passed all prayers (e.g. after Isha) to show tomorrow's Fajr
                if self.dailyPrayers != nil && self.dailyPrayers?.nextPrayer == nil,
                   let location = self.locationManager.location,
                   let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: DateProvider.now()) {
                    self.calculatePrayerTimes(for: location, date: tomorrow)
                }
                // Re-sync to next minute boundary to stay aligned with the clock
                self.scheduleCountdownTick(atNextMinuteBoundary: true)
            }
        }
        countdownTimer?.tolerance = 0.5
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
    
    private func loadPreferences() {
        // Load calculation method
        if let savedMethod = UserDefaults.standard.string(forKey: calculationMethodKey),
           let method = CalculationMethod.allCases.first(where: { $0.rawValue == savedMethod }) {
            calculationMethod = method
        } else {
            // Default to ISNA (North America)
            calculationMethod = .northAmerica
        }
        
        // Load Asr method
        if let savedAsr = UserDefaults.standard.string(forKey: asrMethodKey),
           let method = AsrJuristicMethod.allCases.first(where: { $0.rawValue == savedAsr }) {
            asrMethod = method
        } else {
            asrMethod = .shafi
        }
    }
    
    private func saveCalculationMethod() {
        UserDefaults.standard.set(calculationMethod.rawValue, forKey: calculationMethodKey)
        SharedDataManager.shared.saveCalculationMethod(calculationMethod)
    }
    
    private func saveAsrMethod() {
        UserDefaults.standard.set(asrMethod.rawValue, forKey: asrMethodKey)
        SharedDataManager.shared.saveAsrMethod(asrMethod)
    }
    
    private func setupBindings() {
        // React to location changes
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.calculatePrayerTimes(for: coordinate)
            }
            .store(in: &cancellables)
    }
    
    func calculatePrayerTimes(for coordinate: CLLocationCoordinate2D, date: Date? = nil) {
        isLoading = true
        
        let calculator = PrayerTimeCalculator(
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
        
        let targetDate = date ?? DateProvider.now()
        let prayers = calculator.calculatePrayerTimes(for: targetDate, at: coordinate)
        
        DispatchQueue.main.async {
            self.dailyPrayers = prayers
            self.isLoading = false
            
            // Save to shared storage for widget
            SharedDataManager.shared.savePrayerTimes(prayers)
            // Sync to Watch (runs on separate device, cannot access iPhone App Group)
            WatchConnectivityManager.shared.syncToWatch()
        }
    }
    
    func recalculatePrayerTimes() {
        guard let location = locationManager.location else { return }
        calculatePrayerTimes(for: location)
    }
    
    func refreshCountdown() {
        countdownTick = Date()
        if dailyPrayers != nil && dailyPrayers?.nextPrayer == nil,
           let location = locationManager.location,
           let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: DateProvider.now()) {
            calculatePrayerTimes(for: location, date: tomorrow)
        }
        // Re-sync timer to clock when app becomes active (e.g. returning from background)
        scheduleCountdownTick(atNextMinuteBoundary: true)
    }
    
    func timeUntilNextPrayer() -> String? {
        guard let nextPrayer = dailyPrayers?.nextPrayer else {
            return nil
        }
        
        let now = DateProvider.now()
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
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: DateProvider.now())
    }
    
    var hijriDate: String {
        let islamic = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamic
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: DateProvider.now()) + " AH"
    }
}

