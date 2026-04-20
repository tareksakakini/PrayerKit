//
//  PrayerKitViewModel.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

class PrayerKitViewModel: ObservableObject {
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
            guard !isHydratingNotificationPreferences, oldValue != notificationsEnabled else { return }
            handleNotificationToggleChange()
        }
    }
    @Published var reminderLeadMinutes: Int = 10 {
        didSet {
            let sanitizedLead = sanitizedReminderLead(reminderLeadMinutes)
            if sanitizedLead != reminderLeadMinutes {
                reminderLeadMinutes = sanitizedLead
                return
            }
            guard !isHydratingNotificationPreferences, oldValue != reminderLeadMinutes else { return }
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
    @Published private var atPrayerNotificationSelections = Set(
        PrayerName.allCases.filter(\.defaultNotificationEnabled)
    )
    @Published private var upcomingReminderSelections = Set(
        PrayerName.allCases.filter(\.defaultNotificationEnabled)
    )
    private var isUpdatingNotificationsInternally = false
    private var isHydratingNotificationPreferences = false
    
    private let calculationMethodKey = "calculationMethod"
    private let asrMethodKey = "asrMethod"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let reminderLeadMinutesKey = "reminderLeadMinutes"
    private let atPrayerNamesKey = "atPrayerNotificationNames"
    private let reminderPrayerNamesKey = "upcomingReminderPrayerNames"
    private let legacyNotificationOffsetKey = "notificationOffsetMinutes"
    private let legacyNotificationPrayerNamesKey = "notificationPrayerNames"
    
    private struct LoadedNotificationPreferences {
        let notificationsEnabled: Bool
        let reminderLeadMinutes: Int
        var atPrayerSelections: Set<PrayerName>
        var upcomingReminderSelections: Set<PrayerName>
        var needsPersistence: Bool
    }
    
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
                self.recalculateIfDateOrTimeZoneChanged()
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
    
    private func recalculateIfDateOrTimeZoneChanged() {
        guard let currentPrayers = dailyPrayers,
              let location = locationManager.location else { return }
        
        let now = DateProvider.now()
        let isDifferentDay = !Calendar.current.isDate(currentPrayers.date, inSameDayAs: now)
        let previousOffset = TimeZone.current.secondsFromGMT(for: currentPrayers.date)
        let currentOffset = TimeZone.current.secondsFromGMT(for: now)
        
        if isDifferentDay || previousOffset != currentOffset {
            calculatePrayerTimes(for: location, date: now)
        }
    }
    
    func refreshCountdown() {
        countdownTick = Date()
        refreshNotificationAuthorizationStatus()
        recalculateIfDateOrTimeZoneChanged()
        // Re-sync timer to clock when app becomes active (e.g. returning from background)
        scheduleCountdownTick(atNextMinuteBoundary: true)
    }
    
    /// The next upcoming prayer: today's next prayer, or tomorrow's Fajr after Isha.
    /// Unlike `dailyPrayers?.nextPrayer`, this never returns nil when prayers are available.
    var nextPrayer: Prayer? {
        // Depend on countdownTick so SwiftUI re-evaluates each minute
        _ = countdownTick

        if let todayNext = dailyPrayers?.nextPrayer {
            return todayNext
        }

        // All today's prayers are past — compute tomorrow's Fajr
        guard let location = locationManager.location else { return nil }
        let now = DateProvider.now()
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return nil }
        let calculator = PrayerTimeCalculator(calculationMethod: calculationMethod, asrMethod: asrMethod)
        let tomorrowPrayers = calculator.calculatePrayerTimes(for: tomorrow, at: location)
        return tomorrowPrayers.prayers.first(where: { $0.name == .fajr })
    }

    func timeUntilNextPrayer() -> String? {
        guard let nextPrayer = nextPrayer else {
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
        return formatter.string(from: hijriReferenceDate(asOf: DateProvider.now())) + " AH"
    }
    
    private func hijriReferenceDate(asOf date: Date) -> Date {
        let calendar = Calendar.current
        let maghribTime: Date?
        
        if let dailyPrayers, calendar.isDate(dailyPrayers.date, inSameDayAs: date) {
            maghribTime = dailyPrayers.prayers.first(where: { $0.name == .maghrib })?.time
        } else if let location = locationManager.location {
            let calculator = PrayerTimeCalculator(
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
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
    
    var reminderLeadOptions: [Int] {
        [5, 10, 15, 20, 25, 30]
    }
    
    func isAtPrayerNotificationEnabled(_ prayerName: PrayerName) -> Bool {
        atPrayerNotificationSelections.contains(prayerName)
    }
    
    func setAtPrayerNotificationEnabled(_ enabled: Bool, for prayerName: PrayerName) {
        if enabled {
            atPrayerNotificationSelections.insert(prayerName)
        } else {
            atPrayerNotificationSelections.remove(prayerName)
        }
        saveNotificationPreferences()
        
        if notificationsEnabled {
            rescheduleNotificationsForCurrentState()
        }
    }
    
    func isUpcomingReminderEnabled(_ prayerName: PrayerName) -> Bool {
        upcomingReminderSelections.contains(prayerName)
    }
    
    func setUpcomingReminderEnabled(_ enabled: Bool, for prayerName: PrayerName) {
        if enabled {
            upcomingReminderSelections.insert(prayerName)
        } else {
            upcomingReminderSelections.remove(prayerName)
        }
        saveNotificationPreferences()
        
        if notificationsEnabled {
            rescheduleNotificationsForCurrentState()
        }
    }
    
    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
    }
    
    func setReminderLeadMinutes(_ minutes: Int) {
        reminderLeadMinutes = sanitizedReminderLead(minutes)
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
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.bool(forKey: notificationsEnabledKey)
        let storedLead = defaults.object(forKey: reminderLeadMinutesKey) as? Int
        let normalizedLead = sanitizedReminderLead(storedLead ?? 10)
        let hasAtPrayerSelectionsKey = defaults.object(forKey: atPrayerNamesKey) != nil
        let hasReminderSelectionsKey = defaults.object(forKey: reminderPrayerNamesKey) != nil
        let hasModernSelectionKeys = hasAtPrayerSelectionsKey || hasReminderSelectionsKey
        let needsLeadPersistence = storedLead.map { $0 != normalizedLead } ?? false
        
        var loadedPreferences = LoadedNotificationPreferences(
            notificationsEnabled: notificationsEnabled,
            reminderLeadMinutes: normalizedLead,
            atPrayerSelections: atPrayerNotificationSelections,
            upcomingReminderSelections: upcomingReminderSelections,
            needsPersistence: needsLeadPersistence
        )
        
        if hasAtPrayerSelectionsKey,
           let rawNames = defaults.array(forKey: atPrayerNamesKey) as? [String] {
            loadedPreferences.atPrayerSelections = Set(rawNames.compactMap { PrayerName(rawValue: $0) })
        }
        
        if hasReminderSelectionsKey,
           let rawNames = defaults.array(forKey: reminderPrayerNamesKey) as? [String] {
            loadedPreferences.upcomingReminderSelections = Set(rawNames.compactMap { PrayerName(rawValue: $0) })
        }
        
        if !hasModernSelectionKeys, let migratedPreferences = loadLegacyNotificationPreferences() {
            loadedPreferences = migratedPreferences
        } else if !hasAtPrayerSelectionsKey || !hasReminderSelectionsKey {
            loadedPreferences.needsPersistence = true
        }
        
        applyLoadedNotificationPreferences(loadedPreferences)
    }
    
    private func loadLegacyNotificationPreferences() -> LoadedNotificationPreferences? {
        let defaults = UserDefaults.standard
        guard let rawNames = defaults.array(forKey: legacyNotificationPrayerNamesKey) as? [String] else {
            return nil
        }
        
        let restored = Set(rawNames.compactMap { PrayerName(rawValue: $0) })
        guard !restored.isEmpty else { return nil }
        
        let notificationsEnabled = defaults.bool(forKey: notificationsEnabledKey)
        let legacyOffset = defaults.object(forKey: legacyNotificationOffsetKey) as? Int ?? 0
        
        if legacyOffset < 0 {
            return LoadedNotificationPreferences(
                notificationsEnabled: notificationsEnabled,
                reminderLeadMinutes: sanitizedReminderLead(abs(legacyOffset)),
                atPrayerSelections: [],
                upcomingReminderSelections: restored,
                needsPersistence: true
            )
        }
        
        return LoadedNotificationPreferences(
            notificationsEnabled: notificationsEnabled,
            reminderLeadMinutes: 10,
            atPrayerSelections: restored,
            upcomingReminderSelections: [],
            needsPersistence: true
        )
    }
    
    private func applyLoadedNotificationPreferences(_ preferences: LoadedNotificationPreferences) {
        isHydratingNotificationPreferences = true
        defer { isHydratingNotificationPreferences = false }
        
        notificationsEnabled = preferences.notificationsEnabled
        reminderLeadMinutes = preferences.reminderLeadMinutes
        atPrayerNotificationSelections = preferences.atPrayerSelections
        upcomingReminderSelections = preferences.upcomingReminderSelections
        
        if preferences.needsPersistence {
            saveNotificationPreferences()
        }
    }
    
    private func sanitizedReminderLead(_ value: Int) -> Int {
        let clamped = min(max(value, 5), 30)
        let roundedToStep = Int((Double(clamped) / 5.0).rounded()) * 5
        return min(max(roundedToStep, 5), 30)
    }
    
    private var hasAnyEnabledPrayerNotification: Bool {
        !atPrayerNotificationSelections.isEmpty || !upcomingReminderSelections.isEmpty
    }
    
    private func clearAllPrayerNotificationSelections() {
        atPrayerNotificationSelections = []
        upcomingReminderSelections = []
        saveNotificationPreferences()
    }
    
    private func restoreDefaultPrayerNotificationSelections() {
        atPrayerNotificationSelections = Set(PrayerName.allCases.filter(\.defaultNotificationEnabled))
        upcomingReminderSelections = Set(PrayerName.allCases.filter(\.defaultNotificationEnabled))
        saveNotificationPreferences()
    }
    
    private func ensureSelectionsAvailableWhenTurningNotificationsOn() {
        if !hasAnyEnabledPrayerNotification {
            restoreDefaultPrayerNotificationSelections()
        }
    }

    private func disableNotificationsAndClearSelections() {
        isUpdatingNotificationsInternally = true
        notificationsEnabled = false
        isUpdatingNotificationsInternally = false
        clearAllPrayerNotificationSelections()
        NotificationManager.shared.clearScheduledPrayerNotifications()
    }
    
    private func updateSelectionsAfterAuthResult(granted: Bool) {
        if granted {
            ensureSelectionsAvailableWhenTurningNotificationsOn()
            rescheduleNotificationsForCurrentState()
        } else {
            disableNotificationsAndClearSelections()
        }
    }
    
    private func notificationAuthRequestCompletion(_ granted: Bool) {
        refreshNotificationAuthorizationStatus()
        updateSelectionsAfterAuthResult(granted: granted)
    }
    
    private func handleNotificationsDisabled() {
        NotificationManager.shared.clearScheduledPrayerNotifications()
        refreshNotificationAuthorizationStatus()
    }
    
    private func handleNotificationsEnabled() {
        NotificationManager.shared.requestAuthorization { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async {
                self.notificationAuthRequestCompletion(granted)
            }
        }
    }
    
    private func saveNotificationPreferences() {
        UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)
        UserDefaults.standard.set(reminderLeadMinutes, forKey: reminderLeadMinutesKey)
        UserDefaults.standard.set(
            atPrayerNotificationSelections.map(\.rawValue),
            forKey: atPrayerNamesKey
        )
        UserDefaults.standard.set(
            upcomingReminderSelections.map(\.rawValue),
            forKey: reminderPrayerNamesKey
        )
    }
    
    private func handleNotificationToggleChange() {
        guard !isUpdatingNotificationsInternally else { return }
        saveNotificationPreferences()
        
        if notificationsEnabled {
            handleNotificationsEnabled()
        } else {
            handleNotificationsDisabled()
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
            atPrayerEnabledNames: atPrayerNotificationSelections,
            reminderEnabledNames: upcomingReminderSelections,
            reminderLeadMinutes: reminderLeadMinutes
        )
    }
}
