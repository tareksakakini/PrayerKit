//
//  SettingsView.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import SwiftUI

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
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    SettingsView(viewModel: PrayerTimesViewModel(locationManager: LocationManager()))
}
#endif
