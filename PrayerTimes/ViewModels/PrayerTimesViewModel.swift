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
    
    private let calculationMethodKey = "calculationMethod"
    private let asrMethodKey = "asrMethod"
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        loadPreferences()
        setupBindings()
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
    
    func calculatePrayerTimes(for coordinate: CLLocationCoordinate2D) {
        isLoading = true
        
        let calculator = PrayerTimeCalculator(
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
        
        let prayers = calculator.calculatePrayerTimes(for: Date(), at: coordinate)
        
        DispatchQueue.main.async {
            self.dailyPrayers = prayers
            self.isLoading = false
            
            // Save to shared storage for widget
            SharedDataManager.shared.savePrayerTimes(prayers)
        }
    }
    
    func recalculatePrayerTimes() {
        guard let location = locationManager.location else { return }
        calculatePrayerTimes(for: location)
    }
    
    func timeUntilNextPrayer() -> String? {
        guard let nextPrayer = dailyPrayers?.nextPrayer else {
            return nil
        }
        
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
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    var hijriDate: String {
        let islamic = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamic
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date()) + " AH"
    }
}

