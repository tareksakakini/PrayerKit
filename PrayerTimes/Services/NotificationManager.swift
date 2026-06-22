//
//  NotificationManager.swift
//  PrayerTimes
//
//  Created by Codex on 3/6/26.
//

import Foundation
import BackgroundTasks
import CoreLocation
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    static let backgroundRefreshTaskIdentifier = "tektechinc.PrayerKit.notification-refresh"
    static let scheduledDaysWindow = 7
    private static let maxScheduledNotifications = 60

    private let center = UNUserNotificationCenter.current()
    private let requestPrefix = "prayer_notification_"
    private let schedulingStateQueue = DispatchQueue(label: "NotificationManager.schedulingState")
    private var schedulingGeneration: UInt64 = 0

    private struct NotificationScheduleSnapshot {
        let dailyPrayers: [DailyPrayers]
        let atPrayerEnabledNames: Set<PrayerName>
        let reminderEnabledNames: Set<PrayerName>
        let reminderLeadMinutes: Int
    }

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("⚠️ NotificationManager: Authorization request failed - \(error.localizedDescription)")
            }
            completion(granted)
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func clearScheduledPrayerNotifications() {
        invalidateSchedulingGeneration()
        removePendingPrayerRequests()
    }

    /// DEBUG: schedules 3 notifications, one per minute for the next 3 minutes.
    /// Used to verify whether background refresh keeps firing over time.
    /// Each refresh clears the pending prayer-prefixed notifications and refills
    /// the next 3 minutes from "now".
    func scheduleNextThreeMinuteBurst(completion: (() -> Void)? = nil) {
        let generation = nextSchedulingGeneration()

        authorizationStatus { [weak self] status in
            guard let self else {
                completion?()
                return
            }
            guard self.isCurrentSchedulingGeneration(generation) else {
                completion?()
                return
            }
            let canSchedule = status == .authorized || status == .provisional || status == .ephemeral
            guard canSchedule else {
                self.clearScheduledPrayerNotifications()
                completion?()
                return
            }

            self.removePendingPrayerRequests {
                guard self.isCurrentSchedulingGeneration(generation) else {
                    completion?()
                    return
                }

                let scheduledAt = DateProvider.now()
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let scheduledLabel = formatter.string(from: scheduledAt)

                for offset in 1...3 {
                    let content = UNMutableNotificationContent()
                    content.title = "Prayer Kit Burst"
                    content.body = "Burst \(offset)/3 — scheduled at \(scheduledLabel)"
                    content.sound = .default

                    let trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: TimeInterval(offset * 60),
                        repeats: false
                    )
                    let identifier = "\(self.requestPrefix)burst_\(offset)"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    self.center.add(request) { error in
                        if let error {
                            print("⚠️ NotificationManager: Failed to schedule burst \(offset) - \(error.localizedDescription)")
                        }
                    }
                }

                completion?()
            }
        }
    }

    func scheduleNotifications(
        for dailyPrayers: [DailyPrayers],
        atPrayerEnabledNames: Set<PrayerName>,
        reminderEnabledNames: Set<PrayerName>,
        reminderLeadMinutes: Int,
        completion: (() -> Void)? = nil
    ) {
        let snapshot = NotificationScheduleSnapshot(
            dailyPrayers: dailyPrayers,
            atPrayerEnabledNames: atPrayerEnabledNames,
            reminderEnabledNames: reminderEnabledNames,
            reminderLeadMinutes: reminderLeadMinutes
        )
        let generation = nextSchedulingGeneration()

        authorizationStatus { [weak self] status in
            guard let self else {
                completion?()
                return
            }
            guard self.isCurrentSchedulingGeneration(generation) else {
                completion?()
                return
            }
            let canSchedule = status == .authorized || status == .provisional || status == .ephemeral
            guard canSchedule else {
                self.clearScheduledPrayerNotifications()
                completion?()
                return
            }

            self.removePendingPrayerRequests {
                guard self.isCurrentSchedulingGeneration(generation) else {
                    completion?()
                    return
                }

                var scheduledCount = 0
                let cap = NotificationManager.maxScheduledNotifications

                outer: for day in snapshot.dailyPrayers {
                    guard self.isCurrentSchedulingGeneration(generation) else {
                        completion?()
                        return
                    }

                    for prayer in day.prayers {
                        guard self.isCurrentSchedulingGeneration(generation) else {
                            completion?()
                            return
                        }
                        if scheduledCount >= cap { break outer }

                        if snapshot.atPrayerEnabledNames.contains(prayer.name) {
                            if self.scheduleSingleNotification(
                                for: prayer,
                                offsetMinutes: 0,
                                kind: "at_time"
                            ) {
                                scheduledCount += 1
                                if scheduledCount >= cap { break outer }
                            }
                        }
                        if snapshot.reminderEnabledNames.contains(prayer.name) {
                            if self.scheduleSingleNotification(
                                for: prayer,
                                offsetMinutes: -abs(snapshot.reminderLeadMinutes),
                                kind: "reminder"
                            ) {
                                scheduledCount += 1
                                if scheduledCount >= cap { break outer }
                            }
                        }
                    }
                }

                completion?()
            }
        }
    }

    #if DEBUG
    /// Fires a small banner used by AppDelegate to confirm a silent-push
    /// wake-up triggered `refreshFromPersistedState`. Compiled out of Release.
    func scheduleDebugNotification(after seconds: TimeInterval = 5) {
        authorizationStatus { [weak self] status in
            guard let self else { return }
            let canSchedule = status == .authorized || status == .provisional || status == .ephemeral
            guard canSchedule else { return }

            let content = UNMutableNotificationContent()
            content.title = "Prayer Kit Test"
            content.body = "This is a debug notification."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, seconds),
                repeats: false
            )

            let identifier = "prayerkit_debug_test"
            self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error {
                    print("⚠️ NotificationManager: Failed to schedule debug notification - \(error.localizedDescription)")
                }
            }
        }
    }

    /// Fires a real prayer-style notification (bilingual title + body) a few
    /// seconds from now, so you can verify how the live push will look without
    /// waiting for an actual prayer time. Compiled out of Release builds — does
    /// not ship to the App Store.
    func scheduleDebugPrayerNotification(
        prayerName: PrayerName,
        isReminder: Bool,
        reminderLeadMinutes: Int,
        after seconds: TimeInterval = 1
    ) {
        authorizationStatus { [weak self] status in
            guard let self else { return }
            let canSchedule = status == .authorized || status == .provisional || status == .ephemeral
            guard canSchedule else { return }

            let offsetMinutes = isReminder ? -abs(reminderLeadMinutes) : 0

            let content = UNMutableNotificationContent()
            content.title = prayerName.rawValue
            content.body = self.notificationBody(for: prayerName, offsetMinutes: offsetMinutes)
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, seconds),
                repeats: false
            )

            // Distinct identifier so prayer-rescheduling cleanup
            // (which removes everything with the prayer prefix) doesn't sweep this away.
            let identifier = "prayerkit_debug_test"
            self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error {
                    print("⚠️ NotificationManager: Failed to schedule debug notification - \(error.localizedDescription)")
                }
            }
        }
    }
    #endif

    private func removePendingPrayerRequests(completion: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                completion?()
                return
            }
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(self.requestPrefix) }
                .map(\.identifier)
            if !identifiers.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            completion?()
        }
    }

    private func nextSchedulingGeneration() -> UInt64 {
        schedulingStateQueue.sync {
            schedulingGeneration += 1
            return schedulingGeneration
        }
    }

    private func invalidateSchedulingGeneration() {
        schedulingStateQueue.sync {
            schedulingGeneration += 1
        }
    }

    private func isCurrentSchedulingGeneration(_ generation: UInt64) -> Bool {
        schedulingStateQueue.sync {
            schedulingGeneration == generation
        }
    }

    @discardableResult
    private func scheduleSingleNotification(for prayer: Prayer, offsetMinutes: Int, kind: String) -> Bool {
        let triggerDate = prayer.time.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        guard triggerDate > DateProvider.now() else { return false }

        let content = UNMutableNotificationContent()
        content.title = prayer.name.rawValue
        content.body = notificationBody(for: prayer.name, offsetMinutes: offsetMinutes)
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let identifier = "\(requestPrefix)\(prayer.name.rawValue.lowercased())_\(kind)_\(Int(triggerDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("⚠️ NotificationManager: Failed to schedule \(prayer.name.rawValue) - \(error.localizedDescription)")
            }
        }
        return true
    }

    private func notificationBody(for prayerName: PrayerName, offsetMinutes: Int) -> String {
        let english: String
        if offsetMinutes == 0 {
            english = "It is time for \(prayerName.rawValue)."
        } else if offsetMinutes < 0 {
            english = "\(prayerName.rawValue) starts in \(abs(offsetMinutes)) minutes."
        } else {
            english = "\(prayerName.rawValue) started \(offsetMinutes) minutes ago."
        }
        let arabic = arabicNotificationBody(for: prayerName, offsetMinutes: offsetMinutes)
        // U+2067/U+2069 (RLI/PDI) wrap the Arabic in an RTL isolate: the line
        // still left-aligns under the English (outer paragraph stays LTR), but
        // the period resolves at the END of the Arabic sentence (visually left)
        // instead of jumping to the line's right edge.
        return "\(english)\n\u{2067}\(arabic)\u{2069}"
    }

    private func arabicNotificationBody(for prayerName: PrayerName, offsetMinutes: Int) -> String {
        let isSunrise = prayerName == .sunrise
        if offsetMinutes == 0 {
            return isSunrise
                ? "حان وقت الشروق."
                : "حان وقت صلاة \(prayerName.arabicName)."
        }
        if offsetMinutes < 0 {
            let phrase = arabicMinutesPhrase(abs(offsetMinutes))
            return isSunrise
                ? "يبدأ الشروق بعد \(phrase)."
                : "تبدأ صلاة \(prayerName.arabicName) بعد \(phrase)."
        }
        let phrase = arabicMinutesPhrase(offsetMinutes)
        return isSunrise
            ? "بدأ الشروق منذ \(phrase)."
            : "بدأت صلاة \(prayerName.arabicName) منذ \(phrase)."
    }

    private func arabicMinutesPhrase(_ count: Int) -> String {
        let n = Swift.abs(count)
        switch n {
        case 1: return "دقيقة واحدة"
        case 2: return "دقيقتان"
        case 3...10: return "\(n) دقائق"
        default: return "\(n) دقيقة"
        }
    }
}

// MARK: - Background refresh

extension NotificationManager {
    /// Called once at app launch to register the BGAppRefreshTask handler.
    @available(iOSApplicationExtension, unavailable)
    func registerBackgroundRefreshTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: NotificationManager.backgroundRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleBackgroundRefresh(task: refreshTask)
        }
    }

    /// Submits a request for iOS to wake the app and run a refresh in the background.
    /// Call this when the app enters background. iOS decides the actual fire time.
    @available(iOSApplicationExtension, unavailable)
    func scheduleBackgroundRefresh(earliestAfter interval: TimeInterval = 12 * 3600) {
        let request = BGAppRefreshTaskRequest(identifier: NotificationManager.backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ NotificationManager: Failed to submit background refresh request - \(error.localizedDescription)")
        }
    }

    @available(iOSApplicationExtension, unavailable)
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Queue the next refresh first, so a missed/cancelled run doesn't end the chain.
        scheduleBackgroundRefresh()

        task.expirationHandler = { [weak self] in
            self?.invalidateSchedulingGeneration()
        }

        refreshFromPersistedState { success in
            task.setTaskCompleted(success: success)
        }
    }

    /// Reads location, notification preferences, and calculation method from
    /// the shared app group, then reschedules the rolling prayer-notification
    /// window. Used by the background refresh task and the Notification
    /// Service Extension — both run outside the main view-model lifecycle.
    func refreshFromPersistedState(completion: @escaping (Bool) -> Void) {
        let notificationsEnabled = SharedDataManager.shared.loadNotificationsEnabled()
        guard notificationsEnabled else {
            completion(true)
            return
        }

        guard let coordinate = SharedDataManager.shared.loadLocation() else {
            completion(false)
            return
        }

        let atPrayerNames = SharedDataManager.shared.loadAtPrayerNotificationNames()
            .compactMap { PrayerName(rawValue: $0) }
        let reminderNames = SharedDataManager.shared.loadUpcomingReminderPrayerNames()
            .compactMap { PrayerName(rawValue: $0) }
        guard !atPrayerNames.isEmpty || !reminderNames.isEmpty else {
            completion(true)
            return
        }

        let reminderLead = SharedDataManager.shared.loadReminderLeadMinutes() ?? 10
        let calculationMethod = SharedDataManager.shared.loadCalculationMethod()
        let asrMethod = SharedDataManager.shared.loadAsrMethod()

        let calculator = PrayerTimeCalculator(
            calculationMethod: calculationMethod,
            asrMethod: asrMethod
        )
        let days = NotificationManager.upcomingDays(
            count: NotificationManager.scheduledDaysWindow,
            calculator: calculator,
            location: coordinate
        )

        scheduleNotifications(
            for: days,
            atPrayerEnabledNames: Set(atPrayerNames),
            reminderEnabledNames: Set(reminderNames),
            reminderLeadMinutes: reminderLead
        ) {
            completion(true)
        }
    }

    /// Computes prayer times for the next `count` days starting today.
    static func upcomingDays(
        count: Int,
        calculator: PrayerTimeCalculator,
        location: CLLocationCoordinate2D
    ) -> [DailyPrayers] {
        let calendar = Calendar.current
        let start = DateProvider.now()
        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return calculator.calculatePrayerTimes(for: date, at: location)
        }
    }
}

// MARK: - Diagnostics

/// Parsed view of one pending prayer notification, used by the debug list screen.
struct PendingPrayerNotification: Identifiable {
    let id: String
    let prayerName: String
    let body: String
    let triggerDate: Date

    enum Kind {
        case atTime
        case reminder
        case unknown
    }

    var kind: Kind {
        if body.hasPrefix("It is time") { return .atTime }
        if body.contains(" starts in ") { return .reminder }
        return .unknown
    }

    var kindLabel: String {
        switch kind {
        case .atTime: return "At time"
        case .reminder: return "Reminder"
        case .unknown: return "—"
        }
    }
}

extension NotificationManager {
    /// Fetches all pending prayer notifications and returns them parsed and sorted
    /// by trigger date. The completion is invoked on the main queue.
    func getPendingPrayerNotifications(completion: @escaping ([PendingPrayerNotification]) -> Void) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let prefix = self.requestPrefix
            let items: [PendingPrayerNotification] = requests.compactMap { request in
                guard request.identifier.hasPrefix(prefix),
                      let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let date = Calendar.current.date(from: trigger.dateComponents) else {
                    return nil
                }
                return PendingPrayerNotification(
                    id: request.identifier,
                    prayerName: request.content.title,
                    body: request.content.body,
                    triggerDate: date
                )
            }
            .sorted { $0.triggerDate < $1.triggerDate }

            DispatchQueue.main.async { completion(items) }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
