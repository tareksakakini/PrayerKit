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
    @ObservedObject var viewModel: PrayerTimesViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Calculation Method Section
                        settingsSection(title: "Calculation Method") {
                            VStack(spacing: 0) {
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
                        
                        // Asr Method Section
                        settingsSection(title: "Asr Calculation") {
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
                        
                        // Notifications Section
                        settingsSection(title: "Notifications") {
                            VStack(spacing: 0) {
                                notificationToggleRow
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 20)
                                offsetPickerRow
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
                        
                        // Info Section
                        infoSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 4)
            
            content()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Method Row
    private func methodRow(method: CalculationMethod) -> some View {
        let isSelected = viewModel.calculationMethod == method
        
        return Button(action: {
            viewModel.calculationMethod = method
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.rawValue)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Show angles for reference
                    HStack(spacing: 12) {
                        Text("Fajr: \(Int(method.fajrAngle))°")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if method.ishaMinutesAfterMaghrib == nil {
                            Text("Isha: \(Int(method.ishaAngle))°")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text("Isha: \(method.ishaMinutesAfterMaghrib!) min")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
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
                    
                    Text("Shadow factor: \(Int(method.shadowFactor))x")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
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
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Calculation Methods")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            Text("Different calculation methods use different angles for Fajr and Isha prayers. Choose the method used by your local mosque or Islamic center.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
            
            Text("ISNA (Islamic Society of North America) is commonly used in North America with 15° angles for both Fajr and Isha.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                .lineSpacing(4)
                .padding(.top, 8)
            
            Text("Notifications are local on-device alerts based on your current location and chosen method.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(3)
                .padding(.top, 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Notifications
    private var notificationToggleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prayer Notifications")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                    Text(viewModel.notificationAuthorizationLabel)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }
    
    private var offsetPickerRow: some View {
        HStack {
            Text("Alert Timing")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Picker("Alert Timing", selection: $viewModel.notificationOffsetMinutes) {
                ForEach(viewModel.notificationOffsetOptions, id: \.self) { offset in
                    Text(offsetLabel(offset))
                        .tag(offset)
                }
            }
            .pickerStyle(.menu)
            .disabled(!viewModel.notificationsEnabled)
            .tint(Color(red: 0.85, green: 0.75, blue: 0.55))
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
                    Spacer()
                    Text("5s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
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
                Text(prayer.arabicName)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { viewModel.isPrayerNotificationEnabled(prayer) },
                set: { viewModel.setPrayerNotificationEnabled($0, for: prayer) }
            ))
            .labelsHidden()
            .tint(Color(red: 0.85, green: 0.75, blue: 0.55))
            .disabled(!viewModel.notificationsEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func offsetLabel(_ offset: Int) -> String {
        if offset == 0 {
            return "On time"
        }
        if offset < 0 {
            return "\(abs(offset)) min before"
        }
        return "\(offset) min after"
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    SettingsView(viewModel: PrayerTimesViewModel(locationManager: LocationManager()))
}
#endif
