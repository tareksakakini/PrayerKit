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
import WidgetKit
import OneSignalFramework

class PrayerKitViewModel: ObservableObject {
    @Published var dailyPrayers: DailyPrayers?
    @Published var isLoading: Bool = true
    @Published private(set) var countdownTick: Date = Date()
    /// Manual override for the calculation method. `nil` means automatic —
    /// the effective method is derived from the last successfully resolved
    /// country code (see `resolvedAutomaticMethod`).
    @Published var manualCalculationMethod: CalculationMethod? = nil {
        didSet {
            guard !isHydratingCalculationPreferences, oldValue != manualCalculationMethod else { return }
            saveManualCalculationMethodPreference()
            // Switching back to automatic: consume the cached country code
            // immediately if we have one, otherwise arm the flag so the next
            // geocode landing performs the resolution.
            if manualCalculationMethod == nil {
                if let code = locationManager.isoCountryCode {
                    consumePendingAutomaticResolution(forCountryCode: code)
                } else {
                    pendingAutomaticMethodResolution = true
                }
            }
            // Always propagate — the effective method changed even when the
            // resolved automatic method itself is unchanged (e.g., manual
            // .egyptian → automatic .northAmerica).
            saveCalculationMethod()
            if locationManager.location != nil {
                recalculatePrayerTimes()
            }
        }
    }

    /// Last automatic method we resolved from a successful reverse-geocode.
    /// Persisted in `UserDefaults.standard` so cold launches reuse it instead
    /// of falling back to MWL while the new geocode is in flight (or fails).
    @Published private var resolvedAutomaticMethod: CalculationMethod? = nil

    /// True when we're allowed to overwrite `resolvedAutomaticMethod` from the
    /// next country-code emission. Set on first-ever launch, user-initiated
    /// location refresh, or switching from manual to automatic. Cleared as
    /// soon as a country code lands so background geocode results don't
    /// silently change the method.
    private var pendingAutomaticMethodResolution = false

    /// Method actually used for calculations: manual override if set,
    /// otherwise the last resolved automatic method (or MWL as a global
    /// fallback used only before any geocode has ever succeeded).
    var calculationMethod: CalculationMethod {
        if let manual = manualCalculationMethod { return manual }
        if let resolved = resolvedAutomaticMethod { return resolved }
        return .muslimWorldLeague
    }

    var isUsingAutomaticCalculationMethod: Bool { manualCalculationMethod == nil }
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
    @Published var showSystemSettingsAlert: Bool = false
    private var pendingEnableAfterSettingsReturn = false
    
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
    private var isHydratingCalculationPreferences = false

    /// Legacy key, kept for read-only migration on first launch after the upgrade.
    private let legacyCalculationMethodKey = "calculationMethod"
    private let manualCalculationMethodKey = "manualCalculationMethod"
    private let resolvedAutomaticMethodKey = "resolvedAutomaticMethod"
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
        let defaults = UserDefaults.standard
        isHydratingCalculationPreferences = true

        // Load calculation method.
        // Precedence: new manual-override key → legacy key (migrate) → automatic.
        if defaults.object(forKey: manualCalculationMethodKey) != nil {
            let raw = defaults.string(forKey: manualCalculationMethodKey) ?? ""
            manualCalculationMethod = CalculationMethod.allCases.first(where: { $0.rawValue == raw })
        } else if let legacy = defaults.string(forKey: legacyCalculationMethodKey),
                  let method = CalculationMethod.allCases.first(where: { $0.rawValue == legacy }) {
            // Existing users had to actively pick a method, so preserve their
            // choice as the manual override rather than silently switching them
            // to automatic.
            manualCalculationMethod = method
            defaults.set(method.rawValue, forKey: manualCalculationMethodKey)
        } else {
            manualCalculationMethod = nil
        }

        // Load the last automatic resolution. If none has ever happened we
        // arm `pendingAutomaticMethodResolution` so the first successful
        // geocode is allowed to set it. Otherwise we leave it untouched —
        // background geocode results (including failures) won't change it.
        if let raw = defaults.string(forKey: resolvedAutomaticMethodKey),
           let method = CalculationMethod.allCases.first(where: { $0.rawValue == raw }) {
            resolvedAutomaticMethod = method
        } else {
            resolvedAutomaticMethod = nil
            pendingAutomaticMethodResolution = true
        }

        isHydratingCalculationPreferences = false
        // Intentionally not calling saveCalculationMethod() here: shared
        // storage already holds the previous session's value, and writing
        // the in-memory fallback (MWL) before geocode lands would clobber
        // the correct value for the widget, watch, and notification extension.

        // Load Asr method
        if let savedAsr = defaults.string(forKey: asrMethodKey),
           let method = AsrJuristicMethod.allCases.first(where: { $0.rawValue == savedAsr }) {
            asrMethod = method
        } else {
            asrMethod = .shafi
        }
    }

    private func saveManualCalculationMethodPreference() {
        let defaults = UserDefaults.standard
        if let method = manualCalculationMethod {
            defaults.set(method.rawValue, forKey: manualCalculationMethodKey)
        } else {
            // Explicit empty string marks "automatic" — distinct from
            // "key never set" so we don't run the legacy migration again.
            defaults.set("", forKey: manualCalculationMethodKey)
        }
    }

    /// Mirrors the effective method to the app group (widget + notification
    /// extension consume this). Called whenever the effective method may have
    /// changed: manual override changes, or country code changes in auto mode.
    private func saveCalculationMethod() {
        SharedDataManager.shared.saveCalculationMethod(calculationMethod)
        WatchConnectivityManager.shared.syncToWatch()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveAsrMethod() {
        UserDefaults.standard.set(asrMethod.rawValue, forKey: asrMethodKey)
        SharedDataManager.shared.saveAsrMethod(asrMethod)
        WatchConnectivityManager.shared.syncToWatch()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Consumes a permitted resolution: clears the pending flag and updates
    /// `resolvedAutomaticMethod` (with persistence) if the new value differs.
    /// Does NOT touch shared storage / widget / watch / notifications — the
    /// caller is responsible for that, so paths that change the effective
    /// method for other reasons (e.g. manual → automatic) can still propagate
    /// even when the resolved automatic method itself is unchanged.
    private func consumePendingAutomaticResolution(forCountryCode code: String) {
        pendingAutomaticMethodResolution = false
        let newMethod = CalculationMethod.recommended(forCountryCode: code) ?? .muslimWorldLeague
        guard newMethod != resolvedAutomaticMethod else { return }
        resolvedAutomaticMethod = newMethod
        UserDefaults.standard.set(newMethod.rawValue, forKey: resolvedAutomaticMethodKey)
    }

    /// Subscription path: consume the resolution and, if it changed the
    /// effective calculation method, push the change through.
    private func applyResolvedAutomaticMethod(forCountryCode code: String) {
        let previousEffective = calculationMethod
        consumePendingAutomaticResolution(forCountryCode: code)
        guard calculationMethod != previousEffective else { return }
        saveCalculationMethod()
        if locationManager.location != nil {
            recalculatePrayerTimes()
        }
    }

    /// User-initiated location refresh. Re-arms automatic resolution so the
    /// next successful geocode is allowed to update the calculation method.
    func refreshLocation() {
        if isUsingAutomaticCalculationMethod {
            pendingAutomaticMethodResolution = true
        }
        locationManager.requestLocation()
    }
    
    private func setupBindings() {
        // React to location changes
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.calculatePrayerTimes(for: coordinate)
            }
            .store(in: &cancellables)

        // Country-code landings only update the automatic method when we've
        // explicitly opened the door for it (first run, user refresh, or
        // toggling back to automatic). Nil values are ignored so a failed
        // background geocode can never overwrite a previously-resolved method.
        locationManager.$isoCountryCode
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] code in
                guard let self, self.isUsingAutomaticCalculationMethod else { return }
                guard self.pendingAutomaticMethodResolution else { return }
                self.applyResolvedAutomaticMethod(forCountryCode: code)
            }
            .store(in: &cancellables)

        // Bubble locationManager state changes so SwiftUI views observing this
        // ViewModel re-render when (e.g.) the auto-resolved method changes.
        locationManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    func calculatePrayerTimes(for coordinate: CLLocationCoordinate2D, date: Date? = nil) {
        isLoading = true

        let calculator = PrayerTimeCalculator(
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )

        let targetDate = date ?? DateProvider.now()
        let prayers = calculator.calculatePrayerTimes(
            for: targetDate,
            at: coordinate,
            timeZone: DateProvider.timeZone()
        )

        DispatchQueue.main.async {
            self.dailyPrayers = prayers
            self.isLoading = false

            SharedDataManager.shared.savePrayerTimes(prayers)
            WatchConnectivityManager.shared.syncToWatch()
            WidgetCenter.shared.reloadAllTimelines()

            if self.notificationsEnabled {
                self.rescheduleNotificationsForCurrentState()
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
        let effectiveTimeZone = DateProvider.timeZone()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = effectiveTimeZone

        let isDifferentDay = !calendar.isDate(currentPrayers.date, inSameDayAs: now)
        let previousOffset = effectiveTimeZone.secondsFromGMT(for: currentPrayers.date)
        let currentOffset = effectiveTimeZone.secondsFromGMT(for: now)

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
        // Refill the prayer-notification window on every foreground activation
        // so a returning user always has a fresh schedule.
        rescheduleNotificationsForCurrentState()
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
        let effectiveTimeZone = DateProvider.timeZone()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = effectiveTimeZone
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        let calculator = PrayerTimeCalculator(calculationMethod: calculationMethod, asrMethod: asrMethod)
        let tomorrowPrayers = calculator.calculatePrayerTimes(for: tomorrow, at: location, timeZone: effectiveTimeZone)
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
        formatter.timeZone = DateProvider.timeZone()
        return formatter.string(from: DateProvider.now())
    }

    var hijriDate: String {
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = DateProvider.timeZone()
        let formatter = DateFormatter()
        formatter.calendar = islamic
        formatter.timeZone = DateProvider.timeZone()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: hijriReferenceDate(asOf: DateProvider.now())) + " AH"
    }

    private func hijriReferenceDate(asOf date: Date) -> Date {
        let effectiveTimeZone = DateProvider.timeZone()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = effectiveTimeZone
        let maghribTime: Date?

        if let dailyPrayers, calendar.isDate(dailyPrayers.date, inSameDayAs: date) {
            maghribTime = dailyPrayers.prayers.first(where: { $0.name == .maghrib })?.time
        } else if let location = locationManager.location {
            let calculator = PrayerTimeCalculator(
                calculationMethod: calculationMethod,
                asrMethod: asrMethod
            )
            let todayPrayers = calculator.calculatePrayerTimes(for: date, at: location, timeZone: effectiveTimeZone)
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
        if enabled, notificationAuthorizationStatus == .denied {
            // iOS won't re-prompt after a denial — the user has to flip it on
            // in the system Settings app. Surface that path instead of letting
            // the toggle flash on then snap back.
            showSystemSettingsAlert = true
            return
        }
        notificationsEnabled = enabled
    }

    /// Called when the user taps "Open Settings" in the denial alert. Records
    /// the intent so that when the app returns to the foreground with iOS
    /// authorization granted, the in-app toggle flips on automatically.
    func markPendingEnableAfterSettingsReturn() {
        pendingEnableAfterSettingsReturn = true
    }

    /// Hook called from the view when the scene becomes active. Re-checks
    /// iOS notification authorization and fulfills any pending enable intent
    /// recorded before the user was sent to system Settings.
    func handleSceneBecameActive() {
        refreshCountdown()
        NotificationManager.shared.authorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationAuthorizationStatus = status
                if self.pendingEnableAfterSettingsReturn, status == .authorized {
                    self.pendingEnableAfterSettingsReturn = false
                    self.setNotificationsEnabled(true)
                }
            }
        }
    }

    /// On the very first launch, prompt for notification permission and let
    /// the result drive the in-app toggle. Reuses the standard enable path
    /// so OneSignal opt-in and scheduling happen the same way as a manual
    /// toggle from Settings.
    func promptForNotificationsIfNeeded() {
        let key = "hasPromptedForNotificationsOnFirstLaunch"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        setNotificationsEnabled(true)
    }
    
    func setReminderLeadMinutes(_ minutes: Int) {
        reminderLeadMinutes = sanitizedReminderLead(minutes)
    }
    
    #if DEBUG
    func sendDebugPrayerNotification(prayerName: PrayerName, isReminder: Bool) {
        let lead = reminderLeadMinutes
        NotificationManager.shared.requestAuthorization { [weak self] granted in
            DispatchQueue.main.async {
                self?.refreshNotificationAuthorizationStatus()
                guard granted else { return }
                NotificationManager.shared.scheduleDebugPrayerNotification(
                    prayerName: prayerName,
                    isReminder: isReminder,
                    reminderLeadMinutes: lead,
                    after: 1
                )
            }
        }
    }
    #endif
    
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

        // Always re-save on launch so the app-group mirror used by the NSE
        // stays in sync with UserDefaults.standard (cheap; only 4 keys).
        saveNotificationPreferences()
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
            OneSignal.User.pushSubscription.optIn()
            ensureSelectionsAvailableWhenTurningNotificationsOn()
            rescheduleNotificationsForCurrentState()
        } else {
            OneSignal.User.pushSubscription.optOut()
            disableNotificationsAndClearSelections()
        }
    }
    
    private func notificationAuthRequestCompletion(_ granted: Bool) {
        refreshNotificationAuthorizationStatus()
        updateSelectionsAfterAuthResult(granted: granted)
    }
    
    private func handleNotificationsDisabled() {
        OneSignal.User.pushSubscription.optOut()
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
        let atPrayerRawNames = atPrayerNotificationSelections.map(\.rawValue)
        let reminderRawNames = upcomingReminderSelections.map(\.rawValue)

        UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)
        UserDefaults.standard.set(reminderLeadMinutes, forKey: reminderLeadMinutesKey)
        UserDefaults.standard.set(atPrayerRawNames, forKey: atPrayerNamesKey)
        UserDefaults.standard.set(reminderRawNames, forKey: reminderPrayerNamesKey)

        // Mirror into the app group so the Notification Service Extension
        // (which runs in a separate process) can read the same prefs.
        SharedDataManager.shared.saveNotificationsEnabled(notificationsEnabled)
        SharedDataManager.shared.saveReminderLeadMinutes(reminderLeadMinutes)
        SharedDataManager.shared.saveAtPrayerNotificationNames(atPrayerRawNames)
        SharedDataManager.shared.saveUpcomingReminderPrayerNames(reminderRawNames)
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
        let days = NotificationManager.upcomingDays(
            count: NotificationManager.scheduledDaysWindow,
            calculator: calculator,
            location: location
        )

        NotificationManager.shared.scheduleNotifications(
            for: days,
            atPrayerEnabledNames: atPrayerNotificationSelections,
            reminderEnabledNames: upcomingReminderSelections,
            reminderLeadMinutes: reminderLeadMinutes
        )
    }
}
