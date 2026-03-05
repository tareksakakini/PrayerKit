//
//  ContentView.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel: PrayerTimesViewModel
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        let locManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locManager)
        _viewModel = StateObject(wrappedValue: PrayerTimesViewModel(locationManager: locManager))
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with location and date
                    headerSection
                    
                    // Location error message
                    if let error = locationManager.locationError {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "location.slash.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("Open Settings")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.2))
                        )
                    }
                    
                    // Next prayer card
                    if let nextPrayer = viewModel.dailyPrayers?.nextPrayer {
                        nextPrayerCard(prayer: nextPrayer)
                    }
                    
                    // Prayer times list
                    prayerTimesSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.refreshCountdown()
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
        .overlay(
            // Subtle geometric pattern overlay
            GeometricPatternView()
                .opacity(0.03)
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Location with refresh button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                    Text(locationManager.cityName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    if !locationManager.countryName.isEmpty {
                        Text("•")
                            .font(.system(size: 14))
                            .opacity(0.6)
                        Text(locationManager.countryName)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .opacity(0.8)
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                // Refresh location button
                Button(action: {
                    locationManager.requestLocation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                
                // Settings button
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
            }
            
            // Coordinates (for debugging)
            if let location = locationManager.location {
                Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Dates
            VStack(spacing: 4) {
                Text(viewModel.formattedDate)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(viewModel.hijriDate)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Next Prayer Card
    private func nextPrayerCard(prayer: Prayer) -> some View {
        VStack(spacing: 16) {
            Text("NEXT PRAYER")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 16) {
                // Prayer icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.85, green: 0.75, blue: 0.55),
                                    Color(red: 0.75, green: 0.60, blue: 0.40)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: prayer.name.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(red: 0.07, green: 0.13, blue: 0.26))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(prayer.name.rawValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(prayer.name.arabicName)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(prayer.formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if let timeUntil = viewModel.timeUntilNextPrayer() {
                        Text("in \(timeUntil)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Prayer Times Section
    private var prayerTimesSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Today's Prayers")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "moon.stars")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Prayer rows
            if let prayers = viewModel.dailyPrayers?.prayers {
                ForEach(prayers) { prayer in
                    prayerRow(prayer: prayer)
                }
            } else if viewModel.isLoading {
                loadingView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func prayerRow(prayer: Prayer) -> some View {
        let isNext = viewModel.dailyPrayers?.nextPrayer?.name == prayer.name
        let isPast = prayer.isPast && !isNext
        
        return HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isNext
                            ? Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.2)
                            : Color.white.opacity(isPast ? 0.05 : 0.1)
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: prayer.name.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(
                        isNext
                            ? Color(red: 0.85, green: 0.75, blue: 0.55)
                            : (isPast ? .white.opacity(0.4) : .white.opacity(0.8))
                    )
            }
            
            // Prayer name
            VStack(alignment: .leading, spacing: 2) {
                Text(prayer.name.rawValue)
                    .font(.system(size: 17, weight: isNext ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isPast ? .white.opacity(0.5) : .white)
                
                Text(prayer.name.arabicName)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(
                        isNext
                            ? Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.8)
                            : .white.opacity(isPast ? 0.3 : 0.5)
                    )
            }
            
            Spacer()
            
            // Time
            Text(prayer.formattedTime)
                .font(.system(size: 17, weight: isNext ? .bold : .medium, design: .monospaced))
                .foregroundColor(
                    isNext
                        ? Color(red: 0.85, green: 0.75, blue: 0.55)
                        : (isPast ? .white.opacity(0.4) : .white.opacity(0.9))
                )
            
            // Status indicator
            if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green.opacity(0.6))
            } else if isNext {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.55))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            isNext
                ? Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.1)
                : Color.clear
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Calculating prayer times...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(40)
    }
}

// MARK: - Geometric Pattern View
struct GeometricPatternView: View {
    var body: some View {
        Canvas { context, size in
            let patternSize: CGFloat = 60
            let rows = Int(size.height / patternSize) + 1
            let cols = Int(size.width / patternSize) + 1
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * patternSize
                    let y = CGFloat(row) * patternSize
                    
                    // Draw Islamic geometric star pattern
                    let center = CGPoint(x: x + patternSize / 2, y: y + patternSize / 2)
                    let path = createStarPath(center: center, radius: patternSize / 3, points: 8)
                    
                    context.stroke(path, with: .color(.white), lineWidth: 0.5)
                }
            }
        }
    }
    
    private func createStarPath(center: CGPoint, radius: CGFloat, points: Int) -> Path {
        var path = Path()
        let angleIncrement = .pi * 2 / CGFloat(points * 2)
        
        for i in 0..<(points * 2) {
            let currentRadius = i % 2 == 0 ? radius : radius * 0.5
            let angle = CGFloat(i) * angleIncrement - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * currentRadius,
                y: center.y + sin(angle) * currentRadius
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        
        return path
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    ContentView()
}
#endif
