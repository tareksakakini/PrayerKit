//
//  PrayerTimesViewModel.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

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
    @Published var notificationsEnabled: Bool = false {
        didSet {
            handleNotificationToggleChange()
        }
    }
    @Published var notificationOffsetMinutes: Int = 0 {
        didSet {
            saveNotificationPreferences()
            if notificationsEnabled {
                rescheduleNotificationsForCurrentState()
            }
        }
    }
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private var locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    @Published private var selectedPrayerNotifications = Set(
        PrayerName.allCases.filter(\.defaultNotificationEnabled)
    )
    private var isUpdatingNotificationsInternally = false
    
    private let calculationMethodKey = "calculationMethod"
    private let asrMethodKey = "asrMethod"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let notificationOffsetKey = "notificationOffsetMinutes"
    private let notificationPrayerNamesKey = "notificationPrayerNames"
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        loadPreferences()
        loadNotificationPreferences()
        setupBindings()
        startCountdownTimer()
        refreshNotificationAuthorizationStatus()
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
        WatchConnectivityManager.shared.syncToWatch()
    }
    
    private func saveAsrMethod() {
        UserDefaults.standard.set(asrMethod.rawValue, forKey: asrMethodKey)
        SharedDataManager.shared.saveAsrMethod(asrMethod)
        WatchConnectivityManager.shared.syncToWatch()
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: targetDate)
        let tomorrowPrayers = tomorrow.map { calculator.calculatePrayerTimes(for: $0, at: coordinate) }
        
        DispatchQueue.main.async {
            self.dailyPrayers = prayers
            self.isLoading = false
            
            // Save to shared storage for widget
            SharedDataManager.shared.savePrayerTimes(prayers)
            // Sync to Watch (runs on separate device, cannot access iPhone App Group)
            WatchConnectivityManager.shared.syncToWatch()
            
            if self.notificationsEnabled {
                self.schedulePrayerNotifications(primary: prayers, secondary: tomorrowPrayers)
            }
        }
    }
    
    func recalculatePrayerTimes() {
        guard let location = locationManager.location else { return }
        calculatePrayerTimes(for: location)
    }
    
    func refreshCountdown() {
        countdownTick = Date()
        refreshNotificationAuthorizationStatus()
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
    
    var notificationOffsetLabel: String {
        switch notificationOffsetMinutes {
        case ..<0:
            return "\(abs(notificationOffsetMinutes)) min before"
        case 0:
            return "On time"
        default:
            return "\(notificationOffsetMinutes) min after"
        }
    }
    
    var notificationAuthorizationLabel: String {
        switch notificationAuthorizationStatus {
        case .notDetermined:
            return "Permission not requested"
        case .denied:
            return "Permission denied (enable in iOS Settings)"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    var notificationOffsetOptions: [Int] {
        [-15, -10, -5, 0, 5, 10]
    }
    
    func isPrayerNotificationEnabled(_ prayerName: PrayerName) -> Bool {
        selectedPrayerNotifications.contains(prayerName)
    }
    
    func setPrayerNotificationEnabled(_ enabled: Bool, for prayerName: PrayerName) {
        if enabled {
            selectedPrayerNotifications.insert(prayerName)
        } else {
            selectedPrayerNotifications.remove(prayerName)
        }
        saveNotificationPreferences()
        
        if notificationsEnabled {
            rescheduleNotificationsForCurrentState()
        }
    }
    
    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
    }
    
    func sendDebugNotification() {
        NotificationManager.shared.requestAuthorization { [weak self] granted in
            DispatchQueue.main.async {
                self?.refreshNotificationAuthorizationStatus()
                guard granted else { return }
                NotificationManager.shared.scheduleDebugNotification(after: 5)
            }
        }
    }
    
    private func loadNotificationPreferences() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        
        if let storedOffset = UserDefaults.standard.object(forKey: notificationOffsetKey) as? Int {
            notificationOffsetMinutes = storedOffset
        } else {
            notificationOffsetMinutes = 0
        }
        
        if let rawNames = UserDefaults.standard.array(forKey: notificationPrayerNamesKey) as? [String] {
            let restored = Set(rawNames.compactMap { PrayerName(rawValue: $0) })
            if !restored.isEmpty {
                selectedPrayerNotifications = restored
            }
        }
    }
    
    private func saveNotificationPreferences() {
        UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)
        UserDefaults.standard.set(notificationOffsetMinutes, forKey: notificationOffsetKey)
        UserDefaults.standard.set(
            selectedPrayerNotifications.map(\.rawValue),
            forKey: notificationPrayerNamesKey
        )
    }
    
    private func handleNotificationToggleChange() {
        guard !isUpdatingNotificationsInternally else { return }
        saveNotificationPreferences()
        
        if notificationsEnabled {
            NotificationManager.shared.requestAuthorization { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.refreshNotificationAuthorizationStatus()
                    
                    if granted {
                        self.rescheduleNotificationsForCurrentState()
                    } else {
                        self.isUpdatingNotificationsInternally = true
                        self.notificationsEnabled = false
                        self.isUpdatingNotificationsInternally = false
                        self.saveNotificationPreferences()
                        NotificationManager.shared.clearScheduledPrayerNotifications()
                    }
                }
            }
        } else {
            NotificationManager.shared.clearScheduledPrayerNotifications()
            refreshNotificationAuthorizationStatus()
        }
    }
    
    private func refreshNotificationAuthorizationStatus() {
        NotificationManager.shared.authorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                self?.notificationAuthorizationStatus = status
            }
        }
    }
    
    private func rescheduleNotificationsForCurrentState() {
        guard notificationsEnabled, let location = locationManager.location else { return }
        
        let calculator = PrayerTimeCalculator(
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
        let today = calculator.calculatePrayerTimes(for: DateProvider.now(), at: location)
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: DateProvider.now())
        let tomorrow = tomorrowDate.map { calculator.calculatePrayerTimes(for: $0, at: location) }
        
        schedulePrayerNotifications(primary: today, secondary: tomorrow)
    }
    
    private func schedulePrayerNotifications(primary: DailyPrayers, secondary: DailyPrayers?) {
        let days = [primary, secondary].compactMap { $0 }
        NotificationManager.shared.scheduleNotifications(
            for: days,
            offsetMinutes: notificationOffsetMinutes,
            enabledPrayerNames: selectedPrayerNotifications
        )
    }
}
