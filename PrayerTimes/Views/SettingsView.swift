//
//  SettingsView.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @ObservedObject var viewModel: PrayerKitViewModel
    @Environment(\.dismiss) var dismiss
    @State private var expandedSections: Set<SettingsSection> = []
    @State private var showCalculationInfo = false

    private enum SettingsSection: Hashable {
        case notifications
        case calculationMethod
        case asrCalculation
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient

                ScrollView {
                    VStack(spacing: 20) {
                        collapsibleSection(title: "Notifications", section: .notifications) {
                            VStack(spacing: 0) {
                                notificationToggleRow
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 20)
                                reminderLeadPickerRow
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 20)
                                debugNotificationRow

                                if viewModel.notificationsEnabled {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 20)

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Notify For")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .padding(.horizontal, 20)
                                            .padding(.top, 14)

                                        ForEach(Array(PrayerName.allCases.enumerated()), id: \.element.id) { index, prayer in
                                            prayerNotificationRow(prayer: prayer)
                                            if index < PrayerName.allCases.count - 1 {
                                                Divider()
                                                    .background(Color.white.opacity(0.1))
                                                    .padding(.leading, 20)
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                        }

                        collapsibleSection(title: "Calculation Method", section: .calculationMethod) {
                            VStack(spacing: 0) {
                                automaticMethodRow

                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 20)

                                ForEach(Array(CalculationMethod.allCases.enumerated()), id: \.element.id) { index, method in
                                    methodRow(method: method)
                                    if index < CalculationMethod.allCases.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                        }

                        collapsibleSection(title: "Asr Calculation", section: .asrCalculation) {
                            VStack(spacing: 0) {
                                ForEach(Array(AsrJuristicMethod.allCases.enumerated()), id: \.element.id) { index, method in
                                    asrMethodRow(method: method)
                                    if index < AsrJuristicMethod.allCases.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Calculation Methods", isPresented: $showCalculationInfo) {
                Button("Done", role: .cancel) {}
            } message: {
                Text("Different calculation methods use different angles for Fajr and Isha prayers. Choose the method used by your local mosque or Islamic center.\n\nISNA (Islamic Society of North America) is commonly used in North America with 15° angles for both Fajr and Isha.\n\nNotifications are local on-device alerts based on your current location and chosen method.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                }
            }
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.13, blue: 0.26),
                Color(red: 0.12, green: 0.22, blue: 0.35),
                Color(red: 0.18, green: 0.30, blue: 0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Collapsible Section
    private func collapsibleSection<Content: View>(
        title: String,
        section: SettingsSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedSections.contains(section)

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    toggleSection(section, isExpanded: isExpanded)
                } label: {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if section == .calculationMethod {
                    Button {
                        showCalculationInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    toggleSection(section, isExpanded: isExpanded)
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))

                content()
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 8)
        )
    }

    // MARK: - Automatic Row
    private var automaticMethodRow: some View {
        let isSelected = viewModel.isUsingAutomaticCalculationMethod
        let resolvedLabel = viewModel.calculationMethod.rawValue

        return Button(action: {
            viewModel.manualCalculationMethod = nil
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic")
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(isSelected ? "Using \(resolvedLabel)" : "Pick based on your location")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.15)
                    : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Method Row
    private func methodRow(method: CalculationMethod) -> some View {
        // Highlight only when the user has manually picked this method.
        // In automatic mode, the resolved method is shown on the Automatic row instead.
        let isSelected = viewModel.manualCalculationMethod == method

        return Button(action: {
            viewModel.manualCalculationMethod = method
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.rawValue)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Show angles for reference
                    HStack(spacing: 12) {
                        Text("Fajr: \(formattedAngle(method.fajrAngle))°")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if method.ishaMinutesAfterMaghrib == nil {
                            Text("Isha: \(formattedAngle(method.ishaAngle))°")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            Text("Isha: \(method.ishaMinutesAfterMaghrib!) min")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.15)
                    : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formattedAngle(_ value: Double) -> String {
        // Preserve decimal precision (e.g. 18.2, 19.5) — the new lineup includes
        // half-degree methods, so flooring to Int silently misrepresents them.
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Asr Method Row
    private func asrMethodRow(method: AsrJuristicMethod) -> some View {
        let isSelected = viewModel.asrMethod == method

        return Button(action: {
            viewModel.asrMethod = method
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.rawValue)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Shadow factor: \(Int(method.shadowFactor))x")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.15)
                    : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Notifications
    private var notificationToggleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prayer Notifications")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(viewModel.notificationAuthorizationLabel)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                ))
                .labelsHidden()
                .tint(Color(red: 0.85, green: 0.75, blue: 0.55))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if viewModel.notificationAuthorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open iOS Notification Settings")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    private var reminderLeadPickerRow: some View {
        HStack(spacing: 12) {
            Text("Upcoming Reminder")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Menu {
                ForEach(viewModel.reminderLeadOptions, id: \.self) { minutes in
                    Button {
                        viewModel.setReminderLeadMinutes(minutes)
                    } label: {
                        if minutes == viewModel.reminderLeadMinutes {
                            Label("\(minutes) min before", systemImage: "checkmark")
                        } else {
                            Text("\(minutes) min before")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.reminderLeadMinutes) min before")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(!viewModel.notificationsEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var debugNotificationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.sendDebugNotification()
            } label: {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                    Text("Send Test Notification")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("5s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(PlainButtonStyle())

            Text("Use this to quickly verify notification permissions and delivery.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private func prayerNotificationRow(prayer: PrayerName) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(prayer.rawValue)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(prayer.arabicName)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Text("At time")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Toggle("", isOn: Binding(
                        get: { viewModel.isAtPrayerNotificationEnabled(prayer) },
                        set: { viewModel.setAtPrayerNotificationEnabled($0, for: prayer) }
                    ))
                    .labelsHidden()
                    .tint(Color(red: 0.85, green: 0.75, blue: 0.55))
                    .disabled(!viewModel.notificationsEnabled)
                }

                HStack(spacing: 8) {
                    Text("Reminder")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Toggle("", isOn: Binding(
                        get: { viewModel.isUpcomingReminderEnabled(prayer) },
                        set: { viewModel.setUpcomingReminderEnabled($0, for: prayer) }
                    ))
                    .labelsHidden()
                    .tint(Color(red: 0.85, green: 0.75, blue: 0.55))
                    .disabled(!viewModel.notificationsEnabled)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func toggleSection(_ section: SettingsSection, isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    SettingsView(viewModel: PrayerKitViewModel(locationManager: LocationManager()))
}
#endif
