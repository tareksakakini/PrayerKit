//
//  NotificationService.swift
//  PrayerKitNotificationExtension
//
//  Notification Service Extension for Prayer Kit.
//
//  On receipt of a visible push from OneSignal with `mutable_content: true`,
//  refresh the rolling window of local prayer-time notifications. Reads all
//  state from the shared app group, so the main app does not need to be
//  running.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var didDeliver = false
    private let deliveryQueue = DispatchQueue(label: "NotificationService.delivery")

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        NotificationManager.shared.refreshFromPersistedState { [weak self] _ in
            self?.deliver()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // System is about to terminate the extension; deliver whatever we have.
        deliver()
    }

    private func deliver() {
        deliveryQueue.sync {
            guard !didDeliver else { return }
            didDeliver = true
            let content = bestAttemptContent ?? UNMutableNotificationContent()
            contentHandler?(content)
        }
    }
}
