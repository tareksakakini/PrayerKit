//
//  PrayerTimesApp.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import SwiftUI
import UIKit
import OneSignalFramework

@main
struct PrayerKitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchConnectivityManager.shared.activate()
        _ = NotificationManager.shared
        NotificationManager.shared.registerBackgroundRefreshTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                WatchConnectivityManager.shared.syncToWatch()
            case .background:
                NotificationManager.shared.scheduleBackgroundRefresh()
            default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    // TODO: Replace with the App ID from the OneSignal dashboard
    // (Settings → Keys & IDs). Looks like "abcdef12-3456-7890-abcd-ef1234567890".
    private static let oneSignalAppId = "ab6f6335-b4cc-41eb-8cc1-3fa3eebfce42"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        OneSignal.initialize(Self.oneSignalAppId, withLaunchOptions: launchOptions)
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if DEBUG
        print("🔔 AppDelegate: Silent push received, refreshing notification window…")
        #endif

        NotificationManager.shared.refreshFromPersistedState { success in
            #if DEBUG
            // Verification helper: fires a visible banner ~2s after the refresh
            // completes so we can confirm the wake-up happened without Xcode
            // attached. Scheduled here (not before refresh) so it survives the
            // prayer-cleanup step. Stripped from Release builds.
            print("🔔 AppDelegate: refreshFromPersistedState completed — success=\(success)")
            NotificationManager.shared.scheduleDebugNotification(after: 2)
            #endif
            completionHandler(success ? .newData : .failed)
        }
    }
}
