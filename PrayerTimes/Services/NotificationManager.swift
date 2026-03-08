//
//  NotificationManager.swift
//  PrayerTimes
//
//  Created by Codex on 3/6/26.
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let requestPrefix = "prayer_notification_"

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
        removePendingPrayerRequests()
    }

    func scheduleNotifications(
        for dailyPrayers: [DailyPrayers],
        offsetMinutes: Int,
        enabledPrayerNames: Set<PrayerName>
    ) {
        authorizationStatus { [weak self] status in
            guard let self else { return }
            let canSchedule = status == .authorized || status == .provisional || status == .ephemeral
            guard canSchedule else {
                self.clearScheduledPrayerNotifications()
                return
            }

            self.removePendingPrayerRequests {
                for day in dailyPrayers {
                    for prayer in day.prayers where enabledPrayerNames.contains(prayer.name) {
                        self.scheduleSingleNotification(for: prayer, offsetMinutes: offsetMinutes)
                    }
                }
            }
        }
    }
    
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
            
            let identifier = "\(requestPrefix)debug_test"
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    print("⚠️ NotificationManager: Failed to schedule debug notification - \(error.localizedDescription)")
                }
            }
        }
    }

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

    private func scheduleSingleNotification(for prayer: Prayer, offsetMinutes: Int) {
        let triggerDate = prayer.time.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        guard triggerDate > DateProvider.now() else { return }

        let content = UNMutableNotificationContent()
        content.title = prayer.name.rawValue
        content.body = notificationBody(for: prayer.name, offsetMinutes: offsetMinutes)
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let identifier = "\(requestPrefix)\(prayer.name.rawValue.lowercased())_\(Int(triggerDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("⚠️ NotificationManager: Failed to schedule \(prayer.name.rawValue) - \(error.localizedDescription)")
            }
        }
    }

    private func notificationBody(for prayerName: PrayerName, offsetMinutes: Int) -> String {
        if offsetMinutes == 0 {
            return "It is time for \(prayerName.rawValue)."
        }
        if offsetMinutes < 0 {
            return "\(prayerName.rawValue) starts in \(abs(offsetMinutes)) minutes."
        }
        return "\(prayerName.rawValue) started \(offsetMinutes) minutes ago."
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
